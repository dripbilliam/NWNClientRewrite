# Private native clock source to timer integration

This is an authored, unrun integration plan. The accepted DLL remains private; no main project descriptor, build output, Host, Gameplay, World, session or remote clock owner is changed.

## Provider domain

WorldTimer.provider_words accepts the existing nonnegative Godot integer domain unchanged, or an explicit validated unsigned64 {hi,lo} dictionary. It projects/copies the two DWORDs and never casts a fullu64 through float or signed64. Invalid/unknown samples leave initialize/snapshot state and the previous provider unchanged. The complete DLL sample envelope is not a timer value: callers pass sample.microseconds only after sample.ready.

The prior7,924 checks remain unchanged. Fifty new checks cover integer compatibility, highbit/UINT64_MAX construction, exact constructor offsets, snapshot wrap/difference, unknown/malformed values, invalid reinitialization, retained provider identity and mutation isolation. Before bytes of Timer/test/fixture are preserved at .cache/native-remote-client-clock/provider-words-before-v1, manifest SHAc490401fe2e13777d12186d1121f7063c4cc16c8e1434b2070b163a21ed1af35. The old fixture itself remains unchanged. Proposed component total:7,974.

## Private actual source composition

The separate fixture loads the accepted candidate DLL SHA497e483e44595a7518b860f92c55e3ab3cef9cd372b15c53a2ac31dfd2498190 and its already-accepted descriptor into its own copied project. It calls static NwnClockSourceCandidate.sample, injecting actual ready microseconds limbs directly into three independent real Godot WorldTimers. It verifies exact constructor/snapshot limbs, unchanged paused pairs, conditional pre-receive snapshot order and nested mask1/mask2 transition ordering. Actual reset retains each destination provider; explicit sync yields zero modular differences.

All lower objects/scenes/GUI are explicitly absent, with recorded audio/text callbacks. This is CPU component composition, not real native GUI/audio/object execution. Every captured sample must retain source native-direct-real-candidate-v1 and phase direct-real-only. Sample diagnostics are bounded to64 per provider. No synthetic QPC, authoring of world poses, wall-clock delay expectation or performance claim is added.

The candidate's earlier663 source/ABI checks are a separate accepted scope. This gate does not execute original nwmain instructions, reproduce native cached-thread phase, promote the DLL, establish process-service/remote initialization, or activate clocks in the game. The absolute counter/rate-change caveat remains: no arbitrary zero-origin substitution is authorized.

## Commands and guards

Proposed, not yet run:

    node godot-client/tools/test-native-remote-client-clock-component.mjs native-remote-client-clock-provider-words-v1
    node godot-client/tools/test-native-private-clock-timer.mjs native-private-clock-timer-v1

Each child is headless/max-fps60 with65s/2MiB limits and unique retained evidence labels. The component runner retains its16 source/copy pins and all904 original cases. The private integration runner pins16 inputs: current3GD, runner/document, immutable candidate manifest/build/proof/source/descriptor/DLL/read-only build inputs, plus existing main project/particle descriptor guards. Only the accepted DLL/descriptor and current3GD are copied into its private project. Compiler, candidate artifacts and main descriptors are not modified or launched.

Both runners guard existing engine SHA and six shared native outputs. There is no network, server, profile/key access, GPU/visible client, native compiler/build or user-process action. Expected private composition:85 checks, distinct from7,974 component checks and prior663 candidate checks. Root must approve the exact commands/source atom before execution.

