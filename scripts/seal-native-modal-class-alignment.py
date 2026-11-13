"""Seal exact82 Class/Alignment snapshot and three narrow modal diffs."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
r = json.loads((PROJECT / 'reports/native-modal-class-alignment-v1-receipt.json').read_text(encoding='utf-8-sig'))
assert r['success'] and len(r['results']) == 2 and r['protocolTests'] == 22
assert [row['checks'] for row in r['results']] == [32, 28]
assert all(row['success'] and row['cleanEngine'] and row['exitCode'] == 0 and not row['timedOut'] for row in r['results'])
run = Path(r['directory']).resolve()
assert run.is_relative_to(PROJECT / '.cache/modal-class-alignment-tests')
before = PROJECT / '.cache/modal-class-alignment-tests/20261103-050050-before'
owned = ['systems/native_class_chooser.gd', 'systems/native_alignment_chooser.gd', 'systems/native_creation.gd']
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
    normalized = new.decode().replace('\r\n', '\n')
    if relative == 'systems/native_creation.gd':
        inserted = ('\tsource_frontend.class_chooser.set_modal_owner(ui.modal_order,"other")\n'
                    '\tui.modal_surfaces.bind_layer(source_frontend.class_chooser,source_frontend)\n'
                    '\tsource_frontend.alignment.set_modal_owner(ui.modal_order,"other")\n'
                    '\tui.modal_surfaces.bind_layer(source_frontend.alignment,source_frontend)\n')
        normalized = normalized.replace(inserted, '', 1)
    else:
        normalized = normalized.replace('\tvar replaced_scope:=scope!=value_scope\n\tif replaced_scope:retire_modal_owner()\n', '', 1)
        normalized = normalized.replace('\tif replaced_scope:register_modal_owner()\n', '', 1)
    assert normalized == old.decode().replace('\r\n', '\n'), 'Delta exceeds exact reviewed scope: ' + relative
    add('dirty-before/godot-client/' + relative, old)
    changes.append({'path': 'godot-client/' + relative, 'beforeSha256': sha(old), 'acceptedSha256': sha(new)})
    patch.extend(difflib.unified_diff(old.decode().splitlines(True), new.decode().splitlines(True),
                                    fromfile='dirty-before/' + relative, tofile='accepted82/' + relative))
add('class-alignment-modal-only.patch', ''.join(patch).encode())
add('dirty-before/before.json', (before / 'before.json').read_bytes())
for relative in ['godot-client/NATIVE-MODAL-CLASS-ALIGNMENT.md', 'godot-client/NATIVE-MODAL-OWNERS.md',
                 'godot-client/NATIVE-MODAL-RACE.md', 'godot-client/reports/native-modal-activation-callers-v2.json']:
    add('evidence/' + relative, (ROOT / relative).read_bytes())
add('sealer.py', Path(__file__).read_bytes())
manifest = {
    'scope': 'Exact82 accepted installed Class/Alignment creator factory input and scoped ownership snapshot with Race28 regression. Authored choices/commit and controlled presentation owners; no full draft/level-up, global53/2, original pixels, server or live user-client acceptance.',
    'nativeChecks': 60, 'protocolChecks': 22, 'sharedChanges': changes,
    'currentUnrelatedDifferences': differences,
    'previousRace50ArchiveSha256': 'fb0b0859025708503b62cb472befc03e0b7827217138635b34be61d88e2f1ef0',
    'entries': [{'path': name, 'bytes': len(data), 'sha256': sha(data)} for name, data in sorted(entries.items())],
}
add('manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
destination = PROJECT / '.cache/modal-class-alignment-checkpoints' / (stamp + '-sealed82')
destination.mkdir(parents=True, exist_ok=False)
archive = destination / 'native-modal-class-alignment-v1.zip'
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name, data in sorted(entries.items()):
        z.writestr(name, data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and len(z.infolist()) == len(entries)
    for name, data in entries.items():
        assert sha(z.read(name)) == sha(data)
(destination / 'manifest.json').write_bytes(entries['manifest.json'])
result = {'success': True, 'archive': str(archive.relative_to(ROOT)), 'sha256': sha(archive.read_bytes()),
          'bytes': archive.stat().st_size, 'entries': len(entries), 'checks': 82,
          'currentUnrelatedDifferences': differences, 'sharedChanges': changes}
(destination / 'checkpoint.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
