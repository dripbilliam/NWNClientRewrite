"""Seal exact tested inputs for the native creator's feat responsiveness repair.

No game assets, credentials, profiles or native binaries are included. Separate
policy and actual-control receipts retain their scopes; this is not full creator
or original-server acceptance.
"""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
cases = [
    ('policy', 'godot-client/.cache/creation-feat-context/feat-checkpoint-policy-v1', 1695),
    ('entry', 'godot-client/.cache/creation-class-flow/feat-checkpoint-entry-v1', 22),
]
target = root / 'backups/native-creation-feat-after-v1.zip'
output = root / 'godot-client/reports/native-creation-feat-v1-checkpoint.json'
if target.exists() or output.exists():
    raise RuntimeError('Existing checkpoint preserved')

def sha(data):
    return hashlib.sha256(data).hexdigest()

files = {}
proofs = {}
for label, folder, count in cases:
    directory = root / folder
    proof_bytes = (directory / 'proof.json').read_bytes()
    proof = json.loads(proof_bytes.decode('utf-8-sig'))
    assert proof['success'] and proof['cleanEngine'] and proof['checks'] == count
    assert proof['exitCode'] == 0 and proof['error'] is None
    assert not proof['failures'] and not proof['changedInputs']
    assert proof['serverConnections'] == proof['nativeBuilds'] == 0 and not proof['gpu']
    for row in proof['inputs']:
        path = Path(row['path'])
        assert not path.is_absolute() and '..' not in path.parts
        assert path.suffix in ['.gd', '.mjs', '.json', '.gdextension']
        data = (directory / 'inputs' / path).read_bytes()
        assert sha(data) == row['sha256'], row['path']
        files[label + '/tested-inputs/' + row['path']] = data
    for name in ['proof.json', 'result.json', 'engine.log', 'stdout.log', 'stderr.log']:
        files[label + '/receipts/' + name] = (directory / name).read_bytes()
    proofs[label] = {'sha256': sha(proof_bytes), 'checks': count, 'directory': folder}

entry = json.loads((root / cases[1][1] / 'proof.json').read_text(encoding='utf-8-sig'))
tested = {row['path']: row['sha256'] for row in entry['inputs']}
production = {}
for name in ['godot-client/systems/native_creation.gd',
             'godot-client/systems/native_data/creation_feat_context.gd',
             'godot-client/systems/native_data/creation_feat_state.gd',
             'godot-client/systems/native_data/creation_feat_choice_rules.gd',
             'godot-client/systems/native_data/creation_feat_requirements.gd']:
    data = (root / name).read_bytes()
    assert tested[name] == sha(data), name
    production[name] = sha(data)
for name in ['godot-client/NATIVE-CREATION-FEAT-RESPONSIVENESS.md',
             'scripts/seal-native-creation-feat-checkpoint.py']:
    files['documentation/' + name] = (root / name).read_bytes()
manifest = [{'path': name, 'sha256': sha(data), 'bytes': len(data)}
            for name, data in sorted(files.items())]
manifest_bytes = (json.dumps(manifest, indent=2) + '\n').encode()
files['manifest.json'] = manifest_bytes
with zipfile.ZipFile(target, 'x', zipfile.ZIP_LZMA) as archive:
    for name, data in sorted(files.items()):
        archive.writestr(name, data)
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    for name, data in files.items():
        assert sha(archive.read(name)) == sha(data)
receipt = dict(success=True, proofs=proofs, production=production,
               archive=str(target.relative_to(root)).replace('\\', '/'),
               archiveSha256=sha(target.read_bytes()), bytes=target.stat().st_size,
               entries=len(files), manifestSha256=sha(manifest_bytes),
               scope='Feat policy/original-oracle equality and actual native Skills-to-Feats publication/cache/Cancel controls. No GPU, server, full-creator, level-up or pixel claim.')
output.write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt))
