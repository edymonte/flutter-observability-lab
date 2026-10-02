// Dispara a suíte completa no BFF e falha (exit 1) se algum cenário divergir.
// Uso: node scripts/run-suite.js [http://localhost:8080]
const base = process.argv[2] || process.env.BFF_URL || 'http://localhost:8080';

(async () => {
  const r = await fetch(`${base}/api/v1/suite/executar`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: '{}',
  });
  const d = await r.json();
  for (const v of d.results) {
    const mark = v.validatorOk ? 'OK ' : 'ERR';
    console.log(`${mark} ${v.scenario.padEnd(22)} falhas=[${v.failed.join(', ')}]`);
    v.checks.filter((c) => !c.matched).forEach((c) => console.log(`      ✗ ${c.id}: ${c.detail}`));
  }
  console.log(`\n${d.validatorOk}/${d.total} cenários com o validador conforme o esperado`);
  process.exit(d.ok ? 0 : 1);
})().catch((e) => {
  console.error('Falha ao chamar o BFF:', e.message);
  process.exit(2);
});
