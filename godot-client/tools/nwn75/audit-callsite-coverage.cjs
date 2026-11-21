// Reports machine-readable callsite coverage for direct-edge ledger records.
// A nonliteral call can still be valid; this audit never calls it absent.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const binaryPath = process.argv[2];
if (!binaryPath) throw new Error('Usage: node audit-callsite-coverage.cjs <pinned nwmain.exe>');
const sampleLimit = process.argv.includes('--full') ? Infinity : 4;
const bytes = fs.readFileSync(binaryPath);
const digest = crypto.createHash('sha256').update(bytes).digest('hex');
const expected = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
if (digest !== expected) throw new Error(`Binary SHA-256 mismatch: ${digest}`);
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not a PE image');
const optional = pe + 24;
if (bytes.readUInt16LE(optional) !== 0x20b) throw new Error('Expected PE32+');
const base = bytes.readBigUInt64LE(optional + 24);
const sectionTable = optional + bytes.readUInt16LE(pe + 20);
const sections = [];
for (let i = 0; i < bytes.readUInt16LE(pe + 6); i++) {
  const at = sectionTable + 40 * i;
  sections.push({name: bytes.toString('ascii', at, at + 8).replace(/\0.*$/, ''),
    rva: bytes.readUInt32LE(at + 12), size: bytes.readUInt32LE(at + 16), raw: bytes.readUInt32LE(at + 20)});
}
function offsetOf(value) {
  if (!/^0x[0-9a-f]+$/i.test(value || '')) return null;
  const rva = Number(BigInt(value) - base);
  const s = sections.find(section => rva >= section.rva && rva + 5 <= section.rva + section.size);
  return s ? s.raw + rva - s.rva : null;
}
function literalTarget(site) {
  const at = offsetOf(site);
  if (at === null || ![0xe8, 0xe9, 0xeb].includes(bytes[at])) return null;
  const shortJump = bytes[at] === 0xeb;
  return `0x${(BigInt(site) + BigInt(shortJump ? 2 : 5) +
    BigInt(shortJump ? bytes.readInt8(at + 1) : bytes.readInt32LE(at + 1))).toString(16)}`;
}
const pdata = sections.find(s => s.name === '.pdata');
const ranges = [];
if (pdata) for (let at = pdata.raw; at + 12 <= pdata.raw + pdata.size; at += 12) {
  const begin = bytes.readUInt32LE(at), end = bytes.readUInt32LE(at + 4);
  if (begin && end > begin) ranges.push({begin, end});
}
function candidateSites(from, to) {
  if (!/^0x[0-9a-f]+$/i.test(from || '') || !/^0x[0-9a-f]+$/i.test(to || '')) return [];
  const rva = Number(BigInt(from) - base);
  const range = ranges.find(r => r.begin <= rva && rva < r.end);
  if (!range) return [];
  const result = [];
  for (let siteRva = range.begin; siteRva + 5 <= range.end; siteRva++) {
    const site = `0x${(base + BigInt(siteRva)).toString(16)}`;
    const at = offsetOf(site);
    if (at !== null && [0xe8, 0xe9].includes(bytes[at]) &&
        literalTarget(site) === to.toLowerCase()) result.push(site);
  }
  return result;
}
const directKinds = new Set(['direct_static', 'direct_call', 'direct', 'conditional_direct',
  'original_direct_child', 'tail_jump', 'direct_jump_thunk', 'short_tail_jump',
  'original_jump_thunk', 'import_tail_jump', 'jump_thunk']);
const byLedger = [];
const totals = {records: 0, explicitSite: 0, explicitSiteInstances: 0, multiSiteRecords: 0, explicitLiteralMatch: 0,
  explicitLiteralMismatch: 0, explicitNonliteralOrNamedTarget: 0,
  implicitFromLiteral: 0, noMachineSite: 0, oneByteCandidate: 0, multipleByteCandidates: 0};
for (const name of fs.readdirSync(__dirname).filter(file => file.endsWith('ledger.json'))) {
  const ledger = JSON.parse(fs.readFileSync(path.join(__dirname, name), 'utf8'));
  const counts = {records: 0, explicitSite: 0, explicitSiteInstances: 0, multiSiteRecords: 0, explicitLiteralMatch: 0,
    explicitLiteralMismatch: 0, explicitNonliteralOrNamedTarget: 0,
    implicitFromLiteral: 0, noMachineSite: 0, oneByteCandidate: 0, multipleByteCandidates: 0};
  const sample = [];
  for (const edge of ledger.edges || []) {
    if (!directKinds.has(edge.kind)) continue;
    counts.records++;
    const sites = [...new Set([edge.callsite || edge.call_site || edge.site,
      ...(Array.isArray(edge.callsites) ? edge.callsites : [])].filter(site => /^0x[0-9a-f]+$/i.test(site || '')))];
    if (sites.length) {
      counts.explicitSite++;
      counts.explicitSiteInstances += sites.length;
      if (sites.length > 1) counts.multiSiteRecords++;
      const results = sites.map(site => ({site, actual: literalTarget(site)}));
      const expected = /^0x[0-9a-f]+$/i.test(edge.to || '') ? edge.to.toLowerCase() : null;
      const mismatches = expected ? results.filter(result => result.actual && result.actual !== expected) : [];
      if (mismatches.length) {
        counts.explicitLiteralMismatch++;
        if (sample.length < sampleLimit) sample.push({from: edge.from, to: edge.to, kind: edge.kind, mismatches});
      }
      else if (!expected || results.some(result => !result.actual)) counts.explicitNonliteralOrNamedTarget++;
      else counts.explicitLiteralMatch++;
    }
    else if (/^0x[0-9a-f]+$/i.test(edge.to || '') && literalTarget(edge.from) === edge.to.toLowerCase()) counts.implicitFromLiteral++;
    else {
      counts.noMachineSite++;
      const candidates = candidateSites(edge.from, edge.to);
      if (candidates.length === 1) counts.oneByteCandidate++;
      else if (candidates.length > 1) counts.multipleByteCandidates++;
      if (sample.length < sampleLimit) sample.push({from: edge.from, to: edge.to, kind: edge.kind, byteCandidates: candidates.slice(0, 5)});
    }
  }
  if (counts.records) {
    byLedger.push({ledger: name, ...counts, sample});
    for (const key of Object.keys(totals)) totals[key] += counts[key];
  }
}
process.stdout.write(JSON.stringify({binary_sha256: digest,
  scope: 'Only direct-kind machine-readable ledger records; exact sites in prose are not counted. Candidate E8/E9 bytes inside .pdata ranges require instruction-aware confirmation. A non-E8/E9 or computed instruction may be correctly documented elsewhere. Literal mismatches need inspection.',
  totals, byLedger: byLedger.sort((a, b) => b.noMachineSite - a.noMachineSite)}, null, 2) + '\n');
if (totals.explicitLiteralMismatch) process.exitCode = 1;
