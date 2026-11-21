// Idempotently add REA-confirmed GUI call sites without reformatting the ledger.
const fs = require('node:fs');
const path = require('node:path');

const directory = __dirname;
const evidence = JSON.parse(fs.readFileSync(path.join(directory, 'gui-callsite-instruction-evidence.json'), 'utf8'));
const multiEvidence = JSON.parse(fs.readFileSync(path.join(directory, 'gui-multisite-instruction-evidence.json'), 'utf8'));
const ledgerPath = path.join(directory, 'gui-presentation-ledger.json');
const source = fs.readFileSync(ledgerPath, 'utf8');
const ledger = JSON.parse(source);
const expected = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
if (evidence.binary_sha256 !== expected || multiEvidence.binary_sha256 !== expected || ledger.binary_sha256 !== expected) throw Error('Pinned binary identity mismatch');
if (evidence.schema !== 'nwn75-gui-callsite-instruction-evidence-v1') throw Error('Unexpected evidence schema');
if (multiEvidence.schema !== 'nwn75-gui-multisite-instruction-evidence-v1') throw Error('Unexpected multi-site evidence schema');
const newline = source.includes('\r\n') ? '\r\n' : '\n';
const lines = source.split(/\r?\n/);
const keys = new Set();
let inserted = 0, alreadyPresent = 0;
for (const row of evidence.records) {
  if (!/^0x[0-9a-f]+$/i.test(row.from) || !/^0x[0-9a-f]+$/i.test(row.to) ||
      !/^0x[0-9a-f]+$/i.test(row.callsite) || !/^ev_[0-9a-f]{64}$/.test(row.instruction_evidence_id)) throw Error('Invalid evidence record');
  const key = `${row.from}/${row.to}`;
  if (keys.has(key)) throw Error(`Duplicate evidence edge ${key}`);
  keys.add(key);
  const needle = `"from":"${row.from}","to":"${row.to}"`;
  const matches = lines.map((line, index) => line.includes(needle) ? index : -1).filter(index => index >= 0);
  if (matches.length !== 1) throw Error(`Expected one ledger row for ${key}; found ${matches.length}`);
  const index = matches[0], line = lines[index];
  const siteField = `"callsite":"${row.callsite}"`;
  const evidenceField = `"callsite_evidence_id":"${row.instruction_evidence_id}"`;
  if (line.includes('"callsite":')) {
    if (!line.includes(siteField)) throw Error(`Conflicting callsite for ${key}`);
    if (line.includes('"callsite_evidence_id":') && !line.includes(evidenceField)) throw Error(`Conflicting instruction evidence for ${key}`);
    if (!line.includes('"callsite_evidence_id":')) lines[index] = line.replace(siteField, `${siteField},${evidenceField}`);
    alreadyPresent++;
  } else {
    lines[index] = line.replace(needle, `${needle},${siteField},${evidenceField}`);
    inserted++;
  }
}
let multiInserted = 0, multiAlreadyPresent = 0;
for (const row of multiEvidence.records) {
  const key = `${row.from}/${row.to}`;
  if (keys.has(key)) throw Error(`Evidence edge appears in both single and multi-site sets: ${key}`);
  keys.add(key);
  if (!Array.isArray(row.sites) || row.sites.length < 2 || new Set(row.sites.map(s => s.callsite)).size !== row.sites.length) throw Error(`Invalid multi-site set ${key}`);
  if (row.sites.some(s => !/^0x[0-9a-f]+$/i.test(s.callsite) || !/^ev_[0-9a-f]{64}$/.test(s.instruction_evidence_id))) throw Error(`Invalid multi-site evidence ${key}`);
  const needle = `"from":"${row.from}","to":"${row.to}"`;
  const matches = lines.map((line, index) => line.includes(needle) ? index : -1).filter(index => index >= 0);
  if (matches.length !== 1) throw Error(`Expected one multi-site ledger row for ${key}; found ${matches.length}`);
  const index = matches[0], line = lines[index];
  const siteField = `"callsites":${JSON.stringify(row.sites.map(s => s.callsite))}`;
  const evidenceField = `"callsite_evidence_ids":${JSON.stringify(row.sites.map(s => s.instruction_evidence_id))}`;
  if (line.includes('"callsites":')) {
    if (!line.includes(siteField) || !line.includes(evidenceField)) throw Error(`Conflicting multi-site evidence for ${key}`);
    multiAlreadyPresent++;
  } else {
    if (line.includes('"callsite":')) throw Error(`Single callsite already recorded for multi-site edge ${key}`);
    lines[index] = line.replace(needle, `${needle},${siteField},${evidenceField}`);
    multiInserted++;
  }
}
const output = lines.join(newline);
JSON.parse(output);
if (output !== source) fs.writeFileSync(ledgerPath, output);
process.stdout.write(JSON.stringify({records: evidence.records.length, inserted, alreadyPresent,
  multiRecords: multiEvidence.records.length, multiInserted, multiAlreadyPresent, changed: output !== source}) + '\n');
