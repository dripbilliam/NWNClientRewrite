"""Seal immutable accepted copies; never substitute later dirty worktree bytes."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot-client"
DEST = PROJECT / ".cache/level-up-context-wait/sealed-v1"
CASES = [
    (PROJECT / ".cache/level-up-context-wait/runtime-v5", 61),
    (PROJECT / ".cache/level-up-random-owner/context-wait-random-v1", 47),
    (PROJECT / ".cache/level-up-rule-publication/context-wait-runtime-v1", 52),
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


if DEST.exists():
    raise RuntimeError("Existing seal preserved")
entries = {}
proofs = []


def add(name, data):
    if name in entries and entries[name] != data:
        raise RuntimeError("Conflicting accepted input: " + name)
    entries[name] = data


for case, count in CASES:
    proof_bytes = (case / "proof.json").read_bytes()
    proof = json.loads(proof_bytes)
    if not (proof["success"] and proof["checks"] == count and proof["cleanEngine"]
            and proof["exitCode"] == 0 and not proof.get("changedInputs")
            and not proof.get("changedCopies")):
        raise RuntimeError("Complete clean accepted proof required: " + str(case))
    for row in proof["inputs"]:
        relative = Path(row["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise RuntimeError("Input leaves copied workspace")
        data = (case / "inputs" / relative).read_bytes()
        if sha(data) != row["sha256"]:
            raise RuntimeError("Accepted copy changed: " + str(relative))
        add("inputs/" + relative.as_posix(), data)
    for filename in ["proof.json", "result.json", "engine.log", "stdout.log", "stderr.log"]:
        add("evidence/" + case.name + "/" + filename, (case / filename).read_bytes())
    proofs.append({"path": str(case.relative_to(PROJECT) / "proof.json"),
                   "sha256": sha(proof_bytes), "checks": count,
                   "inputs": len(proof["inputs"])})
for source in sorted((PROJECT / ".cache/level-up-context-wait/before-v1").iterdir()):
    if not source.is_file():
        raise RuntimeError("Unexpected dirty-before entry")
    add("before/" + source.name, source.read_bytes())
for name in ["NATIVE-LEVEL-UP-CONTEXT-WAIT.md", "NATIVE-LEVEL-UP-PARITY-GOAL.md"]:
    add("docs/" + name, (PROJECT / name).read_bytes())
add("seal-script.py", Path(__file__).read_bytes())
manifest = {"version": 1, "scope": "Immutable accepted context-wait checkpoint only; no server/pixel/full-flow acceptance or coverage of later worktree edits.",
            "proofs": proofs, "entries": [{"path": name, "bytes": len(data), "sha256": sha(data)}
                                         for name, data in sorted(entries.items())]}
manifest_bytes = (json.dumps(manifest, indent=2) + "\n").encode()
add("manifest.json", manifest_bytes)
DEST.mkdir(parents=True)
archive = DEST / "native-level-up-context-wait-v1.zip"
with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as output:
    for name, data in sorted(entries.items()):
        output.writestr(name, data)
with zipfile.ZipFile(archive) as verify:
    if verify.testzip() is not None or set(verify.namelist()) != set(entries):
        raise RuntimeError("Archive CRC/inventory differs")
    for name, data in entries.items():
        if verify.read(name) != data:
            raise RuntimeError("Archive readback differs: " + name)
receipt = {"version": 1, "success": True, "scope": manifest["scope"], "proofs": proofs,
           "archive": str(archive.relative_to(PROJECT)), "sha256": sha(archive.read_bytes()),
           "bytes": archive.stat().st_size, "entries": len(entries),
           "manifestSha256": sha(manifest_bytes), "serverConnections": 0,
           "nativeBuilds": 0, "gpu": False, "laterWorktreeCoverageClaimed": False}
report = PROJECT / "reports/native-level-up-context-wait-v1.json"
with report.open("x", encoding="utf8") as output:
    output.write(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt))
