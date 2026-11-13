// Checks the documentation artifacts, not dynamic reachability or render-tree completion.
const fs = require('node:fs');
const path = require('node:path');

const root = __dirname;
const expectedHash = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const problems = [];
let ledgerCount = 0;
let edgeCount = 0;
let linkCount = 0;
const markdownLinks = new Map();

function checkEvidence(value, location) {
  if (!value || typeof value !== 'object') return;
  for (const [key, item] of Object.entries(value)) {
    if (key.endsWith('evidence_id') && typeof item === 'string' && !/^ev_[0-9a-f]{64}$/.test(item)) {
      problems.push(`${location}: invalid ${key}: ${item}`);
    }
    if (key.endsWith('evidence_ids') && Array.isArray(item)) {
      for (const [index, id] of item.entries()) {
        if (typeof id !== 'string' || !/^ev_[0-9a-f]{64}$/.test(id)) {
          problems.push(`${location}: invalid ${key}[${index}]: ${id}`);
        }
      }
    }
    if (item && typeof item === 'object') checkEvidence(item, `${location}.${key}`);
  }
}

for (const name of fs.readdirSync(root)) {
  const filename = path.join(root, name);
  if (name.endsWith('ledger.json')) {
    let ledger;
    try { ledger = JSON.parse(fs.readFileSync(filename, 'utf8')); }
    catch (error) { problems.push(`${name}: ${error.message}`); continue; }
    ledgerCount++;
    if (ledger.binary_sha256 && ledger.binary_sha256 !== expectedHash) {
      problems.push(`${name}: pinned executable hash mismatch`);
    }
    checkEvidence(ledger, name);
    if (Array.isArray(ledger.edges)) {
      edgeCount += ledger.edges.length;
      const seen = new Set();
      for (const [index, edge] of ledger.edges.entries()) {
        if (edge.callsites !== undefined || edge.callsite_evidence_ids !== undefined) {
          if (!Array.isArray(edge.callsites) || !edge.callsites.length) {
            problems.push(`${name}: edge ${index} has invalid callsites array`);
          } else {
            const sites = new Set();
            for (const site of edge.callsites) {
              if (typeof site !== 'string' || !/^0x[0-9a-f]+$/i.test(site)) {
                problems.push(`${name}: edge ${index} has invalid callsite ${site}`);
              } else if (sites.has(site.toLowerCase())) {
                problems.push(`${name}: edge ${index} repeats callsite ${site}`);
              }
              sites.add(String(site).toLowerCase());
            }
          }
          if (edge.callsite_evidence_ids !== undefined &&
              (!Array.isArray(edge.callsite_evidence_ids) ||
               edge.callsite_evidence_ids.length !== edge.callsites?.length)) {
            problems.push(`${name}: edge ${index} callsite evidence does not align with callsites`);
          }
        }
        // These ledgers retain alternate field names and intentional unresolved targets.
        // Only an identical record is unambiguously accidental duplication.
        const key = JSON.stringify(edge);
        if (seen.has(key)) problems.push(`${name}: identical duplicate edge ${index}`);
        seen.add(key);
      }
    }
  }
  if (name.endsWith('.md')) {
    const markdown = fs.readFileSync(filename, 'utf8');
    const localMarkdown = [];
    for (const match of markdown.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
      const target = match[1].split('#', 1)[0];
      if (!target || /^[a-z]+:/i.test(target)) continue;
      linkCount++;
      if (!fs.existsSync(path.resolve(root, decodeURIComponent(target)))) {
        problems.push(`${name}: missing link target ${target}`);
      }
      const resolved = path.resolve(root, decodeURIComponent(target));
      if (resolved.startsWith(root + path.sep) && resolved.endsWith('.md')) localMarkdown.push(path.basename(resolved));
    }
    markdownLinks.set(name, localMarkdown);
  }
}

// The human map should actually lead to every supplement, and the coverage
// index should name every machine-readable ledger. This checks navigation,
// never completeness of the analyzed binary.
const reachableDocs = new Set(['original-render-tree.md', 'coverage-ledger-index.md']);
const queue = [...reachableDocs];
for (let i = 0; i < queue.length; i++) {
  for (const target of markdownLinks.get(queue[i]) || []) {
    if (!reachableDocs.has(target)) { reachableDocs.add(target); queue.push(target); }
  }
}
for (const name of markdownLinks.keys()) {
  if (!reachableDocs.has(name)) problems.push(`${name}: not linked from the main map or coverage index`);
}
const index = fs.readFileSync(path.join(root, 'coverage-ledger-index.md'), 'utf8');
for (const name of fs.readdirSync(root).filter(file => file.endsWith('ledger.json'))) {
  if (!index.includes(`(${name})`)) problems.push(`${name}: not linked from coverage-ledger-index.md`);
}

process.stdout.write(JSON.stringify({ledgerCount, edgeCount, linkCount,
  reachableDocs: reachableDocs.size, problemCount: problems.length, problems: problems.slice(0, 20)}, null, 2) + '\n');
if (problems.length) process.exitCode = 1;
