// Detecção de dados sensíveis em logs (PAN, CVV, CPF).
// Espelha o que o Sensitive Data Scanner do Datadog deveria bloquear.

const PAN_CANDIDATE = /\b(?:\d[ -]?){12,18}\d\b/g;
const CPF = /\b\d{3}\.\d{3}\.\d{3}-\d{2}\b/;
const SKIP_KEYS = /(^|_)(trace_id|span_id|parent_id)$|^dd$/;

function luhnValid(digits) {
  let sum = 0;
  let dbl = false;
  for (let i = digits.length - 1; i >= 0; i--) {
    let d = digits.charCodeAt(i) - 48;
    if (dbl) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    dbl = !dbl;
  }
  return sum % 10 === 0;
}

function findPans(text) {
  const out = [];
  for (const m of String(text).matchAll(PAN_CANDIDATE)) {
    const digits = m[0].replace(/[ -]/g, '');
    if (digits.length >= 13 && digits.length <= 19 && luhnValid(digits)) out.push(digits);
  }
  return out;
}

function maskPanInString(text) {
  return String(text).replace(PAN_CANDIDATE, (m) => {
    const digits = m.replace(/[ -]/g, '');
    if (digits.length < 13 || digits.length > 19 || !luhnValid(digits)) return m;
    return `****${digits.slice(-4)}`;
  });
}

// Percorre o registro de log e devolve achados { path, type }.
function scanRecord(record) {
  const findings = [];
  const walk = (value, path) => {
    if (value === null || value === undefined) return;
    if (typeof value === 'object') {
      for (const [k, v] of Object.entries(value)) {
        if (SKIP_KEYS.test(k)) continue;
        if (/^cvv$|^cvc$|security_code/i.test(k) && v && v !== '[REDACTED]') {
          findings.push({ path: `${path}${k}`, type: 'CVV' });
          continue;
        }
        walk(v, `${path}${k}.`);
      }
      return;
    }
    if (typeof value === 'string' || typeof value === 'number') {
      const s = String(value);
      if (findPans(s).length) findings.push({ path: path.slice(0, -1), type: 'PAN' });
      if (CPF.test(s)) findings.push({ path: path.slice(0, -1), type: 'CPF' });
    }
  };
  walk(record, '');
  return findings;
}

module.exports = { luhnValid, findPans, maskPanInString, scanRecord };
