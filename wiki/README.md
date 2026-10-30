# EntireDecomp static research wiki

The wiki crawls the repository’s Markdown notes and builds a static website with topic indexes, full text search, heading links, outgoing references and backlinks. The original notes remain the source of truth. Generated pages preserve their observations, inferences, dates and open questions.

## Build and preview

Run from the repository root with Node.js 22 or newer:

```powershell
npm ci --prefix wiki --ignore-scripts
npm run build --prefix wiki
npm run check --prefix wiki
npm test --prefix wiki
npm run serve --prefix wiki
```

Open `http://127.0.0.1:4174/`. Stop the preview with Ctrl+C. Serve over HTTP rather than opening HTML files directly so browser modules and the search index load correctly. The wiki has its own dependency lockfile; building it does not install Electron or change the game client build.

The generated website is in `wiki/_site/`. It contains only static HTML, CSS, JavaScript, JSON and Markdown source copies. Upload that directory to any static host. Its links are relative, so the same output works at a domain root or under a GitHub Pages repository path. No remote fonts, CDN scripts or backend services are needed.

To simulate a GitHub Pages project subpath locally:

```powershell
$env:WIKI_BASE = '/EntireDecomp'
npm run serve --prefix wiki
```

Then open `http://127.0.0.1:4174/EntireDecomp/`. Remove the environment variable when returning to a root preview.

## Publish on GitHub Pages

The repository includes `.github/workflows/wiki-pages.yml`. In the GitHub repository, select **Settings → Pages → Build and deployment → Source → GitHub Actions**. Run **Build and publish research wiki** manually from Actions, or push documentation changes to `main` or `master`. The workflow builds and checks the wiki, uploads only `wiki/_site`, then deploys it to Pages. Pull requests run validation without deployment.

Commit the wiki sources, its lockfile and the workflow; keep `_site` and dependency/cache directories ignored. This local setup does not enable Pages or publish anything itself. Repository access and Pages visibility are controlled in GitHub. The generated website includes the selected Markdown text and downloadable Markdown copies; review those notes for the audience before enabling publication.

The workflow follows GitHub’s [custom Pages workflow](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages) and [publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site) documentation.

## Crawl coverage

`wiki/config.mjs` selects the root guides and Markdown files below `evidence/`, `godot-client/`, `scripts/` and `references/`. It excludes caches, backups, runtime logs, captures, reports, tools installations and dependency directories. Symbolic links are not followed. Add further documentation roots or explicit files there.

Project notes and upstream library documents have separate indexes. Topic assignment uses documented filename patterns in the configuration; a note can belong to several topics. Placement is navigation, not a judgment about feature completeness or how current a checkpoint is. Start with the native client overview for its entry paths and follow scoped evidence from there.

Game binaries, proprietary images/models, source code and generated reports are not copied. Image references remain labeled text. Raw HTML in Markdown is escaped. Code, asset and report links outside the published documentation retain their authored label with a source-path tooltip.

## Cross references

Normal relative Markdown links work in both the repository and website:

```markdown
[Native ownership](../godot-client/NATIVE-OWNERSHIP.md)
[Combat target and evidence](../evidence/combat-resolution.md#target-and-evidence)
```

The builder also supports wiki-style links in Markdown text:

```markdown
[[godot-client/NATIVE-OWNERSHIP|Native ownership]]
[[NATIVE-OWNERSHIP]]
[[combat-resolution#target-and-evidence|Combat evidence]]
```

Use an explicit repository path for duplicate names such as README. Exact relative paths resolve first; wiki links can also resolve by a unique basename or document title. Ambiguous aliases are listed in the audit. Heading IDs follow GitHub-style slugs, including suffixes for repeated headings. Wiki syntax inside code blocks or inline code remains literal.

Every authored document link contributes to the destination’s **Linked from** section and the source’s **References from this note** section. The build does not insert guessed references or edit existing research notes.

## Audit and machine references

The website’s **Cross-reference audit** lists unresolved Markdown documents, heading fragments and ambiguous wiki links. A missing heading opens the correct document without its stale fragment. Unavailable documents render as labeled source references, avoiding dead website links. These source issues are reported rather than failing the build; they may describe retained historical evidence. The audit does not check external URL availability.

`npm run check --prefix wiki` checks every generated local HTML link, script, stylesheet and heading target, and confirms search coverage and reciprocal backlinks. It fails for broken generated navigation. `npm test --prefix wiki` exercises link resolution, ambiguity, wiki syntax, escaping and search behavior.

Generated machine-readable files at the site root:

| File | Contents |
| --- | --- |
| `catalog.json` | Source path, page URL, title, topics, headings and incoming/outgoing document edges |
| `search-index.json` | All indexed documents and extracted full text |
| `link-report.json` | Original link destinations and the reason each could not be published directly |

Rebuild after adding, moving or editing Markdown files to refresh the graph and search index. Builds read the current working tree, including selected untracked notes; GitHub builds read only committed files.
