# Linear to GitHub Projects roadmap sync

Mirrors approved Linear tickets into **Projects V2 draft cards**. Linear remains authoritative and is never modified. This utility never creates repository Issues, creates a Project, changes its visibility, or creates status fields.

The configured destination for NWNClientRewrite is [dripbilliam's project 3](https://github.com/users/dripbilliam/projects/3). Runtime code is isolated here and has no npm dependencies. It requires Node.js 22 or later.

## How it works

1. Verify the configured Linear scope and discover its actual workflow statuses.
2. Fetch every issue page, including archived records, and every label page. There is no creation-date cutoff.
3. Read the GitHub Project, status options and all item pages, including archived items.
4. Match managed draft cards by a UUID marker in their bodies. Titles are never identity keys.
5. Plan additions, changed titles/bodies, status changes and retirement actions. Unchanged cards receive no writes.
6. Apply the plan only with explicit `--apply`. API/source fetch failures abort before writes; write failures stop the run and suppress cleanup.

The body contains a Linear identifier/link and an HTML comment:

```html
<!-- linear-project-sync:v1 nwnanalog-public-roadmap 00000000-0000-4000-8000-000000000001 -->
```

Keep `SYNC_NAMESPACE` stable. Removing a marker entirely makes a card unmanaged; malformed reserved markers abort the run to prevent duplicates. Other drafts, repository issues, PRs, redacted items and other namespaces remain untouched.

## GitHub board and credentials

For a new destination, create a user- or organization-owned **Projects V2** project, choose the Kanban/Board layout, and group by Status. Set public visibility manually, give the public read access, and restrict write access to maintainers. Linking the Project to this repository is useful for discovery but does not turn drafts into repository issues.

Create these Status options, or configure mappings to your existing options:

`Backlog`, `Todo`, `In Progress`, `Testing`, `Done`, `Cancelled`.

Disable competing project automations that overwrite statuses or archive managed cards. Eligible cards manually archived in GitHub are unarchived on the next successful sync.

Create a dedicated GitHub **classic personal access token** with `project` scope and access to the destination Project. Queries alone can use `read:project`. No `repo`, `workflow` or repository Issues permission is required by this utility. The default Actions `GITHUB_TOKEN` cannot manage this user-owned Project.

Fine-grained PATs currently do not support user-owned Projects. For an organization-owned destination, a GitHub App installation token with organization Projects read/write permission is another option. The runtime accepts an already issued token; it does not mint/refresh App tokens.

See [GitHub Projects API authentication](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects#authentication) and [PAT limitations](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#fine-grained-personal-access-tokens-limitations). Rotate expiring credentials before they expire.

In **repository Settings → Secrets and variables → Actions**, add repository secrets:

| Secret | Value |
| --- | --- |
| `GH_PROJECT_TOKEN` | GitHub token with Project access |
| `LINEAR_API_KEY` | Dedicated Linear API key with read access to the selected scope |

The current repository's existing `GM_PROJECT_TOKEN` secret is accepted as a compatibility alias. A secret named `GH_PROJECT_TOKEN` takes precedence. Never put a token in repository variables.

Create the Linear key through **Linear Settings → Security & access → Personal API keys**. Restrict it to read access and the relevant team where available. Never put either key in a workflow, commit, issue body or chat. See [Linear API authentication](https://linear.app/developers/graphql).

## Repository Actions variables

Add these under the **Variables** tab in the same repository settings:

| Variable | Configuration |
| --- | --- |
| `LINEAR_PROJECT_ID` | Linear project UUID; use this for the NWNAnalog project |
| `LINEAR_TEAM_ID` | Optional team UUID; at least one of team/project is required |
| `GH_PROJECT_OWNER` | `dripbilliam` (workflow default) |
| `GH_PROJECT_OWNER_TYPE` | `user` (default), or `organization` |
| `GH_PROJECT_NUMBER` | `3` (workflow default) |
| `STATUS_MAPPING_JSON` | The mapping below |
| `LINEAR_SYNC_ENABLED` | Leave unset/false until the first dry run is approved |

Use UUIDs, not Linear names or issue identifiers. Get them from Linear or its read-only GraphQL API. Providing both team and project means **their intersection**, not their union. Use a key with stable access to the entire configured scope.

For the current workflow, set `STATUS_MAPPING_JSON` to:

```json
{"In Review":"Testing","Canceled":"Cancelled","Duplicate":"Cancelled"}
```

Mapping keys can be actual Linear status UUIDs or names. UUID keys take precedence. Names are matched case-insensitively to existing GitHub option names. Otherwise, an actual Linear status name matching a GitHub option is used directly. Statuses are discovered at runtime; their names are not hardcoded into source.

Unknown statuses log a warning and skip the issue by default, preserving any existing card. Set `UNKNOWN_STATUS_POLICY=fallback` and `STATUS_FALLBACK=Backlog` for an explicit fallback, or `UNKNOWN_STATUS_POLICY=error` to abort planning. Missing target options or an absent/ambiguous Status field abort before writes. For a renamed field, set `GH_STATUS_FIELD` to its new name.

## Public-content controls

Defaults are deliberately narrow:

- `PUBLICATION_MODE=label`: only tickets carrying `LINEAR_PUBLIC_LABEL=public` qualify. Applying this label approves the ticket's title, identifier and original Linear URL for permanent public exposure.
- `DESCRIPTION_MODE=title-only`: no source description is returned by the API or copied into the card.
- `PUBLISH_ARCHIVED_ISSUES=false`: archived Linear records are read for safe reconciliation but excluded from publication.

No comments or attachment records are queried. Team names, assignees, private labels, agent activity and internal metadata are not copied. The required Linear UUID is stored only in the synchronization marker. Logs show action identifiers and public target statuses, never source titles, descriptions, keys or raw provider errors.

To publish an explicitly reviewed description, choose `DESCRIPTION_MODE=approved` and add exactly one block to that issue's description:

```markdown
<!-- linear-github-public:start -->
This paragraph has been reviewed for the public roadmap.
<!-- linear-github-public:end -->
```

The rest of the description stays private. Missing/ambiguous blocks produce a title-only card.

`DESCRIPTION_MODE=full` explicitly opts into publishing all description prose. Embedded media/uploads, fenced code/log blocks and recognized `Agent notes` sections are still stripped. Common credential patterns block a card entirely. These filters are safeguards, not a guarantee that arbitrary text is public-safe: review every title and opted-in description. Removing public content later cannot undo its exposure.

`PUBLICATION_MODE=all` opts the entire configured scope into publication. It does not enable descriptions. Change it only after reviewing all affected titles. The synchronizer never applies labels or edits Linear issues.

## Removed and filtered issues

`REMOVAL_POLICY` supports:

| Value | Behavior |
| --- | --- |
| `leave` (default) | Preserve the existing card and log that it is no longer eligible/visible |
| `remove` | Remove the managed Project item |
| `archive-status` | Move it to `ARCHIVE_STATUS`, default `Cancelled`; this does not hide the card |

A present issue with a revoked public label or excluded archival state is distinguished from a UUID absent from the fetched scope. For absent UUIDs, removal modes make a second, unscoped, paginated presence query. Existing moved issues are classified separately; concurrent changes are preserved. Any failed presence query aborts the plan.

An empty, error-free presence result means absent **within the token's visibility**. The API cannot prove that access was not silently revoked. Keep access stable and verify permissions before enabling removal. The default `leave` policy is safest for this uncertainty, but it also leaves formerly public text visible after label removal. Choose `remove` explicitly when automatic withdrawal is wanted.

`MAX_REMOVALS=10` caps retirement actions per run. Empty-source retirement is blocked unless `ALLOW_EMPTY_SOURCE_REMOVALS=true` is explicitly set. Review a dry run before raising either safeguard. Duplicate managed cards are reported as failures and require manual reconciliation; the utility neither creates another copy nor automatically deletes duplicates.

## First import and activation

1. Commit/push the utility and workflow to the repository's default branch. No publication runs from pull requests or ordinary pushes.
2. Configure secrets, source UUID(s), board variables and status mapping. Leave `LINEAR_SYNC_ENABLED` unset.
3. Review and label public tickets in Linear. Tickets are imported regardless of age.
4. In **Actions → Mirror public Linear roadmap → Run workflow**, leave **dry_run checked**. This fetches live data but its GitHub client rejects every mutation.
5. Review proposed `WOULD CREATE/UPDATE/REMOVE` actions, statuses and summary counts. A zero-card plan may simply mean no issue has the public label.
6. **After explicit approval to publish**, set repository variable `LINEAR_SYNC_ENABLED=true`. Run manually with **dry_run unchecked** for the initial import.
7. Leave the variable enabled for scheduled reconciliation every five minutes.

The workflow has a single concurrency group, does not cancel an in-flight sync, and has a 15-minute timeout. Scheduled runs use the default branch and can be delayed/dropped by GitHub; this is polling, not a real-time delivery guarantee. Inactive public repositories may have schedules disabled. See [GitHub schedule behavior](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).

## Local use and tests

Copy `.env.example` to `.env` in this directory, fill in credentials and at least one source UUID, and keep that file untracked. From the repository root:

```powershell
node --env-file=scripts/linear-project-sync/.env scripts/linear-project-sync/cli.mjs --dry-run --verbose
# Only after reviewing the dry run and approving publication:
node --env-file=scripts/linear-project-sync/.env scripts/linear-project-sync/cli.mjs --apply

# No credentials, network, game or npm install needed:
node --test scripts/linear-project-sync/sync.test.mjs scripts/linear-project-sync/api.test.mjs
```

Both `--dry-run` and `--apply` require an explicit choice. `--verbose` adds counts and planning information without dumping content.

Advanced environment options are in `.env.example`: page size (default 50, max 100), page limit, query retries (4) and request timeout (30 seconds). `REQUIRE_PUBLIC_PROJECT=true` validates the destination; set false only when deliberately testing against a private board. This setting never changes visibility.

## Reliability and troubleshooting

- **401/403 or unavailable Project:** check token expiry, `project` scope, owner type, project number and access. A classic PAT is required for user-owned Projects.
- **Missing Linear scope:** use UUIDs and grant the key access to every relevant team. A project-only scope discovers all accessible project teams.
- **Unknown status:** correct the mapping/field/options. The default does not guess a column.
- **Rate limits/network failures:** queries retry with backoff and Retry-After/reset headers. A wait over 60 seconds or exhausted retries fails the run for later reconciliation.
- **Partial/invalid pagination or GraphQL errors:** abort before writes. Partial HTTP-200 GraphQL data is not accepted.
- **Ambiguous draft creation:** creates are never blindly retried. Re-enumerate by marker after a lost response; if still unconfirmed, stop. The next run reconciles existing cards. GitHub's clientMutationId is not treated as an idempotency key.
- **Interrupted run:** rerun. A created card with a missing status is completed rather than duplicated. All writes stop after a failure; cleanup is suppressed.
- **Duplicate markers:** retain one correct managed draft manually and remove the others after review; the next run resumes.

Only one writer may target a namespace/project. Actions concurrency serializes this workflow, but cannot lock out a simultaneous local script or another repository's workflow. GitHub draft creation has no uniqueness constraint; strict exactly-once creation under competing external writers is not guaranteed.

Summary logs report created, updated, unchanged, skipped, failed, removed, archival-status moves and duplicate counts. In dry-run mode these are proposed counts. Filtered source issues and retained retired cards both contribute to skipped. Any blocked content, duplicate conflict or write failure produces a nonzero exit.

To disable safely, set `LINEAR_SYNC_ENABLED=false` or disable the workflow in Actions. Existing cards remain. Manual dry runs still work with the variable false. For an in-flight run, cancel it in Actions if necessary; disabling the schedule does not roll back already published cards. Revoke unused credentials when retiring the integration.

## API references

- [Linear GraphQL and its published schema](https://linear.app/developers/graphql), [pagination](https://linear.app/developers/pagination), [filtering](https://linear.app/developers/filtering), [rate limits](https://linear.app/developers/rate-limiting).
- [GitHub Projects API guide](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects) and [Projects GraphQL reference](https://docs.github.com/en/graphql/reference/projects).

Draft content uses `addProjectV2DraftIssue` and `updateProjectV2DraftIssue`; status uses `updateProjectV2ItemFieldValue`; removal uses `deleteProjectV2Item`. Restoring a managed archived card uses `unarchiveProjectV2Item`. Draft content IDs and Project item IDs are separate and are used for their respective mutations.
