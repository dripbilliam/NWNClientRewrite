import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const output = fileURLToPath(new URL('./_site/', import.meta.url));
const files = [];
async function crawl(directory) { for (const entry of await fs.readdir(directory, { withFileTypes: true })) { const file = path.join(directory, entry.name); if (entry.isDirectory()) await crawl(file); else files.push(file); } }
await crawl(output);
const fileSet = new Set(files);
const ids = new Map();
const html = new Map();
const errors = [];
for (const file of files.filter(file => file.endsWith('.html'))) {
  const content = await fs.readFile(file, 'utf8');
  html.set(file, content);
  const anchors = [...content.matchAll(/\bid="([^"]*)"/g)].map(match => match[1]);
  if (new Set(anchors).size !== anchors.length) errors.push(`${path.relative(output, file)}: duplicate heading or element ID`);
  ids.set(file, new Set(anchors));
  if (!content.includes('<title>') || !content.includes('id="main"')) errors.push(`${file}: missing document shell`);
}
let links = 0;
for (const [file, content] of html) {
  for (const [, attr, encoded] of content.matchAll(/\b(href|src)="([^"]*)"/g)) {
    const href = encoded.replaceAll('&amp;', '&');
    if (/^(?:https?:|mailto:|tel:)/i.test(href)) continue;
    if (href.startsWith('/') || /^[a-z][a-z\d+.-]*:/i.test(href)) { errors.push(`${file}: nonportable ${attr} ${href}`); continue; }
    const [rawPath, fragment] = href.split('#');
    const target = path.resolve(path.dirname(file), decodeURIComponent(rawPath.split('?')[0] || path.basename(file)));
    links++;
    if (!target.startsWith(output) || !fileSet.has(target)) errors.push(`${path.relative(output, file)}: missing target ${href}`);
    else if (fragment && ids.has(target) && !ids.get(target).has(decodeURIComponent(fragment))) errors.push(`${path.relative(output, file)}: missing anchor ${href}`);
  }
}
const catalog = JSON.parse(await fs.readFile(path.join(output, 'catalog.json'), 'utf8'));
const bySource = new Map(catalog.map(doc => [doc.source, doc]));
for (const doc of catalog) for (const target of doc.outgoing) if (!bySource.get(target)?.incoming.includes(doc.source)) errors.push(`Missing backlink ${doc.source} -> ${target}`);
const search = JSON.parse(await fs.readFile(path.join(output, 'search-index.json'), 'utf8'));
if (search.length !== catalog.length) errors.push('Search index does not cover the complete catalog');
if (errors.length) { console.error(errors.slice(0, 50).join('\n')); console.error(`${errors.length} generated-site errors`); process.exitCode = 1; }
else console.log(`Checked ${html.size} HTML pages, ${links} local links and anchors, ${catalog.length} indexed documents, and every backlink. All generated references resolve.`);
