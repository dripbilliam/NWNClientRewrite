"""Seal exact46 parent/factory input checks and preserved pre-fix failures."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
r = json.loads((PROJECT / 'reports/native-modal-feat-parent-v1-receipt.json').read_text(encoding='utf-8-sig'))
assert r['success'] and len(r['results']) == 1 and r['results'][0]['checks'] == 24 and r['protocolTests'] == 22
assert all(x['success'] and x['cleanEngine'] and x['exitCode'] == 0 and not x['timedOut'] for x in r['results'])
run = Path(r['directory']).resolve()
assert run.is_relative_to(PROJECT / '.cache/modal-feat-parent-tests')
before = {
    'systems/native_feats_chooser.gd': PROJECT / '.cache/modal-feat-parent-tests/20261103-025708-before-fix/native_feats_chooser.gd',
    'systems/native_creation.gd': PROJECT / '.cache/modal-feat-parent-tests/20261103-030435-before-factory/native_creation.gd',
}
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
    if row['path'] in before:
        assert current == row['sha256'], 'Owned modal source changed before seal'
    add('accepted-inputs/' + path.relative_to(ROOT).as_posix(), data)
for path in run.iterdir():
    if path.is_file():
        add('accepted-run/' + path.name, path.read_bytes())
add('accepted-run/project.godot', (run / 'project/project.godot').read_bytes())
changes = []
patch = []
for relative, path in before.items():
    old = path.read_bytes()
    new = (run / 'project' / relative).read_bytes()
    add('dirty-before/godot-client/' + relative, old)
    changes.append({'path': 'godot-client/' + relative, 'beforeSha256': sha(old), 'acceptedSha256': sha(new)})
    patch.extend(difflib.unified_diff(old.decode().splitlines(True), new.decode().splitlines(True),
                                    fromfile='dirty-before/' + relative, tofile='accepted46/' + relative))
add('feat-parent-only.patch', ''.join(patch).encode())
for name in ['20261103-025357-29175ac1', '20261103-025512-bc52de73', '20261103-025941-eea07332']:
    folder = PROJECT / '.cache/modal-feat-parent-tests' / name
    for path in folder.iterdir():
        if path.is_file():
            add('preserved-reproduction/' + name + '/' + path.name, path.read_bytes())
    for relative in ['tests/native_modal_feat_parent_test.gd', 'tools/test-native-modal-feat-parent.ps1',
                     'systems/native_feats_chooser.gd', 'systems/native_creation.gd']:
        add('preserved-reproduction/' + name + '/project/' + relative, (folder / 'project' / relative).read_bytes())
for relative in ['godot-client/NATIVE-MODAL-FEAT-PARENT.md', 'godot-client/NATIVE-MODAL-OWNERS.md',
                 'godot-client/reports/native-modal-activation-callers-v2.json',
                 'godot-client/reports/native-gui-modal-rtti-v2.json']:
    add('evidence/' + relative, (ROOT / relative).read_bytes())
add('sealer.py', Path(__file__).read_bytes())
manifest = {
    'scope': 'Exact46 current parent/leaf/factory snapshot, separate input and request identity, two reviewed creator setup calls and preserved infrastructure/real defect rejection. No full draft-controller, original pixels, complete53/2 modal coverage or server acceptance.',
    'nativeChecks': 24, 'protocolChecks': 22, 'sharedChanges': changes,
    'currentUnrelatedDifferences': differences,
    'entries': [{'path': n, 'bytes': len(d), 'sha256': sha(d)} for n, d in sorted(entries.items())],
}
add('manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
destination = PROJECT / '.cache/modal-feat-parent-checkpoints' / (stamp + '-sealed46')
destination.mkdir(parents=True, exist_ok=False)
archive = destination / 'native-modal-feat-parent-v1.zip'
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name, data in sorted(entries.items()):
        z.writestr(name, data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and len(z.infolist()) == len(entries)
    for name, data in entries.items():
        assert sha(z.read(name)) == sha(data)
(destination / 'manifest.json').write_bytes(entries['manifest.json'])
result = {'success': True, 'archive': str(archive.relative_to(ROOT)), 'sha256': sha(archive.read_bytes()),
          'bytes': archive.stat().st_size, 'entries': len(entries), 'checks': 46,
          'currentUnrelatedDifferences': differences, 'sharedChanges': changes}
(destination / 'checkpoint.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
