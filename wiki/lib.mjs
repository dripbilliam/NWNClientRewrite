import path from 'node:path';
import MarkdownIt from 'markdown-it';
import GithubSlugger from 'github-slugger';

export const escapeHtml = value => String(value).replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
export const pagePath = source => `pages/${source.replace(/\.md$/i, '.html')}`;
export const relativeUrl = (from, to) => path.posix.relative(path.posix.dirname(from), to).split('/').map(encodeURIComponent).join('/') || './';
export const key = value => value.replaceAll('\\', '/').replace(/^\.\//, '').toLowerCase();
export const stripFrontmatter = source => source.replace(/^\uFEFF/, '').replace(/^---\r?\n[\s\S]*?\r?\n---(?:\r?\n|$)/, '');
export function plainText(tokens) {
  return tokens.map(t => t.type === 'inline' ? inlineText(t.children || []) : ['fence', 'code_block'].includes(t.type) ? t.content : '').filter(Boolean).join('\n');
}
function inlineText(tokens) { return tokens.map(t => ['text', 'code_inline'].includes(t.type) ? t.content : t.type === 'image' ? t.content : ['softbreak', 'hardbreak'].includes(t.type) ? ' ' : '').join(''); }

export function createMarkdown() {
  const md = new MarkdownIt({ html: false, linkify: true, typographer: false });
  md.inline.ruler.before('link', 'wikilink', (state, silent) => {
    if (!state.src.startsWith('[[', state.pos) || state.linkLevel > 0) return false;
    const end = state.src.indexOf(']]', state.pos + 2);
    if (end < 0) return false;
    const body = state.src.slice(state.pos + 2, end);
    if (!body || body.includes('\n')) return false;
    if (!silent) {
      const [target, ...label] = body.split('|');
      const open = state.push('link_open', 'a', 1);
      open.attrSet('href', target.trim());
      open.meta = { wiki: true };
      state.push('text', '', 0).content = label.join('|') || target;
      state.push('link_close', 'a', -1);
    }
    state.pos = end + 2;
    return true;
  });
  // Local images may contain unlicensed game artwork; preserve the reference as text.
  md.renderer.rules.image = (tokens, index) => {
    const token = tokens[index];
    return `<span class="asset-reference" title="Image remains in the source repository">[Image: ${escapeHtml(token.content || token.attrGet('src'))}]</span>`;
  };
  return md;
}

export function parseDocument(md, source, text) {
  const tokens = md.parse(stripFrontmatter(text), {});
  const slugger = new GithubSlugger();
  const headings = [];
  for (let i = 0; i < tokens.length; i++) {
    if (tokens[i].type !== 'heading_open') continue;
    const title = inlineText(tokens[i + 1].children || []);
    const id = slugger.slug(title);
    tokens[i].attrSet('id', id);
    headings.push({ title, id, level: Number(tokens[i].tag.slice(1)) });
  }
  const title = headings.find(h => h.level === 1)?.title || source.split('/').pop().replace(/\.md$/i, '').replaceAll(/[-_]/g, ' ');
  const textContent = plainText(tokens);
  // A paragraph is more useful than a heading or code block as a search preview.
  const firstParagraph = tokens.find((t, i) => t.type === 'inline' && tokens[i - 1]?.type === 'paragraph_open');
  const summary = (firstParagraph ? inlineText(firstParagraph.children || []) : textContent).replace(/\s+/g, ' ').slice(0, 230);
  return { source, url: pagePath(source), title, headings, summary, text: textContent, tokens, outgoing: new Set(), incoming: new Set() };
}

export function buildLookup(documents) {
  const paths = new Map(documents.map(doc => [key(doc.source), doc]));
  const aliases = new Map();
  for (const doc of documents) {
    for (const alias of [doc.source.replace(/\.md$/i, ''), path.posix.basename(doc.source, path.posix.extname(doc.source)), doc.title]) {
      const k = key(alias);
      if (!aliases.has(k)) aliases.set(k, new Set());
      aliases.get(k).add(doc);
    }
  }
  return { paths, aliases };
}

export function resolveLink(href, source, lookup, wiki = false) {
  let decoded;
  try { decoded = decodeURIComponent(href.replaceAll('\\', '/')); } catch { decoded = href; }
  if (/^(?:https?:|mailto:|tel:)/i.test(decoded)) return { external: true, href };
  if (/^[a-z][a-z\d+.-]*:/i.test(decoded) || decoded.startsWith('//')) return { issue: 'unsupported-scheme' };
  const hashAt = decoded.indexOf('#');
  const fragment = hashAt < 0 ? '' : decoded.slice(hashAt + 1);
  const pathname = (hashAt < 0 ? decoded : decoded.slice(0, hashAt)).split('?')[0];
  let target;
  if (!pathname) target = lookup.paths.get(key(source));
  else {
    const relative = pathname.startsWith('/') ? pathname.slice(1) : path.posix.normalize(path.posix.join(path.posix.dirname(source), pathname));
    target = lookup.paths.get(key(relative));
    if (wiki && !target) {
      target = lookup.paths.get(key(relative + '.md')) || lookup.paths.get(key(pathname)) || lookup.paths.get(key(pathname + '.md'));
      if (!target) {
        const candidates = lookup.aliases.get(key(pathname.replace(/\.md$/i, '')));
        if (candidates?.size === 1) target = [...candidates][0];
        else if (candidates?.size > 1) return { issue: 'ambiguous-wikilink', candidates: [...candidates].map(d => d.source) };
      }
    }
  }
  if (!target) return { issue: /\.md$/i.test(pathname) || wiki ? 'missing-document' : 'repository-file' };
  const validFragment = !fragment || target.headings.some(h => h.id === fragment);
  return { target, fragment, issue: validFragment ? null : 'missing-heading' };
}

export function wireLinks(doc, lookup, issues) {
  function visit(tokens) {
    for (const token of tokens) {
      if (token.type === 'link_open') {
        const href = token.attrGet('href');
        const result = resolveLink(href, doc.source, lookup, token.meta?.wiki);
        if (result.external) {
          token.attrSet('rel', 'noreferrer');
        } else if (result.target) {
          const target = result.target;
          token.attrSet('href', relativeUrl(doc.url, target.url) + (result.issue ? '' : result.fragment ? '#' + encodeURIComponent(result.fragment) : ''));
          if (target !== doc) { doc.outgoing.add(target.source); target.incoming.add(doc.source); }
          if (result.issue) token.attrSet('title', `Original heading no longer exists: #${result.fragment}. Opens the document instead.`);
        } else {
          // Keep the authored label, but do not emit a dead or unsafe site link.
          token.tag = 'span';
          token.attrs = [['class', 'source-reference'], ['title', `Source reference (${result.issue}): ${href}`]];
          token.meta = { unavailable: true };
        }
        if (result.issue) issues.push({ source: doc.source, href, kind: result.issue, ...(result.candidates ? { candidates: result.candidates } : {}) });
      }
      if (token.children) visit(token.children);
    }
    // Match the close token to any unavailable opening token.
    const stack = [];
    for (const token of tokens) {
      if (token.type === 'link_open') stack.push(token.meta?.unavailable || false);
      else if (token.type === 'link_close' && stack.pop()) token.tag = 'span';
    }
  }
  visit(doc.tokens);
}
