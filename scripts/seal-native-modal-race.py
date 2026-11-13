"""Seal exact50 Race/Subrace inputs, dirty-before diffs and preserved repros."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
r = json.loads((PROJECT / 'reports/native-modal-race-subrace-v1-receipt.json').read_text(encoding='utf-8-sig'))
assert r['success'] and len(r['results']) == 1 and r['protocolTests'] == 22
assert r['results'][0]['checks'] == 28
assert all(x['success'] and x['cleanEngine'] and x['exitCode'] == 0 and not x['timedOut'] for x in r['results'])
run = Path(r['directory']).resolve()
assert run.is_relative_to(PROJECT / '.cache/modal-race-subrace-tests')
before_fix = PROJECT / '.cache/modal-race-subrace-tests/20261103-042321-before-fix'
before_factory = PROJECT / '.cache/modal-race-subrace-tests/20261103-044140-before-factory'
owned = {'systems/native_race_chooser.gd': before_fix, 'systems/native_creation.gd': before_factory}
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
    if row['path'] == 'systems/native_race_chooser.gd':
        assert current == row['sha256'], 'Owned chooser changed before seal'
    add('accepted-inputs/' + path.relative_to(ROOT).as_posix(), data)
for path in run.iterdir():
    if path.is_file():
        add('accepted-run/' + path.name, path.read_bytes())
add('accepted-run/project.godot', (run / 'project/project.godot').read_bytes())
changes = []
patch = []
for relative, before in owned.items():
    old = (before / Path(relative).name).read_bytes()
    new = (run / 'project' / relative).read_bytes()
    if relative == 'systems/native_creation.gd':
        inserted = ('\tsource_frontend.race.set_modal_owner(ui.modal_order,"other")\n'
                    '\tui.modal_surfaces.bind_layer(source_frontend.race,source_frontend)\n'
                    '\tsource_frontend.race.subrace.set_modal_owner(ui.modal_order,"other")\n'
                    '\tui.modal_surfaces.bind_layer(source_frontend.race.subrace,source_frontend)\n')
        assert new.decode().replace('\r\n', '\n').replace(inserted, '', 1) == old.decode().replace('\r\n', '\n'), 'Creator delta must be exactly four approved setup calls'
        assert inserted in (PROJECT / relative).read_text(), 'Approved current creator mappings are missing'
    add('dirty-before/godot-client/' + relative, old)
    add('dirty-before/' + Path(relative).stem + '-before.json', (before / 'before.json').read_bytes())
    changes.append({'path': 'godot-client/' + relative, 'beforeSha256': sha(old), 'acceptedSha256': sha(new)})
    patch.extend(difflib.unified_diff(old.decode().splitlines(True), new.decode().splitlines(True),
                                    fromfile='dirty-before/' + relative, tofile='accepted50/' + relative))
add('race-modal-only.patch', ''.join(patch).encode())
for relative in ['godot-client/NATIVE-MODAL-RACE.md', 'godot-client/NATIVE-MODAL-OWNERS.md',
                 'godot-client/reports/native-modal-activation-callers-v2.json',
                 'godot-client/reports/native-creation-race-research-v1.json',
                 'godot-client/reports/native-creation-race-research-v2.json']:
    add('evidence/' + relative, (ROOT / relative).read_bytes())
preserved = [('parse-rejection', '20261103-041043-9fb2ee3e'),
             ('clean-production-reproduction8of10', '20261103-041247-540cc120'),
             ('correction41', '20261103-042803-f7f796c1')]
for label, folder in preserved:
    previous = PROJECT / '.cache/modal-race-subrace-tests' / folder
    for path in previous.iterdir():
        if path.is_file():
            add('preserved-' + label + '/' + path.name, path.read_bytes())
    for relative in ['tests/native_modal_race_subrace_test.gd', 'tools/test-native-modal-race-subrace.ps1',
                     'systems/native_race_chooser.gd', 'systems/native_creation.gd']:
        add('preserved-' + label + '/project/' + relative, (previous / 'project' / relative).read_bytes())
add('sealer.py', Path(__file__).read_bytes())
manifest = {
    'scope': 'Exact50 accepted Race/Subrace creator-factory snapshot and two reviewed modal diffs. Installed geometry/input with authored model/commit and controlled rasters/fonts; no complete membership/global53/2, original pixels, server or live user-client acceptance.',
    'nativeChecks': 28, 'protocolChecks': 22, 'sharedChanges': changes,
    'currentUnrelatedDifferences': differences,
    'previousSkills61ArchiveSha256': 'fcd310fa862bc0e512bb752982ce1f1b5905084e788ad6751670922f62f72840',
    'entries': [{'path': n, 'bytes': len(d), 'sha256': sha(d)} for n, d in sorted(entries.items())],
}
add('manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
destination = PROJECT / '.cache/modal-race-checkpoints' / (stamp + '-sealed50')
destination.mkdir(parents=True, exist_ok=False)
archive = destination / 'native-modal-race-v1.zip'
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name, data in sorted(entries.items()):
        z.writestr(name, data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and len(z.infolist()) == len(entries)
    for name, data in entries.items():
        assert sha(z.read(name)) == sha(data)
(destination / 'manifest.json').write_bytes(entries['manifest.json'])
result = {'success': True, 'archive': str(archive.relative_to(ROOT)), 'sha256': sha(archive.read_bytes()),
          'bytes': archive.stat().st_size, 'entries': len(entries), 'checks': 50,
          'currentUnrelatedDifferences': differences, 'sharedChanges': changes}
(destination / 'checkpoint.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
