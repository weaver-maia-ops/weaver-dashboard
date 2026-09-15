# Project dossier standard

Use this standard whenever creating or materially updating a project card in the Weaver dashboard.

## Purpose

The **Resumo geral** button is a concise project dossier, not only a status note. It must preserve decision context and make the project's current position understandable without reconstructing prior messages.

## Required fields

1. **Situação atual**: one factual paragraph with the current state.
2. **Objetivo do projeto**: intended outcome and strategic purpose.
3. **Escopo e entregas**: agreed or known work scope, outputs, and acceptance criteria. Mark unknown items as pending rather than guessing.
4. **Fase e governança**: project phase and accountable leadership.
5. **Marcos e andamento**: dated or verifiable milestones.
6. **Decisões registradas**: decisions that change scope, ownership, route, or priority.
7. **Riscos, dependências e lacunas**: blockers, external dependencies, and missing information.
8. **Próximos passos**: concrete actions, ideally with owners and timing when known.

## Writing rules

- Record confirmed facts only. Do not infer contract terms, scope, deadlines, owners, or outcomes.
- Use `|` between list items in `data-dossier-progress`, `data-dossier-decisions`, `data-dossier-risks`, and `data-dossier-nextsteps`.
- Use Portuguese and English counterparts for every field.
- Update the `data-summary-updated` date and add a dated item to the card's visible update log.
- Keep team-facing dashboard content within Weaver scope. Do not expose internal operating contexts, private deliberation, or other project domains.

## Dashboard attributes

A structured card uses these button attributes:

```html
data-dossier-overview="..."
data-dossier-objective="..."
data-dossier-scope="..."
data-dossier-phase="..."
data-dossier-progress="item 1|item 2"
data-dossier-decisions="item 1|item 2"
data-dossier-risks="item 1|item 2"
data-dossier-nextsteps="item 1|item 2"
```

Each needs an equivalent `-en` attribute. Cards without `data-dossier-overview` continue to use the legacy free-text summary until they are upgraded.
