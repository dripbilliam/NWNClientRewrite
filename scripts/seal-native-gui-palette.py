"""Checkpoint the packed GUI palette implementation and exact accepted tests.

Only source, metadata and test receipts are archived. Installed game assets,
credentials and native libraries remain outside this checkpoint.
"""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
directory = root / 'godot-client/.cache/gui-packed-palette/gui-packed-palette-v1'
output = root / 'godot-client/reports/native-gui-palette-v1-checkpoint.json'
target = root / 'backups/native-gui-palette-after-v1.zip'
if output.exists() or target.exists():
    raise RuntimeError('Existing checkpoint preserved')

def sha(data):
    return hashlib.sha256(data).hexdigest()

proof = json.loads((directory / 'proof.json').read_text(encoding='utf-8-sig'))
assert proof['success'] and proof['checks'] == 74 and proof['cleanEngine']
assert proof['exitCode'] == 0 and proof['error'] is None
assert not proof['changedInputs'] and not proof['failures']
assert proof['serverConnections'] == proof['nativeBuilds'] == 0 and not proof['gpu']
files = {}
for row in proof['inputs']:
    data = (directory / 'inputs' / row['path']).read_bytes()
    assert sha(data) == row['sha256'], row['path']
    assert Path(row['path']).suffix in ['.gd', '.mjs', '.json', '.gdextension']
    files['tested-inputs/' + row['path']] = data

production = {}
for name in ['godot-client/systems/native_data/asset_service.gd',
             'godot-client/systems/native_data/gui_palette_texture.gd']:
    data = (root / name).read_bytes()
    assert next(row['sha256'] for row in proof['inputs'] if row['path'] == name) == sha(data)
    production[name] = sha(data)
for name in ['proof.json', 'result.json', 'engine.log', 'stdout.log', 'stderr.log']:
    files['receipts/' + name] = (directory / name).read_bytes()
for name in ['godot-client/NATIVE-GUI-PACKED-PALETTE.md', 'scripts/seal-native-gui-palette.py']:
    files['documentation/' + name] = (root / name).read_bytes()
manifest = [{'path': name, 'sha256': sha(data), 'bytes': len(data)} for name, data in sorted(files.items())]
manifest_bytes = (json.dumps(manifest, indent=2) + '\n').encode()
files['manifest.json'] = manifest_bytes
with zipfile.ZipFile(target, 'x', zipfile.ZIP_LZMA) as archive:
    for name, data in sorted(files.items()):
        archive.writestr(name, data)
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    for name, data in files.items():
        assert sha(archive.read(name)) == sha(data)
receipt = dict(success=True, checks=74, production=production,
               archive=str(target.relative_to(root)).replace('\\', '/'),
               archiveSha256=sha(target.read_bytes()), bytes=target.stat().st_size,
               entries=len(files), manifestSha256=sha(manifest_bytes),
               testedProofSha256=sha((directory / 'proof.json').read_bytes()),
               scope='Packed GUI selector byte equivalence, active palette provenance and actual asset-worker validation; no GPU/server/live-client claim.')
output.write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt))
