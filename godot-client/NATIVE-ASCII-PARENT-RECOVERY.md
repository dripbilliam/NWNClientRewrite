# Mixed-case original ASCII model parents

Live session `native-session-1792919688354` deliberately exited with code 1
after the native actor loader reported `ASCII MDL parent missing` for
`ashto_041`. Native reporting and protocol finish acknowledgment completed and
zero workers remained. There is no evidence here of a native access violation.
The previous user session `native-session-1792918958340` has the same model error.
The later session had reached playable state at 8138.898 ms before encountering
this background model, with 200/642 entities present at shutdown.

Offline read-only catalog inspection reproduces the failure with the original
105039-byte model SHA256
`67cc71e41663b4925f1fc36451b55604d0f3e81ef64185cc6823b092d234a359`.
The physical root is named `AShTo_041`; `Box013`, `imp_shield_1.009` and
`imp_shield_2.009` instead name their parent `ashto_041`. Exact-case dictionary
lookup incorrectly rejected those edges.

The native ASCII loader now resolves a unique case-insensitive parent alias
when no exact name matches. It preserves authored names, transforms and physical
nodes, and keeps the established final-exact-declaration behavior for duplicate
names. It still rejects nonexistent parents, cycles and ambiguous case aliases.
This is a targeted compatibility repair. Original binary semantics for every
ambiguous duplicate-name case have not been established, and no broad ASCII
parser parity claim is made. No unparented replacement geometry is invented.
Previously failed parses were not written to the prepared cache; exact-name
successful parses are unchanged, so this does not require clearing the cache.

Evidence:

- `native-ascii-parent-v1`: pre-fix reproduction, failed model parse, exact bytes
  and all three unique case matches recorded. Retained as failed evidence.
- `native-ascii-parent-v2`: 11 checks, including missing/cyclic/ambiguous cases,
  duplicate names, unchanged names/transforms, all three original parent edges,
  and full native actor-model preparation of `ashto_041` (six nodes, one mesh).
  CDB normal heap, four exception traps, unchanged sources, no native exception
  or engine/lifetime error. No public connection.
- `native-ascii-parent-corpus-v1`: 548 existing original ASCII hierarchy,
  transform, geometry/UV and normal comparisons pass. Direct headless engine
  with clean log; this corpus run was not debugger-protected.
- `native-session-ascii-parent-v1`: default launcher against owned local Prelude;
  movement while background objects load remains functional. Native/server final
  distances are approximately 1.500033 m. All 20 entities/nine tiles finish,
  zero workers remain, protocol finish acknowledged, source pins unchanged,
  normal-heap CDB traps armed with no native fault.

Full affected public-area loading still requires a user-driven retry. The broad
native migration, dense moving-world frame pacing and historical native shutdown
fault diagnosis remain incomplete. General recovery from unrelated background
asset preparation failures is not implemented by this parser fix.
