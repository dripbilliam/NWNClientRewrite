"""Losslessly compress one owned rejected-test log, after readback verification."""
from pathlib import Path
from hashlib import sha256
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "godot-client/.cache/associate-binding-tests/20261103-070032-bbd1a833"
SOURCE = DIRECTORY / "engine.log"
ARCHIVE = DIRECTORY / "engine-log-rejected.zip"
RECEIPT = DIRECTORY / "engine-log-compression.json"

def hashed(stream):
    state = sha256()
    while block := stream.read(1024 * 1024):
        state.update(block)
    return state.hexdigest()

def main():
    assert SOURCE.resolve().is_relative_to((ROOT / "godot-client/.cache/associate-binding-tests").resolve())
    assert SOURCE.name == "engine.log" and SOURCE.is_file()
    assert not ARCHIVE.exists() and not RECEIPT.exists()
    before = SOURCE.stat()
    with SOURCE.open("rb") as stream:
        original_hash = hashed(stream)
    with zipfile.ZipFile(ARCHIVE, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        archive.write(SOURCE, "engine.log")
    with zipfile.ZipFile(ARCHIVE) as archive:
        assert archive.namelist() == ["engine.log"]
        assert archive.getinfo("engine.log").file_size == before.st_size
        with archive.open("engine.log") as stream:
            assert hashed(stream) == original_hash
    assert SOURCE.stat().st_size == before.st_size and SOURCE.stat().st_mtime_ns == before.st_mtime_ns
    with SOURCE.open("rb") as stream:
        assert hashed(stream) == original_hash
    packet = {"success": True, "source": str(SOURCE), "sourceBytes": before.st_size,
              "sourceSha256": original_hash, "archive": str(ARCHIVE),
              "archiveBytes": ARCHIVE.stat().st_size, "archiveEntry": "engine.log",
              "verifiedLosslessReadback": True, "ownedRejectedTestOnly": True,
              "sourceReplacedByCompressedCopy": True}
    RECEIPT.write_text(json.dumps(packet, indent=2) + "\n", encoding="utf-8")
    # Only this exact, verified owned test output is removed; the archived bytes
    # and failure evidence remain available and no source/user file is touched.
    SOURCE.unlink()
    print(json.dumps(packet, indent=2))

if __name__ == "__main__":
    main()
