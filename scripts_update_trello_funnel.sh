#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${WEAVER_DASHBOARD_DIR:-/home/aureo/weaver-dashboard}"
ENV_FILE="${WEAVER_DASHBOARD_ENV:-$REPO_DIR/.env}"
OUTFILE="$REPO_DIR/trello_data.json"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1" >&2; exit 10; }
}

need_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: missing $name. Create $ENV_FILE from .env.example and fill it locally." >&2
    exit 20
  fi
}

need_cmd curl
need_cmd jq
need_cmd git
need_cmd cmp
need_var TRELLO_KEY
need_var TRELLO_TOKEN

# Keep this checkout aligned with the published branch before generating data.
# A local refresh is not a successful dashboard update until it is on origin/main.
cd "$REPO_DIR"
git fetch origin main
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: dashboard checkout has uncommitted changes; refusing to publish over an unknown state" >&2
  exit 40
fi
git pull --ff-only origin main

JOBSEARCH_LIST_ID="${TRELLO_JOBSEARCH_LIST_ID:-618d6e3a7f45fe818da46b14}"
SHORTLISTED_LIST_ID="${TRELLO_SHORTLISTED_LIST_ID:-66e03eea1a6e73171d379092}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl_trello() {
  local list_id="$1"
  local fields="$2"
  local out="$3"
  local http_code
  http_code=$(curl -sS -w '%{http_code}' -o "$out" \
    "https://api.trello.com/1/lists/${list_id}/cards?key=${TRELLO_KEY}&token=${TRELLO_TOKEN}&fields=${fields}")
  if [ "$http_code" != "200" ]; then
    echo "ERROR: Trello request failed for list ${list_id} with HTTP ${http_code}" >&2
    exit 30
  fi
}

curl_trello "$JOBSEARCH_LIST_ID" "name,due,labels,dateLastActivity" "$TMP_DIR/trello_jobsearch.json"
curl_trello "$SHORTLISTED_LIST_ID" "name,due,labels" "$TMP_DIR/trello_shortlisted.json"

NOW=$(date -u +%s)
CUR_MONTH=$(date -u +%Y-%m)
CUR_YEAR=$(date -u +%Y)

