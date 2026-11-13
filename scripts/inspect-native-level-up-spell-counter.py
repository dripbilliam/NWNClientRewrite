"""Read-only original9ce190 counter history for memorizing/no-scroll mode1.

Execute unchanged original initialization and OK admission through the retained
spell oracle's captured class/book/ability/GUI getter boundaries. This establishes
when the old GUI counter is overwritten; it does not execute table loading,
source UI integration, server progression, rendering or a user process.
"""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot-client"
OUT = PROJECT / ".cache/level-up-spell-counter/original-v1"
if OUT.exists():
    raise RuntimeError("Existing counter evidence preserved")
source = ROOT / "scripts/inspect-native-creation-spell-selection.py"
fixture = PROJECT / "reports/native-creation-spell-selection-original-v1.json"
inputs = [Path(__file__), source, fixture,
          ROOT / "scripts/inspect-native-intratile-coordinator.py"]
pins = [{"path": p.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
        for p in inputs]
spec = importlib.util.spec_from_file_location("original_spell_selection", source)
original = importlib.util.module_from_spec(spec)
spec.loader.exec_module(original)
corpus = json.loads(fixture.read_text())
if corpus["target"] != original.m.digest or len(corpus["rows"]) != 480:
    raise RuntimeError("Complete pinned original initializer corpus required")
rows = []
overwritten = 0
retained = 0
for number, existing in enumerate(corpus["rows"]):
    value = existing["input"]
    if not value["memorizes"] or value["learnScroll"]:
        continue
    reached = [level for level in range(10) if value["capacity"][level] and value["minimum"][level]]
    expected = max(0, value["capacity"][reached[-1]] - len(value["known"][reached[-1]])) if reached else None
    outputs = []
    for seed in [0, 1, 73, 65535]:
        current = copy.deepcopy(value)
        current["storedRemaining"] = seed
        result = original.run(current)
        if result["output"]["remaining"] != (expected if reached else seed):
            raise RuntimeError("Original counter mismatch in case " + str(number))
        outputs.append({"storedRemaining": seed, "output": result["output"]})
    if reached:
        overwritten += 1
        if any(row["output"] != outputs[0]["output"] for row in outputs[1:]):
            raise RuntimeError("Prior counter affected a guaranteed overwritten case")
    else:
        retained += 1
    rows.append({"corpusIndex": number, "input": value, "reached": reached,
                 "derivedCounter": expected, "runs": outputs})
if not rows or not overwritten or not retained:
    raise RuntimeError("Both guaranteed-write and prior-counter-dependent paths required")
for pin in pins:
    if hashlib.sha256((ROOT / pin["path"]).read_bytes()).hexdigest() != pin["sha256"]:
        raise RuntimeError("Original input changed")
report = {"version": 1, "success": True, "target": original.m.digest,
          "scope": __doc__, "sources": pins, "cases": len(rows),
          "originalExecutions": len(rows) * 4,
          "guaranteedOverwriteCases": overwritten, "priorCounterCases": retained,
          "rows": rows, "serverConnections": 0, "gpu": False, "nativeBuilds": 0}
OUT.mkdir(parents=True)
(OUT / "result.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({key: value for key, value in report.items() if key not in ["rows", "sources"]}))
