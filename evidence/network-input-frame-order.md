# Input pose sampling before movement

Read-only target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`,
at `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`.

The ordinary client path in `1406db800` calls input coordinator `1406f14e0`
at `1406db9f3`, then handles received network frames, then calls AI-list update
`140767d50` at `1406dc249` when the world/model is attached. The input coordinator
calls held-input tick `1406f1e40` at `1406f1ae7`. The AI list dispatches virtual
slot e8 at `140767ebb`. The creature vtable at `140e474e8` has that slot at
`140e475d0`, pointing to `1407fbd10`; its call at `1407fc0f9` reaches selector
`1407fcd70`, which can call path stepping `1408114d0` at `1407fcda9`.

This chain is Ghidra control-flow/pseudocode plus independently mapped original
call instructions and the actual eight-byte vtable entry. It is not a whole
native main-loop execution. Initial candidate `1406e6220` proved to handle
camera work rather than the AI list. The app dossier exceeded REA's response
budget; the completed retained analysis was projected to a 43,927-unit
pseudocode view with exhausted:true. The transport warning did not truncate
that retained function or require modifying/reimporting the original binary.

`inspect-native-frame-input-origin.py` independently executes unchanged
`1406f1e40` instructions for sixteen distinct rendered/predicted-position cases
and four direction masks. The sender boundary receives the rendered38 XY,
not predicted2c0 XY. Timer, object lookup, preview/send and transcendental calls
are captured boundaries. The coordinator phase order is separate static
evidence, rather than something this input-field oracle executes.

The replacement previously advanced presentation movement before sampling held
input. A periodic drive request therefore reported an already-advanced rendered
position. The new `network_frame.js` samples keyboard input before advancing
that frame's presentation, matching the native phase relationship. Tests use
the actual keyboard adapter and actual motion implementation with distinct
positions, compare outgoing pose against all sixteen native observations, and
prove the previous reverse order fails the same gate. Canonical object data
remain unchanged. The codec, geometry, movement rates, timers and server
authority are unchanged by this repair.

This fixes packet pose sampling. Async collision preview completion retains its
owner and fresh-pose validation and is not made atomic with the whole frame.
Inbound network application is also still a separate owner. The new local
trace contains17 fresh-pose retries versus0 before; that overhead is recorded,
not omitted from the diagnosis. Do not infer full native scheduling parity.

Validation:

- 32 focused checks pass, including frame/native-origin, input lifecycle,
  original timing/sequence, installed original-client movement/camera capture
  and path acceptance. The first run's only failure was sandbox denial of an
  installed-data read; the scoped read-only rerun passes all32.
- Build and actual packaged startup/resource IPC pass with
  `index-CH11PlBE.js`. The running prior client was then disconnected normally;
  only the replacement was rejoined to127.0.0.1:5121. Server configuration and
  original client/server binaries remain untouched.
- The calibrated six-input and deliberate-contact checks finish, followed by a
  bounded ten-second sampler. Nineteen starting-room samples give131.3–139.1FPS
  and7.9–10.3ms sampled p95 frames, with no renderer errors or failed objects.
  This is not the earlier100-tile academy or exclusive OS fullscreen.
- All221 applied current predictions replay against original6ea9e0/7fdeb0
  with2048 captured collision queries and maximum coordinate/endpoint delta
  2.38e-7. Paths, factors, animation IDs and resend results agree within the
  unchanged oracle's bounds. No null paths or corrected inputs occur in this
  trace; the earlier trace had36 corrected inputs. Conditions and driver/NPC
  timing are uncontrolled, so this is not a causal improvement ratio.
- W/S retain zero stationary steps. Combined A/D and Q retain short stops;
  maximum pauses are36.1/34.2/24.7ms. Contact Q/E maxima are16.1/17.4ms. Actual
  active-path idle frames remain zero. Many stops follow progressively shorter
  collision-limited endpoints, so continuing the walk clip would not establish
  correct collision behavior. Complete motion acceptance remains open.

Current reports and source hashes are checked by `verify-frame-order.mjs`.
The frozen capture is `creation-performance-exact-drive-capture-v5.json` and
the original-code replay is `native-exact-drive-preview-v9.json`. No proprietary
resource payloads are copied. All scripted input/sampling finish; the updated
client is left idle and connected on the owned local server.

The goal remains active. The next useful checks are actual fullscreen and
renderer entry CPU/preparation profiling, plus native whole-frame/short-path
timing if changing residual stops. The prior academy transition proof belongs
to the previous build and is retained with that qualification. Asset caching
must continue to follow resolver/session ownership; no global server table
cache was introduced here.