jq -r --arg now "$NOW" --arg cur_month "$CUR_MONTH" --arg cur_year "$CUR_YEAR" '
  def label_names: [.labels[]?.name // empty];
  def clean_due: (if .due then (.due | sub("\\.000Z$"; "Z")) else null end);
  def due_ts: (clean_due | if . then (fromdateiso8601) else null end);
  def due_month: (if .due then (.due[0:7]) else null end);
  def due_year: (if .due then (.due[0:4]) else null end);
  def is_individual: (.name | test("\\bIC\\b|Individual Consultant"; "i"));
  def is_company: (.name | test("\\bFirm\\b"; "i")) or (is_individual | not);
  def has_done: (label_names | index("Done") != null);
  def is_past_due: (due_ts != null and due_ts <= ($now | tonumber));
  def is_future: (due_ts != null and due_ts > ($now | tonumber));
  def is_applied: is_past_due or has_done;
  def is_pending: is_future and (has_done | not);
  def is_applied_month: is_applied and (due_month == $cur_month);
  def is_applied_year: is_applied and (due_year == $cur_year);
  {
    individual: {
      pending: [.[] | select(is_individual and is_pending)] | length,
      applied_month: [.[] | select(is_individual and is_applied_month)] | length,
      applied_year: [.[] | select(is_individual and is_applied_year)] | length
    },
    company: {
      pending: [.[] | select(is_company and is_pending)] | length,
      applied_month: [.[] | select(is_company and is_applied_month)] | length,
      applied_year: [.[] | select(is_company and is_applied_year)] | length
    },
    total_applied_year: [.[] | select(is_applied and (due_year == $cur_year))] | length,
    total_pending: [.[] | select(is_pending)] | length,
    total_cards: length,
    monthly_individual: ([.[] | select(is_individual and is_applied and (due_month != null))] | group_by(.due[0:7]) | map({key: .[0].due[0:7], count: length})),
    monthly_company: ([.[] | select(is_company and is_applied and (due_month != null))] | group_by(.due[0:7]) | map({key: .[0].due[0:7], count: length})),
    monthly_applied: ([.[] | select(is_applied and (due_month != null))] | group_by(.due[0:7]) | map({key: .[0].due[0:7], count: length})),
    weekly_entries: ([.[] | select(.dateLastActivity != null)] | group_by(.dateLastActivity[0:10]) | map({key: .[0].dateLastActivity[0:10], count: length}) | sort_by(.key)),
    monthly_entries: ([.[] | select(.dateLastActivity != null)] | group_by(.dateLastActivity[0:7]) | map({key: .[0].dateLastActivity[0:7], count: length}) | sort_by(.key)),
    weekly_entries_individual: ([.[] | select(is_individual and .dateLastActivity != null)] | group_by(.dateLastActivity[0:10]) | map({key: .[0].dateLastActivity[0:10], count: length}) | sort_by(.key)),
    weekly_entries_company: ([.[] | select(is_company and .dateLastActivity != null)] | group_by(.dateLastActivity[0:10]) | map({key: .[0].dateLastActivity[0:10], count: length}) | sort_by(.key)),
    monthly_entries_individual: ([.[] | select(is_individual and .dateLastActivity != null)] | group_by(.dateLastActivity[0:7]) | map({key: .[0].dateLastActivity[0:7], count: length}) | sort_by(.key)),
    monthly_entries_company: ([.[] | select(is_company and .dateLastActivity != null)] | group_by(.dateLastActivity[0:7]) | map({key: .[0].dateLastActivity[0:7], count: length}) | sort_by(.key))
  }
' "$TMP_DIR/trello_jobsearch.json" > "$TMP_DIR/funnel_stats.json"

jq -r '
  def is_individual: (.name | test("\\bIC\\b|Individual Consultant"; "i"));
  def is_company: (.name | test("\\bFirm\\b"; "i")) or (is_individual | not);
  { shortlisted_individual: [.[] | select(is_individual)] | length, shortlisted_company: [.[] | select(is_company)] | length }
' "$TMP_DIR/trello_shortlisted.json" > "$TMP_DIR/shortlisted_stats.json"

jq -s '.[0] * .[1]' "$TMP_DIR/funnel_stats.json" "$TMP_DIR/shortlisted_stats.json" > "$OUTFILE"

summary=$(jq -c '{total: .total_cards, pending: .total_pending, applied_2026: .total_applied_year}' "$OUTFILE")
echo "Funnel updated: ${summary}"

cd "$REPO_DIR"
git add trello_data.json
if git diff --cached --quiet; then
  echo "No local funnel changes to commit."
else
  git commit -m "funnel: atualização $(date -u +'%Y-%m-%d')"
  if [ "${WEAVER_DASHBOARD_PUSH:-1}" = "1" ]; then
    git push origin main
  else
    echo "WEAVER_DASHBOARD_PUSH=0, commit created but push skipped."
    exit 0
  fi
fi

local_head="$(git rev-parse HEAD)"
remote_head="$(git ls-remote origin refs/heads/main | cut -f1)"
if [ "$local_head" != "$remote_head" ]; then
  echo "ERROR: origin/main does not match the local dashboard commit after publish" >&2
  exit 50
fi

# The job is successful only once GitHub Pages serves the generated data.
PAGES_DATA_URL="${WEAVER_DASHBOARD_PUBLIC_DATA_URL:-https://weaver-maia-ops.github.io/weaver-dashboard/trello_data.json}"
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if curl -fsS --max-time 20 "${PAGES_DATA_URL}?commit=${local_head}" -o "$TMP_DIR/published_trello_data.json" \
    && cmp -s "$OUTFILE" "$TMP_DIR/published_trello_data.json"; then
    echo "Published dashboard data verified (commit ${local_head:0:7})."
    exit 0
  fi
  sleep 5
done

echo "ERROR: GitHub Pages did not serve the generated trello_data.json within 60 seconds" >&2
exit 60
