# Native portrait chooser membership

Target: read-only NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`,
at `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`.

Previously the replacement creator offered every non-plot portrait row of the
selected sex, in table order, and appended loose portraits with any size suffix.
Unavailable image rows stayed selectable as text tiles. The27 known missing
source images were therefore presented as an unresolved pack dependency. That
before-state is source inspection, not a measured full native GUI comparison.

Read-only REA analysis identifies `CGuiPortraitSelect` construction at
`1409cfb10` through `CTL_CG_PORTRAITS`. A derived RIP-relative LEA scan locates
these controls; it is not a complete cross-reference census. A REA incoming
procedure-reference request on the data address was rejected and does not
support any behavioral finding. No symbol database or original binary was edited.

The chooser's add path at `1409d0cd0` calls the shared native size resolver
`14084c2f0` with size3 at callsite `1409d0d43`, checks the resolved image's TGA
existence at `1409d0d5c`, then DDS at `1409d0d79`, and skips the row if neither
exists. It also suppresses duplicate bases. The native neighboring-size order
was already verified separately by6144 original-instruction cases.

Population at `1409d1c80` collects the entire portrait table's bases, filters
non-plot rows by selected sex, and makes two passes: matching race first, then
other races. The decision executes at `1409d20f7..1409d2114`. It consults
`CHARGEN_ALLOW_CUSTOM_PORTRAITS`, default1, before appending custom images.
Custom discovery at `1409d04a0` enumerates TGA and DDS in installed/user portrait
directories and admits only filenames whose size suffix is M or m; the suffix
decision is `1409d06b4..1409d06f4`. A custom base already represented by any table
row is excluded, including rows of another sex or plot portraits. The complete
native workshop/directory ordering and GUI widget lifecycle are not claimed.

`scripts/inspect-native-portrait-chooser.py` executes unchanged mapped original
instructions in Unicorn. It covers2048 add/admission/dedup cases,32 race-pass
branches and all256 suffix-byte values. Strings, allocations and resource Exists
are captured boundaries; an already-full24-widget pool bypasses widget creation.
Race and suffix tests are bounded instruction slices, not whole population or
directory execution. No native game process, original image payload or GUI is
used by the oracle. The helper is compared with these observations in focused
Node tests, alongside rules toggles, table/custom exclusion and ownership races.

The replacement now applies these chooser rules. A bounded metadata-only
availability operation checks sizes through the active resolver's catalogs,
without reading image bytes. The production preload exposes a trusted,
session-owned IPC method. It captures the resolver and rejects completion after
closure or replacement. The existing image-only portrait-folder priority and
server rule isolation remain intact; no server name or portrait name is added
to production logic. A present but corrupt image still has catalog membership;
this change does not equate Exists with successful decoding.

Validation:

- 56 focused Node checks pass, including active A/B catalogs and stale completions.
- 21 browser lifecycle cases pass, including new late catalog success/failure
  after cancel/reopen.
- Actual cached creator passes all15 steps, portrait/skill scroll preservation,
  hidden unavailable feats/groups, voice playback/disposal, custom and half-orc
  appearance reads, and six recovered installed portrait image decodes.
- The cached catalog checks3172 candidate bases in about5.1ms, reading zero image
  resources during the check. All27 known absent rows are unavailable and absent
  from the chooser. Recommendation selects an available image.
- The packaged production preload, trusted IPC and actual session method pass
  synthetic A/B catalog, malformed input, canceled pending request and old ID
  checks, with no socket, credential, game join or fetch.
- Build and packaged main-menu/resource IPC pass with `index-oVQBAT2o.js`.
  Screenshot `creation-experience-portrait-chooser-v2.png` was visually checked:
  loaded images and race ordering are visible. The earlier v1 capture preceded
  compositor painting despite decoded images; the final capture waits two frames.

The cached creator test reads the already-downloaded collection offline; it
does not join Arelith or any other server. Browser debug-font requests in packaged
fixtures are canceled before sending. The existing live replacement client and
owned local servers were untouched. This build needs a full client restart to
apply its preload addition. It has not yet replaced the live movement build.

The27 missing image files remain missing. Their absence is handled with native
chooser behavior, rather than invented substitute assets. The authorized user
portrait copy and six installed image recoveries remain verified by earlier
evidence. The goal remains active for broader loading/movement/replication,
transition/fullscreen and effect-resource acceptance. The new chooser fix does
not establish the original reported106ms frame's cause.
