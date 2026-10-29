// Lee los reportes de Apache Benchmark en results/*.txt y arma una tabla
// con las métricas que pide el TP: latencia promedio, p95, p99 y máxima.
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'results');
const archivos = fs.readdirSync(dir).filter((f) => /^\d\d_.*\.txt$/.test(f)).sort();

const num = (txt, re) => {
  const m = txt.match(re);
  return m ? Number(m[1]) : null;
};

const filas = archivos.map((f) => {
  const t = fs.readFileSync(path.join(dir, f), 'utf8');
  return {
    escenario: f.replace('.txt', ''),
    concurrencia: num(t, /Concurrency Level:\s+(\d+)/),
    peticiones: num(t, /Complete requests:\s+(\d+)/),
    rps: num(t, /Requests per second:\s+([\d.]+)/),
    promedio: num(t, /Time per request:\s+([\d.]+) \[ms\] \(mean\)\n/),
    p50: num(t, /\n\s+50%\s+(\d+)/),
    p95: num(t, /\n\s+95%\s+(\d+)/),
    p99: num(t, /\n\s+99%\s+(\d+)/),
    max: num(t, /\n\s+100%\s+(\d+)/),
    fallidas: (num(t, /Failed requests:\s+(\d+)/) || 0) + (num(t, /Non-2xx responses:\s+(\d+)/) || 0),
  };
});

const v = (x) => (x === null ? '—' : x);
console.log('| Escenario | Concurrencia | Peticiones | Req/s | Promedio (ms) | p50 (ms) | p95 (ms) | p99 (ms) | Máx (ms) | Errores |');
console.log('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
for (const r of filas) {
  const pctErr = r.peticiones ? ((r.fallidas / r.peticiones) * 100).toFixed(1) + '%' : '—';
  console.log(
    `| ${r.escenario} | ${v(r.concurrencia)} | ${v(r.peticiones)} | ${v(r.rps)} | ${v(r.promedio)} | ` +
      `${v(r.p50)} | ${v(r.p95)} | ${v(r.p99)} | ${v(r.max)} | ${r.fallidas} (${pctErr}) |`
  );
}
