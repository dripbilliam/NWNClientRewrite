import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import config from './config.mjs';
import { createMarkdown, parseDocument, buildLookup, wireLinks, escapeHtml as e, relativeUrl } from './lib.mjs';

const wikiRoot = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(wikiRoot);
const output = path.join(wikiRoot, '_site');
const excluded = new Set(config.excludedDirectories);
const sources = new Set();
async function crawl(directory) {
  for (const entry of await fs.readdir(path.join(root, directory), { withFileTypes: true })) {
    const source = `${directory}/${entry.name}`;
    if (entry.isSymbolicLink()) continue;
    if (entry.isDirectory() && !excluded.has(entry.name)) await crawl(source);
    else if (entry.isFile() && /\.md$/i.test(entry.name)) sources.add(source);
  }
}
for (const directory of config.roots) await crawl(directory);
for (const source of config.rootFiles) { await fs.access(path.join(root, source)); sources.add(source); }

const md = createMarkdown();
const docs = [];
for (const source of [...sources].sort()) {
  const doc = parseDocument(md, source, await fs.readFile(path.join(root, source), 'utf8'));
  doc.kind = source.startsWith('references/') ? 'Upstream reference' : source.startsWith('evidence/') ? 'Evidence note' : source.startsWith('godot-client/') ? 'Native client note' : /ROADMAP|RESUME|TRACKER/.test(source) ? 'Research log' : 'Project guide';
  if (source === 'REPLACEMENT_CLIENT_ROADMAP.md') doc.title = 'Replacement client roadmap and checkpoint history';
  if (source === 'CASTING_RESUME_NOTE.md') doc.title = 'Casting and client continuation history';
  doc.topics = source.startsWith('references/') ? [] : config.topics.filter(t => t.pattern.test(path.posix.basename(source, '.md'))).map(t => t.id);
  if (!doc.topics.length && !source.startsWith('references/')) doc.topics = ['research'];
  docs.push(doc);
}
const lookup = buildLookup(docs);
const issues = [];
for (const doc of docs) wireLinks(doc, lookup, issues);
const bySource = new Map(docs.map(doc => [doc.source, doc]));
const firstParty = docs.filter(doc => !doc.source.startsWith('references/'));
const upstream = docs.filter(doc => doc.source.startsWith('references/'));
const sortDocs = list => [...list].sort((a, b) => a.title.localeCompare(b.title) || a.source.localeCompare(b.source));

