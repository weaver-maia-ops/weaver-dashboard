(function() {
  const SENHA = "SenhaFacil2!";
  const KEY = "weaver_auth";
  if (sessionStorage.getItem(KEY) === "ok") return;
  const senha = prompt("🔒 Digite a senha para acessar o painel Weaver:");
  if (senha === SENHA) {
    sessionStorage.setItem(KEY, "ok");
  } else {
    document.body.innerHTML = "<div style='display:flex;align-items:center;justify-content:center;height:100vh;color:white;background:#0b0f14;font-family:sans-serif;font-size:18px;'>❌ Acesso negado.</div>";
  }
})();
