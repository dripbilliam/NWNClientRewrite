# Native weather state — presentation still pending

This document records the state-only checkpoint. The subsequent
[rain/snow rendering work](NATIVE-WEATHER-RENDER.md) now presents original
precipitation locally, but remains work in progress after an unresolved native
crash. Lightning/thunder, native pause/timer details and complete weather
coverage remain migration work. The last fully accepted
checkpoint remains `native-retirement-tested-v1.zip`; this stage is a separate
work-in-progress backup.

## Original-code evidence

Read-only original `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`:

- Server sender `1404cebd0` / client dispatcher `14076d910`, area message
  major4/minor4: byte type and BOOL enabled, affecting the current area. It
  contains no target area/object ID. The shared decoder now retains this
  message, and `NetworkWorld` applies it to the actual current area.
- Requests `1407e69a0` and `1407e69e0`: desired type or zero, restart6000ms.
  `140877020` is an audio controller, not the visual intensity fade.
- Area update `1407e7da0`, weather block `1407e8f21..1407e903a`: sample before
  subtracting the integer elapsed time, use the current physical WeatherTypes
  row's FadeTime (fallback6000), unsigned32 numerator and original float32
  arithmetic. Completion sets desired weather to100%, or clear to0%.
- Visual setter `1407e63c0`: clamp intensity to0..100, including NaN→0;
  destroy/recreate six model instances on zero/type changes. Play the original
  animation at intensity/100, externally sample its length, then freeze it.
  This is not a looping precipitation animation or six hand-authored emitters.
- Installed WeatherTypes physical rows1/2 identify `fx_rain`/`rain` and
  `fx_snow`/`snow`, FadeTime6000. Each original model has four emitters; original
  animation tracks control their rates. Assets remain in the existing install
  or external runtime bundles, never in this source archive.

Full retained static analyses are in `reports/native-weatherUpdate-v1.json`,
`native-weatherVisualState-v1.json`, `native-weatherStop-v1.json`,
`native-weatherSet-v1.json` and `native-weather-area-handler-v1.json`.
The independently executed oracle bounds/stubs are recorded in
`tools/native-weather-state-oracle.py`: original request/update/setter
instructions execute; C2DA values, six synthetic models and sound/driver calls
are explicit lower boundaries. This does not establish original asset pixels.

## Implemented ownership

`WeatherDelivery` resolves the session's physical rules rows asynchronously and
publishes small metadata/state envelopes only after native world admission.
Connection, world identity, area, generation, ticket and weather revision must
still match after the await. Retirement suppresses stale results/errors and
waits for outstanding work. Module clock/sky updates do not reset weather.

The native area environment privately owns rule metadata and weather state.
It rejects malformed/stale requests before mutation and accumulates fractional
milliseconds across native rendered frames. State resets with area retirement.
The snapshot field `plannedInstances` counts the six-model plan, **not actual
rendered models**. Every state envelope/snapshot explicitly marks
`presentationPending:true`.

## Verification and retained failures

- `weather-state-v1.json`:105 original-instruction sequential cases,
  **1077 exact comparisons**, zero failures. Includes missing/stock/custom,
  zero/negative FadeTime, rapid changes, clear requests, model-count lifetime
  and animation rate bits. Numeric fixtures contain no game assets.
- `weather-owner-v2.json`:13 headless native checks of validation, private
  metadata, fractional frame accumulation, state retirement and lifetime.
- `weather-backend-v2.log`:36 packet/current-area, stale delivery, retirement,
  evidence-gate, sky/atmosphere and offline captured-area regressions pass.
- Authored `GodotWeather1` SHA256
  `58e8554c23c3cadd305dcb681bec55e70d36f4a3f864542e007b996251d34eeb`,
  derived from our hashed GodotFeedback1 module. Commands
  `-native-weather-rain`, `-native-weather-snow`, `-native-weather-clear`
  execute actual installed-server SetWeather, whose parameter order/constants
  were checked against the installed read-only nwscript API.
- `weather-state-local-v2.json`:22 checks, actual rain→snow→clear→rain→clear
  messages, acknowledged scripts, intermediate fading and endpoints through
  real native frames. Actual SetWeather(CLEAR) emits type0/enabled1. The bool
  must be preserved; zero type still means a clear target. State plans18
  original model instances and retires all18 by the final clear. Graphics are
  still pending. Ordinary movement/animated presentation and16 dialogue/examine
  checks precede the weather check. Exit0, no forced termination, all6 tracked
  world owners and tracked UI/status resources retire.
- `weather-normal-local-v1.json`:ordinary GodotFeedback1 regression,16
  dialogue/examine checks, animated presentation, initial weather metadata and
  clean native retirement/exit0. The ordinary owned server is restored.

`weather-state-local-v1.json` is a retained failed harness run: it expected
enabled0 for clear and sent its terminal test acknowledgement without an area
scope, so the host rejected that acknowledgement and eventually timed out.
All five actual weather packets had arrived. The corrected probe uses the
observed wire semantics and normal scoped command path. This failure is not
counted as acceptance. The first backend regression log failed solely because
its offline asset-reading test lacked sandbox access; v2 used scoped read
access. The first owner-test parse warning was corrected with an explicit
WeakRef type; v2 is the successful run.

No online game-server connections, original process modifications, complete
weather/migration acceptance or performance claims are part of this stage.
The editor remains preserved, so local graphical tests are functional checks,
not clean GPU benchmarks.

The following rendering stage implements the six original instances, their
independent particle owners, placement and frozen-clip sampling, with visible
precipitation and real area/quit checks. See NATIVE-WEATHER-RENDER.md for the
actual evidence, unresolved crash and remaining scope.
