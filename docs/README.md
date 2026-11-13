# Project documentation

Start with the [project overview](../README.md), [native launch guide](../godot-client/README.md) and [playable-parity backlog](parity.md).

| Guide | Contents |
| --- | --- |
| [Architecture](architecture.md) | Native ownership, entry points and remaining services |
| [Development](development.md) | Setup, validation and working safely with existing evidence |
| [Networking](networking.md) | Admission, replicated state, transfers and connection recovery |
| [Characters](characters.md) | Creation, saved characters, level-up and active rules |
| [Gameplay](gameplay.md) | Movement, interactions, combat and recovery |
| [Interface](interface.md) | Original UI, inventory, party, text and input contracts |
| [Rendering](rendering.md) | Models, visibility, lighting, particles and presentation gaps |
| [Performance](performance.md) | Latest measured checkpoint, loading and frame-time limits |
| [Resources](resources.md) | Catalog precedence, native formats, caches and audio |
| [Clocks](clocks.md) | Clock domains, lifecycle ownership and parked experiments |
| [Research](research.md) | Original binary, evidence standards and research entry points |
| [Archived notes](archive.md) | Find or read any pre-consolidation note |

Current work belongs in these guides and [Linear](https://linear.app/nwnanalog/issue/NWN-13/complete-playable-parity-with-the-base-native-client). Update an existing section; avoid another milestone, continuation, goal or handoff Markdown file.

Keep historical test receipts and exact source pins in their existing JSON/log/archive artifacts. A new passing component test does not establish complete native-client parity. The compressed archive preserves original observations, inferences, failures, addresses and commands; it is history, not a current status feed.

Some documentation remains beside tools because the tools pin it as an input. See the archive manifest for those exceptions. The [entity API](../godot-client/ENTITY-API.md), [client flags](../godot-client/CLIENT-FLAGS.md), [extension build reference](../godot-client/native/README.md) and [deferred performance queue](../scripts/performance-queue/README.md) remain separate operational references.
