V2b is report serialization ONLY. Source prepared; no Godot/parser/runtime run.
All26 original actual query inputs, pending/error/mutation cases, radiusNaN/Inf/
signedzero cases, exercise/assertions and var_to_bytes comparisons remain inherited
unchanged from immutable V2. Actual G failure logs/reports remain retained.

Final JSON serialization recursively copies Array/Dictionary report containers.
ONLY nonfinite scalar Float values become:
 {"nwn_report_nonfinite_float64_le_hex":"<16hex little-endian original f64 bits>"}
This avoids JSON.stringify NaN/Infinity warnings and preserves their bit identity.
It never substitutes finite input, reruns/coerces a query, changes equality checks,
or reconstructs any actual test argument from JSON. Finite and builtin Vector3
report values retain original JSON behavior. No new semantic acceptance claim.

Fresh runtime observer MUST extend:
res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v2b.gd
Copying it while observer still extends fixture-v2.gd is insufficient.
Use explicit new manifest-v2b.json+SHA and current B7/H candidate/contract. Same
26 cases/4 canonical positives. Root owns all native/compiler test slots.
