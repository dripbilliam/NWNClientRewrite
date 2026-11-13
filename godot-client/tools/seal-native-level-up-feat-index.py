"""Archive exact copied index evidence, without enumerating changing live sources."""
from pathlib import Path
import hashlib
import json
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
DESTINATION = PROJECT / ".cache/level-up-feat-index-evidence/native-level-up-feat-index-v1.zip"
CASES = (
    ("before79", "level-up-feat-index/mode1-responsiveness-before-v1"),
    ("after87", "level-up-feat-index/mode1-responsiveness-index-after-v1"),
    ("controls110", "level-up-feat-spell-recommended/operation-index-current-controls-v1"),
)
STATE = PROJECT / "systems/native_data/level_up_feat_state.gd"
EXPECTED_STATE = "5959c3a6b328ec36f68867ccc7d676894ac6a9467c66a7a11a0c8cff25b8c5d2"

def sha(data):
    return hashlib.sha256(data).hexdigest()

def encoded(value):
    return (json.dumps(value, indent=2) + "\n").encode()

def main():
    if DESTINATION.exists() or sha(STATE.read_bytes()) != EXPECTED_STATE:
        raise RuntimeError("Preserve existing evidence or changed owned source")
    payload = {}
    cases = []
    def include(name, source, expected=None):
        data = source.read_bytes()
        if expected is not None and sha(data) != expected:
            raise RuntimeError("Copied input differs: " + str(source))
        if name in payload:
            raise RuntimeError("Duplicate evidence path")
        payload[name] = data
    for label, relative in CASES:
        directory = PROJECT / ".cache" / relative
        proof = json.loads((directory / "proof.json").read_text())
        if not proof["success"] or proof["changedInputs"] or proof["changedCopies"] or proof.get("changedNative"):
            raise RuntimeError("Unaccepted source evidence")
        cases.append({"label": label, "checks": proof["checks"], "inputs": len(proof["inputs"])})
        for row in proof["inputs"]:
            relative_path = Path(row["path"])
            if relative_path.is_absolute() or ".." in relative_path.parts:
                raise RuntimeError("Invalid recorded input path")
            include(f"cases/{label}/inputs/{row['path']}", directory / "inputs" / relative_path, row["sha256"])
        for name in ("proof.json", "result.json", "stdout.log", "stderr.log", "engine.log"):
            if (directory / name).is_file():
                include(f"cases/{label}/{name}", directory / name)
        for folder in sorted(directory.glob("result.json.*resources")):
            for source in sorted(folder.rglob("*")):
                if source.is_file():
                    include(f"cases/{label}/{folder.name}/{source.relative_to(folder).as_posix()}", source)
    for relative in (
        "reports/native-level-up-responsiveness-before-v1.json",
        "reports/native-level-up-feat-operation-index-v1.json",
        "tools/seal-native-level-up-feat-index.py",
    ):
        include(relative, PROJECT / relative)
    before = PROJECT / ".cache/level-up-feat-index/operation-index-before-v1"
    for source in sorted(before.iterdir()):
        if source.is_file():
            include("dirty-before/" + source.name, source)
    manifest = {"schema": "native-level-up-feat-index-evidence-v1", "acceptedAfterChecks": 197,
        "baselineBeforeChecks": 79, "cases": cases,
        "scope": "Copied offline source/data profiling and controlled native input; engine and installed base game remain external pinned/test inputs. No new live-server, FPS or pixel acceptance.",
        "entries": [{"path": name, "sha256": sha(data), "bytes": len(data)} for name, data in sorted(payload.items())]}
    manifest_bytes = encoded(manifest)
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(DESTINATION, "x", zipfile.ZIP_DEFLATED, compresslevel=4) as archive:
        for name, data in sorted(payload.items()):
            archive.writestr(name, data)
        archive.writestr("manifest.json", manifest_bytes)
    with zipfile.ZipFile(DESTINATION) as archive:
        if archive.testzip() is not None or archive.read("manifest.json") != manifest_bytes:
            raise RuntimeError("Archive readback failed")
        for name, data in payload.items():
            if sha(archive.read(name)) != sha(data):
                raise RuntimeError("Archive source readback differs")
    if sha(STATE.read_bytes()) != EXPECTED_STATE:
        raise RuntimeError("Owned source changed during seal")
    result = {"success": True, "archive": str(DESTINATION), "sha256": sha(DESTINATION.read_bytes()),
        "manifestSha256": sha(manifest_bytes), "entries": len(payload) + 1,
        "bytes": DESTINATION.stat().st_size, "acceptedAfterChecks": 197, "ownedSourceUnchanged": True}
    DESTINATION.with_suffix(".json").write_bytes(encoded(result))
    print(json.dumps(result))

if __name__ == "__main__":
    main()
