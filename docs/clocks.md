# Clocks and lifecycle

Clock domains and lifecycle ownership are part of native behavior. Do not treat engine delta, real time, game time, world time, per-object clocks and GUI timers as interchangeable.

The special native-clock/DLL experiments are parked unless specifically resumed. They are not a prerequisite for ordinary speech readability or the multiplayer parity backlog. A reviewed launch using an explicit clock flag is a different acceptance route from a default launch without it.

## Contracts to preserve

- Capture ordered received events and lifecycle witnesses before coalesced world/UI publication.
- Keep connection, generation, actor/disclosure lifetime and physical owner identity separate.
- Unknown construction time, missing lifecycle state or a delivery gap is not permission to invent a timestamp.
- Retain pause, cleanup, timer and AI/GUI clock ownership across reconnect, model replacement and retirement.
- A reused numeric object ID or retained physical owner does not automatically acquire a new birth time.
- Separate raw literal ScriptFloating delivery, parsed STRREF delivery and ordinary speech receipt policies.

## Retained harness inputs

A small set of original notes remains because copied-source tests include those exact paths:

| Reference | Scope |
| --- | --- |
| [Remote lifecycle](../godot-client/NATIVE-REMOTE-CLIENT-CLOCK-LIFECYCLE.md) | Construction and lifetime boundaries |
| [Services](../godot-client/NATIVE-CLIENT-CLOCK-SERVICES.md) | Process timers, cleanup and clock services |
| [Object clocks](../godot-client/NATIVE-CLIENT-OBJECT-CLOCKS.md) | Per-object ownership |
| [Runtime test](../godot-client/NATIVE-CLIENT-CLOCK-RUNTIME-TEST.md) | Isolated actual pipeline gate |
| [Remote component](../godot-client/NATIVE-REMOTE-CLIENT-CLOCK-COMPONENT.md) | Received/private component boundary |
| [Private timer integration](../godot-client/NATIVE-PRIVATE-CLOCK-TIMER-INTEGRATION.md) | Optional private provider |
| [Original pause clocks](../evidence/client-pause-clocks.md) | Original timing evidence |

These are scoped reproducibility references, not a statement that all routes are installed or accepted. Additional historical ingress, owner, parser and GUI-clock contracts are recoverable from the archive.
