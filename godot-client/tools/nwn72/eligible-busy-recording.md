# NWN-72 busy-area unchanged-input census

`eligible-busy-recording.cjs` read the pinned generation-2 Arelith capture at `C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf` without launching a client or measuring FPS. It verified `recording.json` SHA-256 `1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463`, `timeline.jsonl` SHA-256 `6ce44bfe52a7bd8c3b08e936206360847cd3bb1ec1713bd1d21c7304882d3920`, 5,704 events, generation 2 and busy area `2147618622`. Current source SHA-256: `systems/network_motion.gd` `bc6d3c8d26cd041a5f9977ac8f3357cd72b3102b7e2b9afa7060c0bd18176499`; `systems/native_render/live_world.gd` `ec5c12122567a3824650dedbc0b212b3a0e2651d20825493ece161ea6bd4f422`.

Run from `godot-client` with a fresh report path:

```powershell
node tools/nwn72/eligible-busy-recording.cjs --report='C:\Users\Niflheim\Desktop\Tools\Local Tools\EntireDecomp\godot-client\.cache\nwn72\eligible-busy-recording-c.json'
```

The capture has 2,971 `movement-sample` rows, one per distinct native frame, **for the controlled creature only**. The first row lacks a predecessor. Of the 2,970 comparable rows, 2,210 (74.4%) repeat render position, orientation and animation; 2,212 repeat the tracked motion fields; 2,714 repeat facing orientation and target; and 2,205 repeat all tracked state fields. A conservative 2,162 rows (72.8%) repeat tracked state and keyboard state while inactive, uncorrected, not holding drive input and already facing the target. Across all 2,971 rows, 777 have active motion or a moving keyboard, 54 have correction, 272 have an unsettled facing target, and 728 hold drive input; these categories overlap. Equality uses exact numeric identity, including signed zero.

The same area contains 201 `frame/movement` messages with 277 records for 21 distinct IDs; 29 records are creations. Every record has at least one `changes` field and no complete patch exactly repeats the previous patch for the same ID. Individual fields often repeat their previous wire value, for example `facingTarget` in 179 of 218 fields and `animation` in 148 of 257, but the prior wire value is not the locally simulated current state. This packet census cannot label those records safe to discard.

**Guard decision:** There is a sizeable input-stable population for the *sampled controlled creature*. This recording does not provide per-frame states for the other creatures, so it cannot establish the fraction of all `World.apply_pose` calls eligible in the busy area. More importantly, current `World.apply_pose` still calls gait, combat base-frame/cue and cast/special/equipped effect observers after its conditional transform setter. Their clocks and lifecycle can advance with unchanged sampled motion. Therefore the 2,162 rows are candidates only for a narrowly invalidated transform/input fast path, not a proven safe whole-`apply_pose` skip. The existing transform setter already avoids writing an unchanged transform. A production guard needs per-creature frame input and dependent-owner wake/lifetime evidence before promotion.

Receipt: `.cache/nwn72/eligible-busy-recording-c.json`. No production source changed.

Independent root rerun: `.cache/nwn72/eligible-busy-recording-root.json`, exit 0, same source hashes, 2,971/2,970 sample/comparable rows, 2,210 unchanged pose inputs and 2,162 conservatively idle/tracked-unchanged rows; the 201 packet events and 277 records also matched. A speculative yaw cache was not accepted and the current `network_motion.gd` source hash was restored to the value above.
