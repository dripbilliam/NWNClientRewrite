# Original scrollbar input — scoped follow-up

The later [content-sized thumb milestone](NATIVE-SCROLL-THUMB.md) replaces the
fixed thumb size and adds original linked-row scrolling. Receipts below refer
to this earlier input checkpoint's historical source.

The original-framed Examine and merchant confirmation scrollbars now use
mouse-down arrow actions, held arrow/page repetition, original-font line steps,
consistent wheel handling over text and rail, and thumb-drag cancellation.
This extends [NATIVE-SCROLLBAR.md](NATIVE-SCROLLBAR.md); full scrollbar parity
and the entire UI goal remain incomplete.

## Original rules

Static evidence in `../backups/animations/rea-native-scroll-repeat-v1.json`:

- `CGuiTimerButton` constructor `1401e4a20`, mouse-down `1401e4f70`, timer
  `1401e4d30`: act on press, wait500000 microseconds, then repeat with a
  50000-microsecond period. The comparison is strict `>`. A tick emits at most
  one callback and clears excess elapsed time. It does not replay missed ticks.
  An inactive pressed visual suppresses delivery while elapsed time accumulates.
- Scrollbar constructor `1401e5e60` uses timer buttons for both arrows. Their
  normal step is one logical line; ordinary wheel handler `1401fb0e0` uses
  three. Native pixel-scrolling routines are a separate original mode.
- Slider mouse-down `1401e6830` primes its clock. The first GUI timer tick
  pages; it then waits333333 microseconds and repeats at100000 microseconds.
  Slider timer `1401e62c0` advances timer phase even if no page is applied.
  Repetition stops applying pages on the thumb and cannot reverse the chosen
  page direction while held.
- Slider mouse-up `1401e6ae0` releases capture. Mouse-focus loss `1401e6b10`
  restores a thumb drag's starting value. The native control now does this on
  focus-out and menu hiding; ordinary release keeps the committed value.

`native_data/gui_repeat.gd` owns the data-only timer. `native_scrollbar.gd`
owns native input/capture, visible-mode ownership and weak resource lifetime.
Font loading updates the line step from original metrics: Galahad14 supplies17
GUI pixels per line,51 per ordinary wheel notch. This also holds at125-percent
root scale without changing the local scroll units. Idle widgets stop processing;
release, hiding, focus loss and close retire held state and signal subscriptions.

Godot's default [ScrollContainer wheel handler](https://raw.githubusercontent.com/godotengine/godot/master/scene/gui/scroll_container.cpp)
uses a viewport-relative amount. Setting a scrollbar custom step did not change
that handler in our test. The visible original bar now accepts wheel input from
the content's `gui_input` signal before that default runs. The [official Control
dispatch order](https://raw.githubusercontent.com/godotengine/godot/master/scene/gui/control.cpp)
supports this interception. Hidden basic/item bars sharing a container do not
both process the event. Unrelated keys, clicks and camera input are unchanged.

## Verification

Final source-pinned native debugger receipts:

| Prefix `native-scroll-repeat-` | Checks |
| --- | ---: |
| `clock-final-v1` |12 |
| `examine-final-v1` |61 |
| `store-final-v1` |32 |
| `retirement-final-v1` |13 |
| `playability-final-v1` |1314 |

The graphical tests inject native input into an isolated SubViewport: press
before release; a real held frame loop; release stopping callbacks; pointer
exit/re-entry; rail repeat/direction lock/thumb pause; drag commit; injected
focus-out rollback; menu-hide rollback; content/rail wheel agreement;125-percent
geometry; no extra model renders or gameplay requests. Exact clock boundaries
and long-frame single-delivery behavior are separately deterministic.

`native-scroll-repeat-actions-final-v1` is the isolated original localhost5125
action regression. No public/Arelith connections or original-client interruption.
It passed99 checks with unchanged source, native exit0 and zero remaining
workers. All final debugger receipts are clean. The scaled native frame capture
was visually reviewed; these scoped checks do not prove original-client parity.

Early failures remain retained: a test variable type declaration, the initial
viewport-relative content wheel mismatch, and a focus-notification constant in
the wrong test scope. The first simplified immediate rail-page implementation
was replaced with the original primed timer/phase rules before acceptance.

Still open: live original-client input/visual comparison, exact text-line range
and page-extent mapping at partial lines, all disabled/hover/art states,
fractional wheel/pixel-scrolling modes, arbitrary server layouts/fonts, GUI
sounds and the full target/scale audit. Synthetic focus-out tests do not prove
all OS mouse-capture paths. Keep `full_scrollbar_parity` false. The earlier
intermittent blood screenshot failure remains open despite later passing runs.

Rollback: `backups/native-scroll-input-v1.zip`; audit:
`node godot-client/tools/audit-native-scroll-input.mjs`.
