import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createMarkdown, parseDocument, buildLookup, wireLinks, resolveLink, relativeUrl } from '../lib.mjs';
import { searchDocuments, excerpt } from '../assets/search.mjs';

test('Markdown links and wikilinks resolve across directories, with reciprocal backlinks', () => {
  const md = createMarkdown();
  const a = parseDocument(md, 'evidence/casting.md', '# Casting\n\n[Godot](../godot-client/NATIVE-SPELLBOOK.md#spell-slots) and [[NATIVE-SPELLBOOK|Spellbook]].\n');
  const b = parseDocument(md, 'godot-client/NATIVE-SPELLBOOK.md', '# Native spellbook\n\n## Spell slots\n\n## Spell slots\n');
  const lookup = buildLookup([a, b]);
  const issues = [];
  wireLinks(a, lookup, issues);
  assert.deepEqual(issues, []);
  assert.deepEqual([...a.outgoing], [b.source]);
  assert.deepEqual([...b.incoming], [a.source]);
  assert.equal(b.headings[2].id, 'spell-slots-1');
  const html = md.renderer.render(a.tokens, md.options, {});
  assert.match(html, /href="..\/godot-client\/NATIVE-SPELLBOOK.html#spell-slots"/);
  assert.match(html, />Spellbook<\/a>/);
});

test('ambiguous aliases are reported; explicit paths resolve', () => {
  const md = createMarkdown();
  const a = parseDocument(md, 'README.md', '# Main');
  const b = parseDocument(md, 'a/SHARED.md', '# A');
  const c = parseDocument(md, 'b/SHARED.md', '# B');
  const lookup = buildLookup([a, b, c]);
  assert.equal(resolveLink('SHARED', 'evidence/x.md', lookup, true).issue, 'ambiguous-wikilink');
  assert.equal(resolveLink('a/SHARED', a.source, lookup, true).target, b);
});

test('unavailable source links render without dead anchors; missing headings fall back to the document', () => {
  const md = createMarkdown();
  const a = parseDocument(md, 'evidence/a.md', '# A\n\n[Code](../src/a.js) [Missing](missing.md) [Old](a.md#old) [[javascript:alert(1)|Unsafe]]\n\n`[[not-a-link]]`\n');
  const issues = [];
  wireLinks(a, buildLookup([a]), issues);
  const html = md.renderer.render(a.tokens, md.options, {});
  assert.match(html, /href="a.html"/);
  assert.doesNotMatch(html, /href="(?:javascript|missing|..\/src)/);
  assert.match(html, /<code>\[\[not-a-link\]\]<\/code>/);
  assert.deepEqual(issues.map(i => i.kind), ['repository-file', 'missing-document', 'missing-heading', 'unsupported-scheme']);
  assert.equal((html.match(/<span /g) || []).length, (html.match(/<\/span>/g) || []).length);
});

test('raw HTML stays inert and relative URLs support repository subpaths', () => {
  const md = createMarkdown();
  assert.match(md.render('<script>alert(1)</script>'), /&lt;script&gt;/);
  assert.equal(relativeUrl('pages/evidence/a.html', 'assets/style.css'), '../../assets/style.css');
  assert.equal(relativeUrl('pages/a.html', 'pages/a name.html'), 'a%20name.html');
});

test('search ranks titles and paths, requires all terms, and filters sources and topics', () => {
  const docs = [
    { source: 'evidence/casting.md', title: 'Casting', text: 'The native spell system', topics: ['spells'] },
    { source: 'godot-client/NATIVE-CASTING.md', title: 'Native casting', text: 'Current native spell system', topics: ['spells', 'native-client'] },
    { source: 'references/a/README.md', title: 'Native casting library', text: 'Native casting reference', topics: [] }
  ];
  assert.equal(searchDocuments(docs, 'native casting')[0].doc.source, docs[1].source);
  assert.equal(searchDocuments(docs, 'native casting').length, 2);
  assert.equal(searchDocuments(docs, 'native casting', { scope: 'all' }).length, 3);
  assert.equal(searchDocuments(docs, 'native', { topic: 'native-client' }).length, 1);
  assert.equal(searchDocuments(docs, 'native', { scope: 'upstream' })[0].doc.source, docs[2].source);
  assert.equal(searchDocuments(docs, 'nothing').length, 0);
  assert.equal(searchDocuments(docs, '').length, 0);
  assert.match(excerpt('x'.repeat(400) + ' needle ' + 'y'.repeat(400), 'needle'), /needle/);
});
