// Static documentation audit only. A disconnected ledger node can be a missing
// connector, an alternate root, or an intentionally unresolved dynamic edge.
// This is not runtime reachability and is not a completion percentage.
const fs = require('node:fs');
const path = require('node:path');

const directory = __dirname;
const roots = process.argv.slice(2);
if (roots.length === 0) roots.push('0x140c11bdc');
const files = fs.readdirSync(directory).filter(name => name.endsWith('ledger.json'));
const adjacency = new Map();
const perFile = new Map();

for (const file of files) {
  const ledger = JSON.parse(fs.readFileSync(path.join(directory, file), 'utf8'));
  if (!Array.isArray(ledger.edges)) continue;
  const edges = ledger.edges.filter(edge => edge.from && edge.to);
  perFile.set(file, edges);
  for (const edge of edges) {
    let targets = adjacency.get(edge.from);
    if (!targets) adjacency.set(edge.from, targets = new Set());
    targets.add(edge.to);
  }
}

const queue = [...roots];
const reachable = new Set(queue);
for (let cursor = 0; cursor < queue.length; cursor++) {
  for (const target of adjacency.get(queue[cursor]) || []) {
    if (!reachable.has(target)) {
      reachable.add(target);
      queue.push(target);
    }
  }
}

const filesSummary = [...perFile].map(([file, edges]) => {
  const disconnected = edges.filter(edge => !reachable.has(edge.from));
  return {
    file,
    edge_records: edges.length,
    disconnected_source_records: disconnected.length,
    sample: disconnected.slice(0, 8).map(edge => ({ from: edge.from, to: edge.to }))
  };
});

process.stdout.write(JSON.stringify({
  warning: 'Static ledger connectivity only; not runtime reachability or completion.',
  roots,
  reachable_nodes: reachable.size,
  nodes_with_outgoing_edges: adjacency.size,
  disconnected_outgoing_nodes: [...adjacency.keys()].filter(node => !reachable.has(node)).length,
  files: filesSummary
}, null, 2) + '\n');
