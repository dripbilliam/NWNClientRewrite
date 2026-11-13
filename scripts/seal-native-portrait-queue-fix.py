"""Seal the exact accepted Portrait raster admission sources and failure proof."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

workspace = Path(__file__).resolve().parents[1]
project = workspace / "godot-client"
before = project / ".cache/portrait-asset-queue-tests/20261103-082337-a0bee58d"
accepted = project / ".cache/portrait-asset-queue-tests/20261103-082902-e6900d82"
backup = project / ".cache/portrait-asset-queue-before"
destination = project / ".cache/portrait-asset-queue-checkpoints/sealed-v1"
digest = lambda data: hashlib.sha256(data).hexdigest()
read_json = lambda path: json.loads(path.read_text(encoding="utf-8-sig"))
passed = read_json(accepted / "runner.json")
rejected = read_json(before / "runner.json")
actual = read_json(accepted / "native_portrait_asset_queue_test.json")
failed = read_json(before / "native_portrait_asset_queue_test.json")
assert passed["success"] and not rejected["success"]
assert not passed["changedInputs"] and not passed["changedCopiedInputs"]
assert sum(row["checks"] for row in passed["results"]) == 40
assert all(row["cleanEngine"] and not row["timedOut"] for row in passed["results"])
assert not rejected["results"][0]["timedOut"] and rejected["results"][0]["cleanEngine"]
assert len(failed["actualBitmapEvidence"]["failedKeys"]) == 76
assert actual["actualBitmapEvidence"]["failedKeys"] == []
assert len(actual["actualBitmapEvidence"]["decoded"]) == 64
assert len(passed["inputs"]) == 155

files: dict[str, bytes] = {}
for row in passed["inputs"]:
    source = accepted / "project" / row["path"]
    data = source.read_bytes()
    assert digest(data) == row["sha256"], row["path"]
    files["accepted/project/" + row["path"]] = data

for name in ("native_ui_art.gd", "native_portrait_chooser.gd", "asset_service.gd"):
    files["dirty-before/" + name] = (backup / name).read_bytes()

for directory, label in ((before, "rejected-real-loader"), (accepted, "accepted")):
    for source in directory.iterdir():
        if source.is_file():
            files[label + "/" + source.name] = source.read_bytes()

for suffix in ("20261103-082201-0199add0", "20261103-082222-3bdc5406"):
    directory = project / ".cache/portrait-asset-queue-tests" / suffix
    for source in directory.iterdir():
        if source.is_file():
            files["prior-rejections/" + suffix + "/" + source.name] = source.read_bytes()
    files["prior-rejections/" + suffix + "/fixture.gd"] = (directory / "project/tests/native_portrait_asset_queue_test.gd").read_bytes()

art_path = "systems/native_ui_art.gd"
art_sha = digest(files["accepted/project/" + art_path])
assert art_sha == "e65699dad51a2b0190c0fdb84fcdc7c51c680638bf62fae7154ae81648be9949"
assert digest((project / art_path).read_bytes()) == art_sha
assert digest((before / "project" / art_path).read_bytes()) == digest((backup / "native_ui_art.gd").read_bytes())
for relative, name in (("systems/native_portrait_chooser.gd", "native_portrait_chooser.gd"), ("systems/native_data/asset_service.gd", "asset_service.gd")):
    assert digest(files["accepted/project/" + relative]) == digest((backup / name).read_bytes())

manifest = {
    "kind": "native-portrait-queue-fix-v1",
    "productionFilesChanged": [art_path],
    "productionSha256": art_sha,
    "acceptedDirectory": str(accepted.relative_to(project)).replace("\\", "/"),
    "rejectedDirectory": str(before.relative_to(project)).replace("\\", "/"),
    "acceptedChecks": {"realInstalledBitmapGallery": 20, "existingBindingIdentity": 8, "admissionAndRetirementPolicy": 12, "total": 40},
    "inputCount": 155,
    "reproduction": {"installedChoices": 125, "permanentFailedKeysBefore": 76, "failedKeysAfter": 0, "decodedActualBitmapResourcesAfter": 64, "deterministicTestQueueBound": 2, "productionQueueBoundUnchanged": 128},
    "behavior": "Only queue-full bitmap admission is deferred. Current weak bindings own deduplicated descriptors; actual completion drains capacity. Admitted reads retain an independent key index across rapid revisits. Rebind/unbind/freed targets/close retire obsolete work. Missing or corrupt resources remain explicit failures.",
    "limits": ["Frame model art and fonts controlled; portrait bytes/decode/publication are actual installed native assets.", "No screenshot/pixel or full live creator acceptance; no GPU/FPS claim.", "No AssetService, Portrait geometry/input, Painter, renderer, API or user-process change.", "Archive is the exact accepted copied closure, not a blanket claim about concurrent main-worktree files."],
    "publicConnections": 0,
    "nativeBuilds": 0,
    "files": [{"path": name, "sha256": digest(data), "bytes": len(data)} for name, data in sorted(files.items())],
}
manifest_bytes = (json.dumps(manifest, indent=2) + "\n").encode()
files["manifest.json"] = manifest_bytes
files["seal-script.py"] = Path(__file__).read_bytes()
destination.mkdir(parents=True, exist_ok=True)
archive = destination / "native-portrait-queue-fix-v1.zip"
assert not archive.exists(), "Do not overwrite a prior seal"
with ZipFile(archive, "x", compression=ZIP_DEFLATED, compresslevel=5) as output:
    for name, data in sorted(files.items()):
        output.writestr(name, data)
with ZipFile(archive) as output:
    assert set(output.namelist()) == set(files)
    for name, data in files.items():
        assert digest(output.read(name)) == digest(data), name

receipt = {
    "success": True,
    "archive": str(archive.relative_to(project)).replace("\\", "/"),
    "sha256": digest(archive.read_bytes()),
    "entries": len(files),
    "bytes": archive.stat().st_size,
    "productionSha256": art_sha,
    "checks": 40,
    "readbackVerified": True,
    "manifest": manifest,
}
(project / "reports/native-portrait-queue-fix-v1.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: value for key, value in receipt.items() if key != "manifest"}, indent=2))
