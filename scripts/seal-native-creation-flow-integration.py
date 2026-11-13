"""Seal owned creation integration and exact accepted native test inputs."""
from pathlib import Path
from hashlib import sha256
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot-client"
OUTPUT = ROOT / "backups/native-creation-flow-integration-v1.zip"
RECEIPT = PROJECT / "reports/native-creation-flow-integration-checkpoint-v1.json"
OWNED = [
    "systems/native_creation.gd", "systems/native_creation_frontend.gd",
    "systems/native_associate_chooser.gd", "systems/native_ok_scroll.gd",
    "systems/native_data/creation_associate_layout.gd",
    "systems/native_data/creation_associate_state.gd",
    "systems/native_data/creation_associate_preview.gd",
    "systems/native_data/creation_post_feats.gd", "tools/native-session-host.cjs",
    "tests/native_creation_associate_view_test.gd",
    "tests/native_creation_associate_binding_test.gd",
    "tests/run-native-creation-associate-view-tests.ps1",
    "tests/run-native-creation-associate-binding-tests.ps1",
    "NATIVE-CREATION-FLOW-INTEGRATION.md", "NATIVE-CREATION-ASSOCIATES.md",
    "NATIVE-UI-RESOURCE-INVENTORY.md", "NATIVE-UI-PARITY-GOAL.md",
    "reports/native-creation-associate-view-static-v1.json",
]

def digest(data):
    return sha256(data).hexdigest()

def main():
    if OUTPUT.exists() or RECEIPT.exists():
        raise RuntimeError("Preserve existing checkpoint; choose a new version")
    entries = {}
    cases = []
    for label, name, current in [
        ("standalone-input30", "native-creation-associate-view-v2", False),
        ("actual-draft-bic24", "native-creation-associate-binding-v4", True),
    ]:
        public = PROJECT / f"reports/{name}-receipt.json"
        proof = json.loads(public.read_text(encoding="utf-8-sig"))
        assert proof["success"] and proof["exitCode"] == 0
        assert proof["engineClean"] and not proof["timedOut"] and not proof["changedInputs"]
        directory = Path(proof["directory"])
        assert directory.resolve().is_relative_to(PROJECT.resolve())
        entries[f"evidence/{label}/receipt.json"] = public.read_bytes()
        for item in proof["inputs"]:
            relative = item["path"].replace("\\", "/")
            assert ".." not in Path(relative).parts
            data = (directory / "project" / relative).read_bytes()
            assert digest(data) == item["sha256"], relative
            if current:
                assert digest((PROJECT / relative).read_bytes()) == item["sha256"], relative
            entries[f"evidence/{label}/source/{relative}"] = data
        for name in ["result.json", "engine.log", "stdout.log", "stderr.log"]:
            entries[f"evidence/{label}/{name}"] = (directory / name).read_bytes()
        cases.append({"label": label, "checks": proof["result"]["checks"],
                      "inputs": len(proof["inputs"]), "current": current,
                      "scope": proof["result"]["scope"]})
    for relative in OWNED:
        entries["current/godot-client/" + relative] = (PROJECT / relative).read_bytes()
    entries["scripts/seal-native-creation-flow-integration.py"] = Path(__file__).read_bytes()
    before = ROOT / ".cache/associate-view-checkpoints/20261103-064013-before"
    for path in sorted(before.iterdir()):
        if path.is_file():
            entries["before-existing-dirty-files/" + path.name] = path.read_bytes()
    failed = PROJECT / ".cache/associate-binding-tests/20261103-070032-bbd1a833/engine.log"
    with failed.open("rb") as stream:
        prefix = stream.read(16384)
    entries["rejected/recursion-summary.json"] = json.dumps({
        "accepted": False, "reason": "Reentrant route_post dispatch; stack overflow then runner output memory failure",
        "rawLog": str(failed), "rawBytes": failed.stat().st_size,
        "prefix": prefix.decode("utf-8", errors="replace"),
        "fullLogRetained": True,
    }, indent=2).encode()
    for name in ["20261103-070321-59f3bd31", "20261103-070519-d3757828"]:
        directory = PROJECT / ".cache/associate-binding-tests" / name
        for filename in ["engine.log", "receipt.json"]:
            entries[f"rejected/{name}/{filename}"] = (directory / filename).read_bytes()
    manifest = {name: {"sha256": digest(data), "bytes": len(data)} for name, data in sorted(entries.items())}
    entries["manifest.json"] = json.dumps(manifest, indent=2).encode()
    with zipfile.ZipFile(OUTPUT, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(entries.items()):
            archive.writestr(name, data)
    with zipfile.ZipFile(OUTPUT) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(entries)
        for name, data in entries.items():
            assert digest(archive.read(name)) == digest(data), name
    packet = {"success": True, "archive": str(OUTPUT), "sha256": digest(OUTPUT.read_bytes()),
              "bytes": OUTPUT.stat().st_size, "entries": len(entries), "cases": cases,
              "serverConnections": 0, "gpu": False, "fullCreationParity": False,
              "originalPixels": False, "serverAdmission": False, "goalComplete": False,
              "navigationProof": "reports/native-pregame-flow-v1-receipt.json (independent agent seal)",
              "remaining": ["appearance/info integration", "level-up", "original continuation/write ordering",
                            "original-client visual comparison", "authoritative server admission",
                            "40–87ms synchronous action/cleanup overhead"]}
    RECEIPT.write_text(json.dumps(packet, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(packet, indent=2))

if __name__ == "__main__":
    main()
