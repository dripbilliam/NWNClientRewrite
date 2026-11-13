# NWN-75 original Nuklear kind-18 callback

Scope: installed `nwmain.exe`, SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. Addresses are original image VAs. This is a static producer-to-consumer map of numeric command 18. It does not prove that this command is emitted or that its callback executes in a gameplay frame.

## Producer and command fields

`FUN_140a89050` `0x140a89050` is the observed direct caller of central command allocator `0x140a619c0` that requests kind `0x12` (18), size `0x28`, at `0x140a890e7`. The x64 inputs are RCX context, RDX float rectangle, R8 callback pointer and R9 opaque user value. The producer returns for null context. When context `+0x18` enables clipping, it rejects zero clip width/height and nonoverlapping rectangles. If allocation returns null, it writes no command. Otherwise it stores the R9 user value at command `+0x18` (`0x140a890f8`) and the R8 callback pointer at `+0x20` (`0x140a890fc`). It converts rectangle x/y to signed 16-bit fields at `+0x10`/`+0x12`, clamps width/height to nonnegative floats, then converts them to 16-bit fields at `+0x14`/`+0x16`. It does not validate the callback pointer before storing it. REA producer `ev_4f3634fc47640659b0d9bc418ce46420bb7f83ed47a249f65542f4cbe8c48e0d`, assembly and allocator edge `ev_f191c354a97fe9feb877731d369aedaa7bf8d1a0f809bcb0e2ab8c258839c4f6`.

| Command offset | Source | Converter use |
| --- | --- | --- |
| `+0x00` | Allocator writes kind 18. | Numeric switch selects case `0x12`. |
| `+0x08` | Allocator's linked next offset. | Converter advances the command chain after the callback. |
| `+0x10`–`+0x16` | Rectangle x, y, width, height as four 16-bit fields. | Passed as callback arguments 2–5. |
| `+0x18` | Producer's R9 user value. | Passed as callback argument 6. |
| `+0x20` | Producer's R8 callback pointer. | Indirectly called at `0x140a7d163`. |

## Converter dispatch and descendant boundary

`FUN_140a7c340` case `0x12` reaches `0x140a7d140`. It loads command `+0x18` to the stack as argument 6, loads four 16-bit rectangle fields as arguments 2–5, passes the conversion context in RCX, and executes `CALL qword ptr [RDI + 0x20]` at `0x140a7d163`. The callsite has no null or target-family check. The converter then follows the ordinary linked-command bounds/next-offset path. REA converter `ev_ec58a71c7490d2775255b5ecb90580cb3ed6537531109c758291b65934bf3467`, exact instruction `ev_45a726b8fe183a92d0a78726c57c87fbcfd31f3e2b1f49e4f267bedd66069fd7`. The outer draw `0x140a71760` consumes converted output and can issue texture/scissor and indexed GL draws for nonempty draw commands, as mapped in `gui-presentation.md`; the kind-18 callback's own CPU or GL leaves are unknown until its target is identified.

## Target and reachability census

The analyzed producer has **no incoming executable call or function-pointer data reference** in the current original image. Its REA incoming set contains internal conditional jumps and `.rdata`/`.pdata` function-range metadata references; these are not callback registrations (`ev_97ae78aa22ca72290476c810b39cd930b80239404e158b4f43f47818b40662f2`). The complete initialized-image search for its 8-byte VA `0x140a89050` returned zero matches (`ev_8cfc0c4c6ffc3ce10b771d8e3ee7ee02f52910d2096b3a64b6396bd1e73d5425`). A search for its exact 32-bit RVA found only two `.rdata` metadata positions and one `.pdata` range entry (`ev_4ee488d41a048d8e66c9d2793094ac4d0c906cd018c76d0eb82915e64525d917`). The existing allocator-caller census lists this as the sole **direct allocator caller** that emits kind 18; it does not exclude an inline writer through a lower buffer helper.

Consequently the original static evidence proves the callback field comes from the caller-supplied R8 when this producer runs, but identifies **no concrete callback target family** and no path from an active UI entry to this producer. Computed address formation, an inline command writer, or code outside the analyzed original image could bypass the direct-reference census. Without such a producer-to-callback-value edge, following CPU/GL descendants past `0x140a7d163` or claiming runtime execution would be speculation. The unresolved edge is precisely: an active command producer must write kind 18, establish a nonzero `+0x20` target, and reach the converter's case 18; none is proven here.
