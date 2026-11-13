# NWN-64 private actor-clock validity bypass — rejected

Status: **not promoted**. No accepted particle source, DLL, engine or runtime selection changed; no renderer or FPS test was run.

## Candidate and exact source pair

The accepted shared presenter checks `Callable.is_valid()` on every actor-clock source before the existing opt-in canonical `ModelRigs` reader. A private candidate attempted the guarded native read first; only when it declined did the original validity check and Callable path run. This removes a validity dispatch on a successful canonical read without caching an owner, source string, model or time between emitters. The native reader itself still checks current ObjectID, Script identity, canonical source and live dictionary values at each source boundary.

Two private DLLs were built with the same pinned MSVC flags and 47-file current-source closure; only `native/particle_presentation.hpp` differs. Control source SHA-256 `643dc50015c8f406aad9a9da3fe150a73dbd0b7853508799cdb1c70c319ac97f`, candidate `597432d634884e04740895f6a4c548d3d1a4fe2eaef265fa13cad09da2ec5091`; control DLL `50ffcfab47ff7184e845bbcd33bcfe7fa5b9bf7524efaaebc5740f67858f9ddd`, candidate DLL `83eda7798303d19a160125cf8606da1b7e177e9e75bd8a83cbb6a6eb6f4be56c`. The installed DLL remains SHA-256 `485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d`. Build and source manifests are under `.cache/native-render-gap/particles/nwn64-clock-validity-{control-a,a}/`.

## Functional gate

The pinned receipt `.cache/nwn64/clock-validity-parity-c/receipt.json` (SHA-256 `dd9654c148eb15399bc8ad6fae864c717a4fa9db90646c8cccbc09119b673916`) records two isolated headless fixtures using the same current-source control and candidate. The focused clock fixture passed 823 checks in each mode, including script edit/reload, replacement, derived scripts, unsupported conversions, callbacks and reentry; packet digest, RNG state and RNG draws match. The 1,750-source/960-culled fixture passed 3,624 checks in each mode; packet digest, RNG state/draws and output summary match. It retained 42,000 successful native reads while reducing the diagnostic validity-call count from 42,000 to zero. The focused candidate retained 77 validity calls on fallback cases versus 427 in control. A known Windows root-certificate diagnostic was excluded from the isolated test log gate; both test processes exited zero and had no test or native errors.

## Component cost and decision

One headless profile-off component ABBA and one reversed-order BAAB used 240 frames per leg, 160 measured `NwnParticlePresentation` calls per leg, identical native binary flags and original-packet/RNG witnesses. Receipts: `.cache/nwn64/clock-validity-cost-a/receipt.json` SHA-256 `4f00e24772af22eeb0dbcdcf4ddd20a6b04f0778969a625954ab5d56b77baa0f`; `clock-validity-cost-b/receipt.json` SHA-256 `a423c3e7560f2dd17fa58afa3b5f4290166f561b0e99f09c624997de74124088`.

| Sequence | Control mean | Candidate mean | Difference |
| --- | ---: | ---: | ---: |
| ABBA | 1.140 ms | 0.959 ms | 0.181 ms saved |
| BAAB | 1.025 ms | 0.989 ms | 0.037 ms saved |

The first ABBA control leg was slower (1.265 ms) than its later control leg (1.015 ms), while the reversed-order sequence narrows the saving to 0.037 ms. This is a synthetic case with 350 canonical clocks. The previous original-scene census counted only 47 live callable sources among 919 shared sources; linear scaling from the smaller BAAB saving would suggest about 0.005 ms in that scene, **an inference, not a measurement**. Reordering callable validity for that small expected gain adds a subtle semantic proof obligation around invalid/reloaded Callables. The candidate is therefore rejected for production. The already separate opt-in canonical reader has a larger synthetic component effect, but its accepted-binary and live impact remain unproven. NWN-64 stays In Progress.
