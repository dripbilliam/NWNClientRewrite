export function searchDocuments(documents, query, { topic = '', scope = 'project' } = {}) {
  const terms = [...new Set(query.trim().toLowerCase().split(/\s+/).filter(Boolean))];
  if (!terms.length) return [];
  const results = [];
  for (const doc of documents) {
    const upstream = doc.source.startsWith('references/');
    if (scope === 'project' && upstream || scope === 'upstream' && !upstream || topic && !doc.topics.includes(topic)) continue;
    const title = doc.title.toLowerCase();
    const source = doc.source.toLowerCase();
    const text = doc.text.toLowerCase();
    if (!terms.every(term => title.includes(term) || source.includes(term) || text.includes(term))) continue;
    const phrase = query.toLowerCase().trim();
    const filename = source.split('/').pop().replace(/\.md$/, '').replace(/[-_]+/g, ' ');
    const score = terms.reduce((sum, term) => sum + (title.includes(term) ? 12 : 0) + (source.includes(term) ? 6 : 0) + (text.includes(term) ? 1 : 0), 0) + (title.includes(phrase) ? 15 : 0) + (filename.includes(phrase) ? 25 : 0);
    results.push({ doc, score });
  }
  return results.sort((a, b) => b.score - a.score || a.doc.title.localeCompare(b.doc.title));
}

export function excerpt(text, query, length = 260) {
  const terms = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
  const lower = text.toLowerCase();
  const first = Math.min(...terms.map(term => lower.indexOf(term)).filter(index => index >= 0));
  const start = Number.isFinite(first) ? Math.max(0, first - 80) : 0;
  return (start > 0 ? '…' : '') + text.slice(start, start + length).replace(/\s+/g, ' ') + (start + length < text.length ? '…' : '');
}
