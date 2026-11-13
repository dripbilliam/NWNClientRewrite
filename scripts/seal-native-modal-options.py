"""Seal exact90 accepted inputs and the three reviewed Options modal diffs."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
r = json.loads((PROJECT / 'reports/native-modal-options-v1-receipt.json').read_text(encoding='utf-8-sig'))
assert r['success'] and len(r['results']) == 3 and r['protocolTests'] == 22
assert sum(x['checks'] for x in r['results']) == 68
assert all(x['success'] and x['cleanEngine'] and x['exitCode'] == 0 and not x['timedOut'] for x in r['results'])
run = Path(r['directory']).resolve()
assert run.is_relative_to(PROJECT / '.cache/modal-options-tests')
before = PROJECT / '.cache/modal-options-tests/20261103-023941-before'
owned = ['systems/native_video_options.gd', 'systems/native_key_settings.gd', 'systems/native_main_menu.gd']
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
    if row['path'] in owned:
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
    add('dirty-before/godot-client/' + relative, old)
    changes.append({'path': 'godot-client/' + relative, 'beforeSha256': sha(old), 'acceptedSha256': sha(new)})
    patch.extend(difflib.unified_diff(old.decode().splitlines(True), new.decode().splitlines(True),
                                    fromfile='dirty-before/' + relative, tofile='accepted90/' + relative))
add('options-modal-only.patch', ''.join(patch).encode())
add('dirty-before/before.json', (before / 'before.json').read_bytes())
for relative in ['godot-client/NATIVE-MODAL-OPTIONS.md', 'godot-client/NATIVE-MODAL-OWNERS.md',
                 'godot-client/reports/native-options-modal-boundaries-v1.json',
                 'scripts/record-native-options-modal-boundaries.py']:
    add('evidence/' + relative, (ROOT / relative).read_bytes())
add('sealer.py', Path(__file__).read_bytes())
manifest = {
    'scope': 'Exact90 source snapshot and three reviewed Video/Key modal diffs; no complete original modal membership, global53/2, original pixels, server or live user-client acceptance.',
    'nativeChecks': 68, 'protocolChecks': 22, 'sharedChanges': changes,
    'currentUnrelatedDifferences': differences,
    'previous713ArchiveSha256': 'cd55edb59d334bce025b639e13931f9a6abb16cabd5dcdd0b65205681e5dd68b',
    'entries': [{'path': n, 'bytes': len(d), 'sha256': sha(d)} for n, d in sorted(entries.items())],
}
add('manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
destination = PROJECT / '.cache/modal-options-checkpoints' / (stamp + '-sealed90')
destination.mkdir(parents=True, exist_ok=False)
archive = destination / 'native-modal-options-v1.zip'
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name, data in sorted(entries.items()):
        z.writestr(name, data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and len(z.infolist()) == len(entries)
    for name, data in entries.items():
        assert sha(z.read(name)) == sha(data)
(destination / 'manifest.json').write_bytes(entries['manifest.json'])
result = {'success': True, 'archive': str(archive.relative_to(ROOT)), 'sha256': sha(archive.read_bytes()),
          'bytes': archive.stat().st_size, 'entries': len(entries), 'checks': 90,
          'currentUnrelatedDifferences': differences, 'sharedChanges': changes}
(destination / 'checkpoint.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
