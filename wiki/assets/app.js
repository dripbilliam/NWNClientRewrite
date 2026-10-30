import { searchDocuments, excerpt } from './search.mjs';

const navigation = document.querySelector('.navigation');
const smallScreen = matchMedia('(max-width: 850px)');
if (smallScreen.matches) navigation.open = false;
smallScreen.addEventListener('change', event => { navigation.open = !event.matches; });
document.addEventListener('keydown', event => {
  if (event.key !== '/' || event.ctrlKey || event.altKey || event.metaKey || /INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName) || document.activeElement.isContentEditable) return;
  event.preventDefault();
  const input = document.querySelector('#query, #home-query');
  if (input) input.focus();
  else location.href = new URL('../search.html', import.meta.url).href;
});

const form = document.querySelector('#search-form');
if (form) {
  const query = document.querySelector('#query');
  const topic = document.querySelector('#topic');
  const scope = document.querySelector('#scope');
  const status = document.querySelector('#search-status');
  const resultsElement = document.querySelector('#search-results');
  const params = new URLSearchParams(location.search);
  query.value = params.get('q') || '';
  if ([...topic.options].some(o => o.value === params.get('topic'))) topic.value = params.get('topic');
  if ([...scope.options].some(o => o.value === params.get('scope'))) scope.value = params.get('scope');
  let indexPromise;
  let request = 0;
  let debounce;
  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function highlight(container, text, value) {
    const escapedTerms = value.trim().split(/\s+/).filter(Boolean).map(term => term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    if (!escapedTerms.length) { container.textContent = text; return; }
    const pattern = new RegExp(`(${escapedTerms.join('|')})`, 'gi');
    const wholeTerm = new RegExp(`^(?:${escapedTerms.join('|')})$`, 'i');
    for (const part of text.split(pattern)) container.append(wholeTerm.test(part) ? element('mark', '', part) : document.createTextNode(part));
  }
  async function search() {
    const current = ++request;
    const value = query.value.trim();
    const next = new URL(location.href);
    for (const [name, val] of [['q', value], ['topic', topic.value], ['scope', scope.value === 'project' ? '' : scope.value]]) val ? next.searchParams.set(name, val) : next.searchParams.delete(name);
    history.replaceState(null, '', next);
    resultsElement.replaceChildren();
    if (!value) { status.textContent = 'Enter a few words to search the library.'; return; }
    status.textContent = 'Searching the library…';
    try {
      indexPromise ||= fetch(resultsElement.dataset.index).then(response => { if (!response.ok) throw new Error('Search index unavailable'); return response.json(); }).catch(error => { indexPromise = undefined; throw error; });
      const documents = await indexPromise;
      if (current !== request) return;
      const results = searchDocuments(documents, value, { topic: topic.value, scope: scope.value });
      let shown = 0;
      function showMore() {
        resultsElement.querySelector('button')?.remove();
        const batch = results.slice(shown, shown + 60);
        for (const { doc } of batch) {
          const article = element('article', 'document-row');
          const content = element('div');
          content.append(element('span', 'kind', doc.kind));
          const heading = element('h3');
          const link = element('a', '', doc.title);
          link.href = doc.url.split('/').map(encodeURIComponent).join('/');
          heading.append(link);
          const snippet = element('p', 'result-snippet');
          highlight(snippet, excerpt(doc.text, value), value);
          content.append(heading, snippet, element('code', 'source-path', doc.source));
          article.append(content);
          resultsElement.append(article);
        }
        shown += batch.length;
        status.textContent = results.length ? `${results.length} matching ${results.length === 1 ? 'document' : 'documents'}${shown < results.length ? ` · showing ${shown}` : ''}` : 'No matching notes. Try fewer words or include upstream references.';
        if (shown < results.length) {
          const button = element('button', '', 'Show more results');
          button.addEventListener('click', showMore);
          resultsElement.append(button);
        }
      }
      showMore();
    } catch {
      if (current === request) status.textContent = 'Search could not load. Use the document directory, or retry after serving the site over HTTP.';
    }
  }
  form.addEventListener('submit', event => { event.preventDefault(); clearTimeout(debounce); search(); });
  query.addEventListener('input', () => { clearTimeout(debounce); debounce = setTimeout(search, 180); });
  topic.addEventListener('change', search);
  scope.addEventListener('change', search);
  search();
}