// The generator owns exactly wiki/_site. Refuse symlinks before clearing old output.
if (output !== path.join(root, 'wiki', '_site') || await fs.realpath(wikiRoot) !== wikiRoot) throw new Error('Unsafe wiki output path');
try { if (!(await fs.lstat(output)).isDirectory() || (await fs.lstat(output)).isSymbolicLink()) throw new Error('Wiki output must be a real directory'); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
await fs.rm(output, { recursive: true, force: true });
await fs.mkdir(path.join(output, 'assets'), { recursive: true });
for (const name of ['style.css', 'app.js', 'search.mjs']) await fs.copyFile(path.join(wikiRoot, 'assets', name), path.join(output, 'assets', name));
await fs.writeFile(path.join(output, '.nojekyll'), '');

function nav(from, active) {
  const item = (url, text, id) => `<a ${active === id ? 'aria-current="page"' : ''} href="${relativeUrl(from, url)}">${text}</a>`;
  return `<a class="brand" href="${relativeUrl(from, 'index.html')}"><span class="brand-icon">E</span><span>EntireDecomp<small>RESEARCH WIKI</small></span></a>
    <details class="navigation" open><summary>Browse the wiki</summary><nav aria-label="Main navigation">
    ${item('index.html', 'Overview', 'home')}${item('search.html', 'Search all notes', 'search')}${item('directory.html', 'Document directory', 'directory')}
    <p class="nav-label">TOPICS</p>${config.topics.map(t => item(`topics/${t.id}.html`, e(t.title), t.id)).join('')}
    <p class="nav-label">REFERENCE</p>${item('upstream.html', 'Upstream libraries', 'upstream')}${item('link-health.html', 'Cross-reference audit', 'health')}${item('pages/wiki/README.html', 'Wiki maintenance', 'maintenance')}
    </nav></details><div class="sidebar-note">${firstParty.length} project notes<br>${upstream.length} upstream documents<br><span>Built from repository Markdown</span></div>`;
}
function layout(url, title, content, active = '', toc = '') {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="color-scheme" content="light dark"><meta name="description" content="NWN Enhanced Edition reverse engineering and native client research, linked by topic and source."><title>${e(title)} · EntireDecomp</title><link rel="stylesheet" href="${relativeUrl(url, 'assets/style.css')}"><script type="module" src="${relativeUrl(url, 'assets/app.js')}"></script></head><body><a class="skip-link" href="#main">Skip to content</a><aside class="sidebar">${nav(url, active)}</aside><div class="workspace"><header class="topbar"><span>NWN: Enhanced Edition <span class="separator">/</span> Research library</span><a href="${relativeUrl(url, 'search.html')}">Search <kbd>/</kbd></a></header><div class="reading-layout"><main id="main" tabindex="-1">${content}<footer>EntireDecomp · Source-linked research. Check each note’s date, evidence and scope.</footer></main>${toc}</div></div></body></html>`;
}
async function write(url, title, content, active, toc) {
  await fs.mkdir(path.dirname(path.join(output, url)), { recursive: true });
  await fs.writeFile(path.join(output, url), layout(url, title, content, active, toc));
}
function link(doc, from, label = doc.title) { return `<a href="${relativeUrl(from, doc.url)}">${e(label)}</a>`; }
function cards(list, from) { return `<div class="document-list">${list.map(doc => `<article class="document-row"><div><span class="kind">${e(doc.kind)}</span><h3>${link(doc, from)}</h3><p>${e(doc.summary)}</p><code class="source-path">${e(doc.source)}</code></div><span class="link-count" title="Notes linking here">${doc.incoming.size} ↗</span></article>`).join('')}</div>`; }
function chips(doc, from) { return doc.topics.map(id => `<a class="chip" href="${relativeUrl(from, `topics/${id}.html`)}">${e(config.topics.find(t => t.id === id).title)}</a>`).join(''); }

const home = `<div class="eyebrow">THE RESEARCH LIBRARY</div><h1>Follow the evidence.<br>Find the next connection.</h1><p class="lead">A connected index of NWN: Enhanced Edition research and the native Godot client. Browse a subsystem, search the notes, or follow references back to their source.</p>
<form class="home-search" action="search.html"><label class="sr-only" for="home-query">Search research notes</label><input id="home-query" name="q" type="search" placeholder="Search casting, native ownership, area transitions…"><button>Search notes <span aria-hidden="true">→</span></button></form>
<div class="stats"><div><strong>${firstParty.length}</strong><span>Project notes</span></div><div><strong>${config.topics.length}</strong><span>Research topics</span></div><div><strong>${docs.reduce((sum, d) => sum + d.outgoing.size, 0)}</strong><span>Document connections</span></div></div>
<section><div class="section-heading"><h2>Start here</h2><a href="directory.html">All documents →</a></div><div class="entry-grid">${config.entryPoints.map(entry => { const doc = bySource.get(entry.path); if (!doc) throw new Error(`Missing entry point ${entry.path}`); return `<a class="entry-card" href="${relativeUrl('index.html', doc.url)}"><span class="kind">${e(doc.kind)}</span><h3>${e(entry.label)} <span aria-hidden="true">↗</span></h3><p>${e(entry.description)}</p></a>`; }).join('')}</div></section>
<section><h2>Explore by subsystem</h2><div class="topic-grid">${config.topics.map((t, index) => `<a class="topic-card" href="topics/${t.id}.html"><span class="topic-number">${String(index + 1).padStart(2, '0')}</span><div><h3>${e(t.title)}</h3><p>${e(t.description)}</p><span class="topic-count">${firstParty.filter(d => d.topics.includes(t.id)).length} notes →</span></div></a>`).join('')}</div></section>
<aside class="callout"><strong>Read checkpoints in context</strong><p>Notes retain their original observations, inferences and open questions. A historical passing check does not establish current feature parity. Start with the native client overview, then follow its scoped evidence links.</p></aside>`;
await write('index.html', 'Research overview', home, 'home');

for (const topic of config.topics) {
  const list = firstParty.filter(d => d.topics.includes(topic.id));
  await write(`topics/${topic.id}.html`, topic.title, `<div class="eyebrow">SUBSYSTEM INDEX · ${list.length} NOTES</div><h1>${e(topic.title)}</h1><p class="lead">${e(topic.description)}</p><p class="muted">Topic placement follows document filenames. A note can appear in several topics; references below remain the authored connections.</p>${cards(sortDocs(list), `topics/${topic.id}.html`)}`, topic.id);
}
const kinds = ['Project guide', 'Native client note', 'Evidence note', 'Research log'];
await write('directory.html', 'Document directory', `<div class="eyebrow">PROJECT INDEX</div><h1>Document directory</h1><p class="lead">All ${firstParty.length} project notes, grouped by source. For library documentation, browse <a href="upstream.html">upstream references</a>.</p><div class="jump-links">${kinds.map(kind => `<a href="#${kind.replaceAll(' ', '-').toLowerCase()}">${kind}s</a>`).join('')}</div>${kinds.map(kind => `<section id="${kind.replaceAll(' ', '-').toLowerCase()}"><h2>${kind}s <span class="muted">${firstParty.filter(d => d.kind === kind).length}</span></h2>${cards(sortDocs(firstParty.filter(d => d.kind === kind)), 'directory.html')}</section>`).join('')}`, 'directory');
const libraries = [...new Set(upstream.map(d => d.source.split('/')[1]))].sort();
await write('upstream.html', 'Upstream libraries', `<div class="eyebrow">REFERENCE LIBRARY</div><h1>Upstream libraries</h1><p class="lead">Documentation from reference implementations and their dependencies. These describe their own projects; they are not independent validation of this client.</p>${libraries.map(library => `<section><h2>${e(library)}</h2>${cards(sortDocs(upstream.filter(d => d.source.split('/')[1] === library)), 'upstream.html')}</section>`).join('')}`, 'upstream');

const topicOptions = config.topics.map(t => `<option value="${t.id}">${e(t.title)}</option>`).join('');
await write('search.html', 'Search research notes', `<div class="eyebrow">FULL TEXT SEARCH</div><h1>Find a research note</h1><p class="lead">Search titles, source paths, headings and the full document text.</p><form id="search-form" class="search-form"><label for="query">Words or function names</label><div class="query-row"><input id="query" name="q" type="search" placeholder="e.g. native projectile impact" autocomplete="off"><button>Search</button></div><div class="filters"><label>Topic<select id="topic"><option value="">All topics</option>${topicOptions}</select></label><label>Sources<select id="scope"><option value="project">Project notes</option><option value="all">All documents</option><option value="upstream">Upstream references</option></select></label></div></form><p id="search-status" role="status" aria-live="polite">Enter a few words to search the library.</p><div id="search-results" data-index="search-index.json"></div><noscript><p>Search needs JavaScript. Browse the <a href="directory.html">document directory</a> or topic navigation instead.</p></noscript>`, 'search');

for (const doc of docs) {
  const h1 = doc.headings.find(h => h.level === 1);
  let tokens = doc.tokens;
  // Keep original heading anchors, using the page title for an initial source H1.
  if (tokens[0]?.type === 'heading_open' && tokens[0].tag === 'h1') tokens = tokens.slice(3);
  for (const token of tokens) if (token.type === 'heading_open' || token.type === 'heading_close') token.tag = `h${Math.min(6, Number(token.tag.slice(1)) + 1)}`;
  const body = md.renderer.render(tokens, md.options, {});
  const related = sortDocs([...doc.outgoing].map(source => bySource.get(source)));
  const backlinks = sortDocs([...doc.incoming].map(source => bySource.get(source)));
  const connectionList = list => list.length ? `<ul>${list.map(other => `<li>${link(other, doc.url)} <small>${e(other.source)}</small></li>`).join('')}</ul>` : '<p class="muted">No authored document links in this direction.</p>';
  const content = `<div class="breadcrumbs"><a href="${relativeUrl(doc.url, 'directory.html')}">Library</a><span>/</span>${e(doc.kind)}</div><h1${h1 && doc.tokens[0]?.type === 'heading_open' ? ` id="${e(h1.id)}"` : ''}>${e(doc.title)}</h1><div class="document-meta"><code>${e(doc.source)}</code><a href="${relativeUrl(doc.url, `sources/${doc.source}`)}" download>Markdown source ↓</a></div><div class="chips">${chips(doc, doc.url)}</div>${doc.kind === 'Research log' ? '<aside class="callout"><strong>Retained checkpoint history</strong><p>Entries may supersede earlier entries. Read dates and follow the linked subsystem evidence before treating a checkpoint as current behavior.</p></aside>' : ''}${doc.kind === 'Upstream reference' ? '<p class="callout">Upstream project documentation, retained as reference material.</p>' : ''}<article class="prose">${body}</article><section class="connections" id="wiki-connections"><h2>Document connections</h2><div class="connection-grid"><div><h3>References from this note <span>${related.length}</span></h3>${connectionList(related)}</div><div><h3>Linked from <span>${backlinks.length}</span></h3>${connectionList(backlinks)}</div></div></section>`;
  const toc = `<aside class="toc"><div>ON THIS PAGE</div><nav aria-label="On this page">${doc.headings.filter(h => h.level <= 3).map(h => `<a class="toc-level-${h.level}" href="#${encodeURIComponent(h.id)}">${e(h.title)}</a>`).join('')}<a href="#wiki-connections">Document connections</a></nav></aside>`;
  await write(doc.url, doc.title, content, doc.topics[0], toc);
  await fs.mkdir(path.dirname(path.join(output, 'sources', doc.source)), { recursive: true });
  await fs.copyFile(path.join(root, doc.source), path.join(output, 'sources', doc.source));
}

const broken = issues.filter(i => i.kind !== 'repository-file');
const repositoryFiles = issues.filter(i => i.kind === 'repository-file');
const issueGroups = [...new Set(broken.map(i => i.source))].sort();
await write('link-health.html', 'Cross-reference audit', `<div class="eyebrow">DOCUMENT CONNECTIONS</div><h1>Cross-reference audit</h1><p class="lead">${docs.length} Markdown documents crawled. ${broken.length} unresolved document or heading references; ${repositoryFiles.length} repository file references remain outside the static library.</p><p>Missing headings open the correct document without a fragment. Missing documents and unpublished code, report or asset paths appear as underlined source references with the original path in their tooltip. This audit checks local document links only; it does not check remote URLs.</p><p><a href="link-report.json">Download the complete link report (JSON)</a> · <a href="catalog.json">Download the document graph (JSON)</a></p>${issueGroups.map(source => `<section><h2>${link(bySource.get(source), 'link-health.html')}</h2><ul class="issue-list">${broken.filter(i => i.source === source).map(i => `<li><span class="kind">${e(i.kind)}</span> <code>${e(i.href)}</code>${i.candidates ? `<small>Matches: ${e(i.candidates.join(', '))}</small>` : ''}</li>`).join('')}</ul></section>`).join('') || '<p>No unresolved document or heading references.</p>'}`, 'health');

const catalog = docs.map(({ source, url, title, kind, topics, summary, headings, outgoing, incoming }) => ({ source, url, title, kind, topics, summary, headings, outgoing: [...outgoing].sort(), incoming: [...incoming].sort() }));
await fs.writeFile(path.join(output, 'catalog.json'), JSON.stringify(catalog));
await fs.writeFile(path.join(output, 'search-index.json'), JSON.stringify(docs.map(doc => ({ source: doc.source, url: doc.url, title: doc.title, summary: doc.summary, kind: doc.kind, topics: doc.topics, text: doc.text }))));
await fs.writeFile(path.join(output, 'link-report.json'), JSON.stringify({ documents: docs.length, documentIssues: broken.length, repositoryReferences: repositoryFiles.length, issues }, null, 2));
console.log(`Built ${docs.length} documents (${firstParty.length} project, ${upstream.length} upstream), ${config.topics.length} topics and ${docs.reduce((sum, d) => sum + d.outgoing.size, 0)} connections.`);
console.log(`Source audit: ${broken.length} document/heading issues; ${repositoryFiles.length} unpublished repository references. See _site/link-report.json.`);
console.log(`Static output: ${output}`);
