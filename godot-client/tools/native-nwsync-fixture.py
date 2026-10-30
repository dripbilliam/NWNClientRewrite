"""Authored local NWSync data. No original assets, keys or network access."""
import hashlib
import json
import pathlib
import sqlite3
import struct
import tempfile
import zlib

root = pathlib.Path(tempfile.mkdtemp(prefix="nwn-native-nwsync-test-"))
cache = root / "cache"
installed = root / "installed"
for folder in (cache / "manifests", cache / "objects", installed):
    folder.mkdir(parents=True, exist_ok=True)

def blob(data, algorithm):
    payload = data if algorithm == 0 else struct.pack("<I", 1) + zlib.compress(data)
    return b"NSYC" + struct.pack("<III", 3, algorithm, len(data)) + payload

def ref(name, kind):
    return name.encode("cp1252").ljust(16, b"\0") + struct.pack("<H", kind)

data = b"2DA V2.0\n\nLabel Value\n0 Native 17\n1 Worker 23\n"
digest = hashlib.sha1(data).hexdigest()
manifest = b"NSYM" + struct.pack("<III", 3, 1, 2)
manifest += bytes.fromhex(digest) + struct.pack("<I", len(data)) + ref("native_table ", 2017)
manifest += struct.pack("<I", 0) + ref("alias", 2017)
manifest += struct.pack("<I", 0) + ref("generic", 0)
manifest_hash = hashlib.sha1(manifest).hexdigest()
(cache / "manifests" / manifest_hash).write_bytes(manifest)
(cache / "objects" / digest).write_bytes(blob(data, 1))
for algorithm in (0, 1):
    (root / f"blob{algorithm}").write_bytes(blob(data, algorithm))
(root / "raw").write_bytes(data)
meta = sqlite3.connect(installed / "nwsyncmeta.sqlite3")
meta.executescript("CREATE TABLE manifests(sha1 TEXT); CREATE TABLE manifest_resrefs(manifest_sha1 TEXT,resref TEXT,restype INTEGER,resref_sha1 TEXT); CREATE TABLE shards(id INTEGER);")
meta.execute("INSERT INTO manifests VALUES(?)", (manifest_hash,))
meta.execute("INSERT INTO shards VALUES(1)")
for name in ("native_table ", "alias"):
    meta.execute("INSERT INTO manifest_resrefs VALUES(?,?,?,?)", (manifest_hash, name, 2017, digest))
meta.execute("INSERT INTO manifest_resrefs VALUES(?,?,?,?)", (manifest_hash, "generic", 0, digest))
meta.commit()
meta.close()
shard = sqlite3.connect(installed / "nwsyncdata_0.sqlite3")
shard.execute("CREATE TABLE resrefs(sha1 TEXT,data BLOB)")
shard.execute("INSERT INTO resrefs VALUES(?,?)", (digest, blob(data, 1)))
shard.commit()
shard.close()
fixture = {"root": str(root), "cache": str(cache), "installed": str(installed), "hash": manifest_hash, "resource": digest, "bytes": len(data)}
file = root / "fixture.json"
file.write_text(json.dumps(fixture), encoding="utf-8")
print(file)
