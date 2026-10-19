# REA project integration — 2026-10-16

User authorized integration and resuming the spellcasting/combat/campaign goal.
`rea_nwn` is now registered in generated project-scoped `.codex/config.toml`.
The global Codex configuration and the original game/project hashes are unchanged.
`codex mcp get rea_nwn --json` reads back the installed registration.

The configuration uses the documented project MCP table, native tool allow-list,
30-second server initialization timeout and1,200-second tool timeout. Initialization
is target-free; Ghidra starts on the first native query. See the
[official MCP configuration documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).
This registration requires a client reload before tools appear in an already
running agent's own catalog. No app restart was forced during project work.

`scripts/rea-mcp.mjs` launches the exact `rea-agents@6.5.0` package under
`tooling/rea`, with the verified Windows addon hash. The isolated dependency
manifest pins6.5.0 exactly; its lock uses the public registry tarball/integrity,
so restoration does not depend on the trial archive. Package lifecycle scripts
were disabled. No main client dependencies or external tools were installed.
`npm ci --prefix tooling/rea --ignore-scripts --omit=dev` restores this toolchain.

The launcher uses installed Ghidra12.1.4/JDK21 and a temporary child profile.
Ghidra imports/target snapshots remain in OS temporary directories, outside the
repository. It never opens the saved original Ghidra project. The native policy
admits23 inspection/session tools, with no runtime execution, injection, patching,
browser, or annotation tools. Windows provider P0 retains its own restrictions.
Machine-local config is Git-ignored; `scripts/integrate-rea.mjs` recreates it,
preserving unrelated project config and backing up an existing file if needed.

The current agent uses `scripts/rea-session.mjs`, a persistent stdio MCP client
using the same launcher and policy. Tool results are saved as full REA Evidence
under `backups/animations/rea-*.json`; stdout reports only saved paths/status.
Use its actual advertised input schemas. It does not simulate REA tool calls.

The first attempted native query exposed a bridge mistake: SDK2 expects call
options in argument2, whereas the old argument3 spelling allowed the60-second
default timeout. That attempt was cancelled/closed, the client corrected and
restarted. The successful persistent cold search took436,058.82ms. The next
three native function queries took76.28,28.90 and54.02ms in the same program.
This is measured reuse, not a startup/readiness-only claim.

`scripts/verify-rea-integration.mjs` / `rea-integration-verification.json`: PASS.
The LocationAccess, VectorNormalize and PrintString dossiers match independent
instruction addresses/mnemonics and complete function boundaries:68/49/61
instructions,273/206/268bytes. Native execution tests separately validate the
implemented semantics; pseudocode types and bit casts remain analyst work.

Projectile receiver7ac670 exceeded the10MiB MCP response budget. The completed
analysis was retained rather than truncated. The policy now includes the read-only
`inspect_analysis_view` pager: the retained pseudocode view has48103 UTF16 code
units and the assembly view has1929 instructions, both fully paged with exhausted
coverage and no continuation offset. Paging offsets for pseudocode count code
units, not lines. The verifier checks shared parent evidence, original artifact
SHA256, full coverage and first/last instruction boundaries. Fresh Codex readback
`rea-integration-codex-get-v2.json` confirms all23 enabled tools. The original
22-tool readback remains historical evidence. This adds access to retained
analysis; it does not establish that the native receiver is implemented.

The failed old client was stopped after closing its target. The successful
persistent client is intentionally retained for continuing research. Close its
target with `close_binary`, then send `{"close":true}` when finished; verify
cleanup rather than deleting an active private Ghidra directory or changing ACLs.
No implication that REA alone completes spellcasting or gameplay parity.

The user explicitly revoked the earlier pause by requesting continuation. Work
has resumed and the goal API currently reports active.
