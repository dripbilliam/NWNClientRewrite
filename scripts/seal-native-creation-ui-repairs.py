"""Preserve the scoped creator repairs and their exact accepted test snapshots."""
from pathlib import Path
from hashlib import sha256
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot-client"
ARCHIVE = ROOT / "backups/native-creation-ui-repairs-v1.zip"
RECEIPT = PROJECT / "reports/native-creation-ui-repairs-v1-checkpoint.json"
CASES = {
    "native-creation-spells-raster-v6": 12,
    "native-creation-urgent-ui-binding-v2": 24,
    "native-creation-preview-equipment-v1": 11,
}
OWNED = [
    "systems/native_spells_chooser.gd",
    "systems/native_creation_preview.gd",
    "systems/native_data/combat_actor.gd",
]


def digest(data):
    return sha256(data).hexdigest()


def main():
    assert not ARCHIVE.exists() and not RECEIPT.exists(), "Preserve earlier checkpoints"
    entries, results = {}, []

    def add(name, data):
        assert not Path(name).is_absolute() and ".." not in Path(name).parts
        assert name not in entries or entries[name] == data
        entries[name] = data

    covered = {}
    for name, expected in CASES.items():
        receipt = PROJECT / "reports" / f"{name}-receipt.json"
        case = json.loads(receipt.read_text(encoding="utf-8-sig"))
        assert case["success"] and case["engineClean"] and case["exitCode"] == 0
        assert not case["timedOut"] and not case["changedInputs"]
        assert case["result"]["success"] and case["result"]["checks"] == expected
        directory = Path(case["directory"]).resolve()
        assert directory.is_relative_to((PROJECT / ".cache").resolve())
        log = (directory / "engine.log").read_text(encoding="utf-8-sig")
        assert not re.search(r"(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|Unicode parsing error|ObjectDB instances leaked|Leaked instance|still in use at exit", log)
        current_changes = []
        for row in case["inputs"]:
            relative = row["path"]
            data = (directory / "project" / relative).read_bytes()
            assert digest(data) == row["sha256"]
            add(f"accepted/{name}/inputs/{relative}", data)
            if digest((PROJECT / relative).read_bytes()) != row["sha256"]:
                current_changes.append(relative)
            if relative in OWNED:
                covered[relative] = row["sha256"]
        add(f"accepted/{name}/receipt.json", receipt.read_bytes())
        for child in directory.iterdir():
            if child.is_file() and child.name != "receipt.json":
                assert child.stat().st_size < 8 * 1024 * 1024
                add(f"accepted/{name}/{child.name}", child.read_bytes())
        results.append({"name": name, "checks": expected, "scope": case.get("scope", case["result"].get("scope")),
                        "changedSinceAcceptedSnapshot": current_changes})
    for relative in OWNED:
        data = (PROJECT / relative).read_bytes()
        assert relative in covered and digest(data) == covered[relative], relative
        add("current-root-repairs/" + relative, data)
    before = ROOT / ".cache/creation-render-fixes/20261103-075608-before"
    for child in before.iterdir():
        if child.is_file():
            assert child.stat().st_size < 2 * 1024 * 1024
            add("preserved-before/" + child.name, child.read_bytes())
    add("documentation/NATIVE-CREATION-UI-REPAIRS.md", (PROJECT / "NATIVE-CREATION-UI-REPAIRS.md").read_bytes())
    add("scripts/seal-native-creation-ui-repairs.py", Path(__file__).read_bytes())
    manifest = {"cases": results, "checks": sum(CASES.values()),
                "scope": "Root spell foreground/actual raster and preview-equipment repairs. Exact historical accepted inputs retained separately by case; later unrelated UI edits are listed, never silently upgraded to tested inputs. Portrait, Attributes, feat-subtype and claimed-title owners have separate checkpoints. No live-server or full-creator completion acceptance.",
                "entries": [{"path": name, "sha256": digest(data), "bytes": len(data)} for name, data in sorted(entries.items())]}
    add("manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())
    ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ARCHIVE, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(entries.items()):
            archive.writestr(name, data)
    with zipfile.ZipFile(ARCHIVE) as archive:
        assert archive.testzip() is None and len(archive.infolist()) == len(entries)
        for name, data in entries.items():
            assert archive.read(name) == data
    result = {"success": True, "archive": str(ARCHIVE.relative_to(ROOT)), "sha256": digest(ARCHIVE.read_bytes()),
              "entries": len(entries), "bytes": ARCHIVE.stat().st_size, "checks": sum(CASES.values()),
              "readbackVerified": True, "scope": manifest["scope"]}
    RECEIPT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
