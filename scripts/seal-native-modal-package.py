"""Seal exact66 accepted inputs and the two reviewed Package modal diffs."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
r = json.loads((PROJECT / 'reports/native-modal-package-v1-receipt.json').read_text(encoding='utf-8-sig'))
assert r['success'] and len(r['results']) == 2 and r['protocolTests'] == 22
assert sum(x['checks'] for x in r['results']) == 44
assert all(x['success'] and x['cleanEngine'] and x['exitCode'] == 0 and not x['timedOut'] for x in r['results'])
run = Path(r['directory']).resolve()
assert run.is_relative_to(PROJECT / '.cache/modal-package-tests')
before = PROJECT / '.cache/modal-package-tests/20261103-031200-before'
owned = ['systems/native_package_chooser.gd', 'systems/native_creation.gd']
sha = lambda data: hashlib.sha256(data).hexdigest()
entries = {}
differences = []


def add(name, data):
    assert name not in entries and not Path(name).is_absolute() and '..' not in Path(name).parts
    entries[name] = data


for row in r['inputs']:
    path = (PROJECT / row['path']).resolve()
    copied = (run / 'project' / row['path']).resolve()
    assert path.is_relative_to(ROOT) and copied.is_relative_to(run)
    data = copied.read_bytes()
    assert sha(data) == row['sha256'], row['path']
    current = sha(path.read_bytes())
    if current != row['sha256']:
        differences.append({'path': row['path'], 'acceptedSha256': row['sha256'], 'currentSha256': current})
    if row['path'] == 'systems/native_package_chooser.gd':
        assert current == row['sha256'], 'Owned modal source changed before seal'
    add('accepted-inputs/' + path.relative_to(ROOT).as_posix(), data)
for path in run.iterdir():
    if path.is_file():
        add('accepted-run/' + path.name, path.read_bytes())
add('accepted-run/project.godot', (run / 'project/project.godot').read_bytes())
changes = []
patch = []
for relative in owned:
    old = (before / Path(relative).name).read_bytes()
    new = (run / 'project' / relative).read_bytes()
    if relative == 'systems/native_creation.gd':
        inserted = '\tsource_frontend.packages.set_modal_owner(ui.modal_order,\"other\")\n\tui.modal_surfaces.bind_layer(source_frontend.packages,source_frontend)\n'
        assert new.decode().replace('\r\n', '\n').replace(inserted, '', 1) == old.decode().replace('\r\n', '\n'), 'Creator delta must be exactly the two approved setup calls'
    add('dirty-before/godot-client/' + relative, old)
    changes.append({'path': 'godot-client/' + relative, 'beforeSha256': sha(old), 'acceptedSha256': sha(new)})
    patch.extend(difflib.unified_diff(old.decode().splitlines(True), new.decode().splitlines(True),
                                    fromfile='dirty-before/' + relative, tofile='accepted66/' + relative))
add('package-modal-only.patch', ''.join(patch).encode())
add('dirty-before/before.json', (before / 'before.json').read_bytes())
for relative in ['godot-client/NATIVE-MODAL-PACKAGE.md', 'godot-client/NATIVE-MODAL-OWNERS.md',
                 'godot-client/reports/native-creation-modal-paths-v1.json',
                 'scripts/record-native-creation-modal-paths.py']:
    add('evidence/' + relative, (ROOT / relative).read_bytes())
add('sealer.py', Path(__file__).read_bytes())
manifest = {
    'scope': 'Exact66 source snapshot and two reviewed Package modal diffs; no complete original modal membership, global53/2, original pixels, server or live user-client acceptance.',
    'nativeChecks': 44, 'protocolChecks': 22, 'sharedChanges': changes,
    'currentUnrelatedDifferences': differences,
    'previousFeats46ArchiveSha256': 'be4f7c0394d468fd932edb7c681ce9f54b3ab340e1c68066fcb73bd5a882a1bb',
    'entries': [{'path': n, 'bytes': len(d), 'sha256': sha(d)} for n, d in sorted(entries.items())],
}
add('manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
destination = PROJECT / '.cache/modal-package-checkpoints' / (stamp + '-sealed66')
destination.mkdir(parents=True, exist_ok=False)
archive = destination / 'native-modal-package-v1.zip'
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name, data in sorted(entries.items()):
        z.writestr(name, data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and len(z.infolist()) == len(entries)
    for name, data in entries.items():
        assert sha(z.read(name)) == sha(data)
(destination / 'manifest.json').write_bytes(entries['manifest.json'])
result = {'success': True, 'archive': str(archive.relative_to(ROOT)), 'sha256': sha(archive.read_bytes()),
          'bytes': archive.stat().st_size, 'entries': len(entries), 'checks': 66,
          'currentUnrelatedDifferences': differences, 'sharedChanges': changes}
(destination / 'checkpoint.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
