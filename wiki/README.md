# Static documentation wiki

The wiki builds a static, searchable website from the current repository guides and retained operational references. Historical Markdown is compressed in the [documentation archive](../docs/archive.md), rather than crawled as hundreds of competing status pages.

## Build and preview

From the repository root, with compatible Node.js:

```powershell
npm ci --prefix wiki --ignore-scripts
npm test --prefix wiki
npm run build --prefix wiki
npm run check --prefix wiki
npm run serve --prefix wiki
```

Open `http://127.0.0.1:4174/`. Generated output is `wiki/_site/`; dependencies and output stay ignored. HTTP serving is required for search modules. The wiki build does not build or launch the game.

For a repository subpath, set `$env:WIKI_BASE = '/NWNClientRewrite'` before serving. Remove it to return to a root preview.

## Sources and links

`wiki/config.mjs` selects `docs/`, native operational references, scripts, evidence and upstream references. It excludes archives, caches, backups, reports, runtime logs and dependencies. The historical ZIP and raw evidence are not published or copied by the wiki.

Normal relative Markdown links resolve to published pages when the destination is included. Links to code, archives or nonpublished artifacts are labeled source references. Wiki-style aliases are supported; ambiguous aliases and missing headings appear in the cross-reference audit.

The builder provides full-text search, topic indexes, source paths, outgoing links and reciprocal backlinks. Generated `catalog.json`, `search-index.json` and `link-report.json` record that graph. `npm run check --prefix wiki` validates generated local links, assets, heading targets, search coverage and backlinks.

## Publishing

The existing `.github/workflows/wiki-pages.yml` validates pull requests and can publish `wiki/_site/` through GitHub Pages on configured main/master pushes or manual workflow dispatch. Repository access and Pages visibility are controlled in GitHub.

This cleanup neither enables Pages nor triggers a deployment. Review documentation for its intended audience before publishing; archive history and local/private evidence remain repository-side references.

## Maintenance

Edit an existing [topic guide](../docs/README.md), then rebuild. Do not create a new checkpoint or handoff document for every run. New durable API/operational references should have a clear owner and a link from the documentation index.
