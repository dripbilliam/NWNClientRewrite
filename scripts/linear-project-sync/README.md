# Linear → GitHub Issues and Projects sync

Mirrors the NWNAnalog Linear project into [NWNClientRewrite Issues](https://github.com/dripbilliam/NWNClientRewrite/issues) and [project board 3](https://github.com/users/dripbilliam/projects/3). The Action runs every five minutes (`2-59/5 * * * *`). Linear remains authoritative and is never modified. Runtime code is isolated here, has no npm dependencies, and requires Node.js 22 or later.

The owner-approved deployment publishes all scoped tickets, including archived tickets, with full description prose: `PUBLICATION_MODE=all`, `DESCRIPTION_MODE=full`, `PUBLISH_ARCHIVED_ISSUES=true`. Comments, attachments, embedded media, execution logs and recognized agent-note sections remain excluded. Credentials block publication. Treat mirrored titles and descriptions as public.

## Import and ongoing updates

`SYNC_TARGET=issues` enables repository issues. The initial live run imports eligible tickets and replaces their managed draft cards with linked repository issues. Subsequent runs:

1. Read all Linear tickets/states, all Project items (including archived), and all repository Issues (open and closed), with validated pagination.
2. Match by the Linear UUID comment in the body; titles are never identity keys.
3. Update changed titles and descriptions, and show the exact Linear workflow status in the issue body.
4. Close completed tickets as **Completed**, canceled/duplicate tickets as **Not planned**, and reopen tickets whose Linear state becomes active.
5. Add missing issue links to the board, restore eligible archived items, and apply the mapped Linear column.
6. Remove an old managed draft only after the replacement issue, issue state, board link and board status have succeeded.

Unchanged tickets receive no writes. New Linear tickets are imported automatically. Existing issue numbers, comments, manually applied labels, assignees and milestones are preserved. This sync owns the title, body and open/closed state of UUID-marked issues; manual body edits are replaced by Linear on the next run. Unmanaged issues, PRs and unrelated drafts stay untouched.

An interrupted import resumes from the UUID. Lost create/link responses are reconciled by re-enumeration, never blindly repeated. Write failures stop the run and preserve any not-yet-replaced drafts. Duplicate/malformed markers require operator review; conflicting tickets are not duplicated or automatically deleted.

The marker stays stable across a draft and its replacement issue:

```html
<!-- linear-project-sync:v1 nwnanalog-public-roadmap 00000000-0000-4000-8000-000000000001 -->
```

Keep `SYNC_NAMESPACE` stable. Removing a marker makes an issue unmanaged. Do not switch this deployment back to draft mode after migration.

## Credentials and permissions

Credentials are supplied only to the sync step:

| Credential | Purpose |
| --- | --- |
| `LINEAR_API_KEY` repository secret | Read the selected Linear scope |
| `GH_PROJECT_TOKEN` repository secret | Manage the user-owned Project; existing `GM_PROJECT_TOKEN` is a compatibility alias |
| Automatic Actions `GITHUB_TOKEN`, exposed as `GH_ISSUE_TOKEN` | Create/update repository issues; the sync job grants `issues: write` and `contents: read` |

No new repository secret is needed for issue mirroring in Actions. The Project token needs `project` access and read access to the linked public issues; repository writes use the separate short-lived Actions token. The test job is read-only and receives no sync secrets. Push and pull-request runs only test.

For local issue mode, set `GH_ISSUE_TOKEN` to a token with Issues read/write access to the selected repository. Store credentials in ignored `.env`, never in source, issue bodies, variables or logs. Provider payloads and credentials are redacted from errors.

References: [GitHub Project authentication](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects#authentication), [Actions token permissions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication), [Linear authentication](https://linear.app/developers/graphql).

## Configuration

The workflow sets `SYNC_TARGET=issues` and `GH_ISSUE_REPOSITORY=${{ github.repository }}`. The library's legacy default `SYNC_TARGET=drafts` remains for separate draft-only deployments and does not request a repository token.

Repository Actions variables:

| Variable | Current deployment / default |
| --- | --- |
| `LINEAR_PROJECT_ID` | NWNAnalog project UUID |
| `LINEAR_TEAM_ID` | Optional team UUID; team + project means their intersection |
| `GH_PROJECT_OWNER` | `dripbilliam` |
| `GH_PROJECT_OWNER_TYPE` | `user`; `organization` also supported |
| `GH_PROJECT_NUMBER` | `3` |
| `LINEAR_SYNC_ENABLED` | `true` enables scheduled/live publication |
| `SYNC_NAMESPACE` | `nwnanalog-public-roadmap` |
| `PUBLICATION_MODE` | Current `all`; library default `label` |
| `LINEAR_PUBLIC_LABEL` | `public`, used in label-only mode |
| `DESCRIPTION_MODE` | Current `full`; library default `title-only` |
| `PUBLISH_ARCHIVED_ISSUES` | Current `true`; library default `false` |
| `STATUS_MAPPING_JSON` | `{"Canceled":"Canceled","Duplicate":"Canceled"}` |
| `GH_STATUS_FIELD` | `Status` |
| `UNKNOWN_STATUS_POLICY` | `skip`; `fallback` or `error` also supported |
| `STATUS_FALLBACK` | `Backlog`, used only by fallback policy |
| `REMOVAL_POLICY` | `leave` |
| `ARCHIVE_STATUS` | Current `Canceled` |
| `MAX_REMOVALS` | `10` |
| `ALLOW_EMPTY_SOURCE_REMOVALS` | `false` |
| `REQUIRE_PUBLIC_PROJECT` | `true` |

Use Linear UUIDs, not names or ticket identifiers. There is no creation-date cutoff. All labels/pages are read before planning; archived tickets are fetched even when excluded from publication.

Board 3 has Backlog, Todo, In progress, Testing, In review, Done and Canceled. States are discovered from Linear at runtime. Mapping keys may be workflow UUIDs or names; UUID mappings take precedence, then names match case-insensitively. `In Review` maps directly to `In review`. Keep the cancellation spelling `Canceled`. Missing/ambiguous fields/options abort before writes; unknown statuses skip by default.

Create/configure Projects, visibility, Status options and access manually. The utility never changes visibility or creates fields. Disable competing board automations that overwrite managed status values.

## Publication controls

The library defaults to publishing only `public`-labelled ticket titles. Description modes:

- `title-only`: descriptions are not fetched/published.
- `approved`: publish exactly one explicitly selected description block.
- `full`: publish description prose after filtering media/uploads, code/log fences and agent-note sections.

Approved blocks use these exact delimiters:

```markdown
<!-- linear-github-public:start -->
Reviewed public description.
<!-- linear-github-public:end -->
```

Missing/ambiguous approved blocks yield title-only descriptions. API tokens, private-key headers, CD-key formats, credential assignments, authenticated URLs and signed credential parameters block publication. Pattern checks cannot prove arbitrary text is public-safe. Removing text cannot undo prior public exposure or notifications.

## Missing or filtered tickets

`REMOVAL_POLICY=leave` preserves mirrored issues/cards when a ticket disappears, moves out of scope, loses its public label, or becomes ineligible. It does not automatically withdraw previously public text.

`remove` removes only the managed Project item; repository issues and discussions are never deleted. `archive-status` moves the board item to `ARCHIVE_STATUS` without hiding it. These modes confirm absent UUIDs with a second unscoped Linear lookup, enforce `MAX_REMOVALS`, and block empty-source cleanup unless explicitly enabled. Absence can only be established within the token's visibility. Query/permission failures never count as deletions; any publication/write failure suppresses retirement cleanup.

## Run and validate

The current deployment is owner-authorized for live publication. Import or reconcile immediately with:

```powershell
gh workflow run linear-project-sync.yml -f dry_run=false
```

Manual dispatch defaults to live mode. `dry_run=true` remains an optional preview; it is not required before an authorized live import. Automatic runs use the same issue/board sync every five minutes. A single concurrency group serializes runs, does not cancel an in-flight import, and has a 15-minute sync timeout. Mutations are spaced by at least one second per API client. GitHub can delay/drop scheduled invocations; the cron frequency is not a delivery guarantee.

For local use, copy `.env.example` to ignored `.env`, configure source UUID(s) and credentials, then run:

```powershell
node --env-file=scripts/linear-project-sync/.env scripts/linear-project-sync/cli.mjs --apply
node --test scripts/linear-project-sync/sync.test.mjs scripts/linear-project-sync/api.test.mjs scripts/linear-project-sync/issues.test.mjs
```

Exactly one of `--apply` or `--dry-run` is required. Unit tests use mocked providers; no credentials, network, game installation or npm install is needed. Tests cover import, draft replacement, unchanged reruns, close/reopen states, partial writes, lost responses, duplicate markers, privacy filters and pagination.

Advanced options in `.env.example`: page size 50 (max 100), page cap 1000, query retries 4, request timeout 30 seconds. Provider/rate-limit failures stop safely for the next run. Creates are never blindly retried; clientMutationId is not a uniqueness guarantee. Keep one writer per namespace/project: Actions concurrency cannot serialize unrelated external/local writers.

Summary output counts created/updated/unchanged issues, linked board items, migrated drafts, skips, failures and retirement actions. Titles/descriptions are never logged. Set `LINEAR_SYNC_ENABLED=false` or disable the workflow to stop scheduled publication; existing issues/cards remain.

API references: [Linear GraphQL](https://linear.app/developers/graphql), [pagination](https://linear.app/developers/pagination), [GitHub Issues](https://docs.github.com/en/graphql/reference/issues), [GitHub Projects](https://docs.github.com/en/graphql/reference/projects). Issue mode uses createIssue, updateIssue, closeIssue, reopenIssue and addProjectV2ItemById. Legacy draft mode uses addProjectV2DraftIssue/updateProjectV2DraftIssue. Both use updateProjectV2ItemFieldValue, unarchiveProjectV2Item and deleteProjectV2Item for board management.
