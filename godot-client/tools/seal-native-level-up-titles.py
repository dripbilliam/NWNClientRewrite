"""Seal exact accepted and rejected title-test copies; never collect live user data."""
from pathlib import Path
import hashlib
import json
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
WORKSPACE = PROJECT.parent
DESTINATION = PROJECT / ".cache/level-up-title-evidence/native-level-up-titles-v1.zip"
CASES = [
    ("font-parse-reject", "level-up-title-presentation/level-up-title-presentation-v1", False),
    ("font-diagnostic-reject", "level-up-title-presentation/level-up-title-presentation-v2", False),
    ("font-label-model-reject", "level-up-title-presentation/level-up-title-presentation-v3", False),
    ("font151", "level-up-title-presentation/level-up-title-presentation-v4", True),
    ("runtime-expected-class-reject", "level-up-title-runtime/level-up-title-runtime-v1", False),
    ("runtime-known72", "level-up-title-runtime/level-up-title-runtime-v2", True),
    ("runtime-unknown72", "level-up-title-runtime/level-up-title-runtime-unknown-v1", True),
]

def digest(data):
    return hashlib.sha256(data).hexdigest()

def encode(value):
    return (json.dumps(value, indent=2) + "\n").encode()

def main():
    if DESTINATION.exists():
        raise RuntimeError("Preserve existing immutable evidence")
    payload = {}
    current = {}
    cases = []
    def include(name, source, expected=None):
        data = source.read_bytes()
        if expected is not None and digest(data) != expected:
            raise RuntimeError("Copied input changed: " + str(source))
        if name in payload:
            raise RuntimeError("Duplicate archive name: " + name)
        payload[name] = data
    for label, relative, accepted in CASES:
        directory = PROJECT / ".cache" / relative
        proof = json.loads((directory / "runner.json").read_text())
        if proof["success"] != accepted or proof["changedInputs"] or proof["changedCopy"] or proof["changedNative"]:
            raise RuntimeError("Unexpected retained evidence state: " + label)
        cases.append({"label": label, "accepted": accepted, "checks": proof["checks"], "inputs": len(proof["inputs"])})
        for row in proof["inputs"]:
            relative_path = Path(row["path"])
            if relative_path.is_absolute() or ".." in relative_path.parts:
                raise RuntimeError("Invalid recorded relative path")
            include(f"cases/{label}/inputs/{row['path']}", directory / "inputs" / relative_path, row["sha256"])
            original = WORKSPACE / relative_path
            if original.exists():
                current[original] = digest(original.read_bytes())
        for filename in ("runner.json", "result.json", "engine.log", "stdout.log", "stderr.log"):
            if (directory / filename).is_file():
                include(f"cases/{label}/{filename}", directory / filename)
        resources = directory / "result.json.resources"
        if resources.exists():
            for source in sorted(resources.rglob("*")):
                if source.is_file():
                    include(f"cases/{label}/resources/{source.relative_to(resources).as_posix()}", source)
    for relative in (
        "reports/native-level-up-title-presentation-plan-v1.json",
        "reports/native-level-up-title-presentation-v1-receipt.json",
        "reports/native-level-up-title-integration-v1-receipt.json",
        "tools/seal-native-level-up-titles.py",
    ):
        include(relative, PROJECT / relative)
    before = PROJECT / ".cache/level-up-title-presentation/title-runtime-before-v1"
    for source in sorted(before.iterdir()):
        if source.is_file():
            include("dirty-before/" + source.name, source)
    manifest = {"schema": "native-level-up-title-evidence-v1", "acceptedChecks": 295,
        "cases": cases, "runtimeIntegrated": True, "originalPixelsAccepted": False,
        "serverConnections": 0, "userProcessActions": 0,
        "entries": [{"path": name, "sha256": digest(data), "bytes": len(data)} for name, data in sorted(payload.items())]}
    manifest_bytes = encode(manifest)
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(DESTINATION, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, data in sorted(payload.items()):
            archive.writestr(name, data)
        archive.writestr("manifest.json", manifest_bytes)
    with zipfile.ZipFile(DESTINATION) as archive:
        if archive.testzip() is not None or archive.read("manifest.json") != manifest_bytes:
            raise RuntimeError("Archive integrity failure")
        for name, data in payload.items():
            if digest(archive.read(name)) != digest(data):
                raise RuntimeError("Archive readback differs: " + name)
    if any(digest(source.read_bytes()) != expected for source, expected in current.items()):
        raise RuntimeError("A current source changed during seal")
    result = {"success": True, "archive": str(DESTINATION), "entries": len(payload) + 1,
        "bytes": DESTINATION.stat().st_size, "sha256": digest(DESTINATION.read_bytes()),
        "manifestSha256": digest(manifest_bytes), "acceptedChecks": 295, "currentSourcesUnchanged": True}
    DESTINATION.with_suffix(".json").write_bytes(encode(result))
    print(json.dumps(result))

if __name__ == "__main__":
    main()
