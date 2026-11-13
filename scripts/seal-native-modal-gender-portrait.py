"""Seal exact98 source-owned Gender/Portrait checks and retained failures."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
r = json.loads((PROJECT / 'reports/native-modal-gender-portrait-v1-receipt.json').read_text(encoding='utf-8-sig'))
assert r['success'] and [x['checks'] for x in r['results']] == [44, 32] and r['protocolTests'] == 22
assert not r['changedInputs'] and not r['changedCopiedInputs']
assert all(x['success'] and x['cleanEngine'] and x['exitCode'] == 0 and not x['timedOut'] for x in r['results'])
run = Path(r['directory']).resolve()
assert run.is_relative_to(PROJECT / '.cache/modal-gender-portrait-tests')
before = PROJECT / '.cache/modal-gender-portrait-tests/20261103-060611-before'
scroll_before = PROJECT / '.cache/modal-gender-portrait-tests/20261103-062415-before-scroll-fix'
owned = ['systems/native_gender_chooser.gd', 'systems/native_portrait_chooser.gd', 'systems/native_creation.gd']
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
        assert current == row['sha256'], 'Owned source changed before seal'
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
        inserted = ('\tsource_frontend.gender.set_modal_owner(ui.modal_order,"other")\n'
                    '\tui.modal_surfaces.bind_layer(source_frontend.gender,source_frontend)\n'
                    '\tsource_frontend.portrait.set_modal_owner(ui.modal_order,"other")\n'
                    '\tui.modal_surfaces.bind_layer(source_frontend.portrait,source_frontend)\n')
        assert new.decode().replace('\r\n', '\n').replace(inserted, '', 1) == old.decode().replace('\r\n', '\n')
    add('dirty-before/godot-client/' + relative, old)
    changes.append({'path': 'godot-client/' + relative, 'beforeSha256': sha(old), 'acceptedSha256': sha(new)})
    patch.extend(difflib.unified_diff(old.decode().splitlines(True), new.decode().splitlines(True),
                                    fromfile='dirty-before/' + relative, tofile='accepted98/' + relative))
add('gender-portrait-only.patch', ''.join(patch).encode())
add('dirty-before/before.json', (before / 'before.json').read_bytes())
for name in ['native_portrait_chooser.gd', 'before.json']:
    add('before-approved-scroll-correction/' + name, (scroll_before / name).read_bytes())
for relative in ['godot-client/NATIVE-MODAL-GENDER-PORTRAIT.md', 'godot-client/NATIVE-MODAL-CLASS-ALIGNMENT.md',
                 'godot-client/tools/diagnose-native-modal-gender-portrait.ps1']:
    add('evidence/' + relative, (ROOT / relative).read_bytes())
rejected = PROJECT / '.cache/modal-gender-portrait-tests/20261103-061457-153802ae'
for path in rejected.iterdir():
    if path.is_file():
        add('preserved-rejection/' + path.name, path.read_bytes())
add('preserved-rejection/native_modal_gender_portrait_test.gd',
    (rejected / 'project/tests/native_modal_gender_portrait_test.gd').read_bytes())
for directory in ['20261103-061847-5af6a272', '20261103-061927-6dafeb0f']:
    source = PROJECT / '.cache/modal-gender-portrait-diagnostics' / directory
    for path in source.iterdir():
        if path.is_file():
            add('preserved-diagnostics/' + directory + '/' + path.name, path.read_bytes())
    add('preserved-diagnostics/' + directory + '/native_modal_gender_portrait_test.gd',
        (source / 'project/tests/native_modal_gender_portrait_test.gd').read_bytes())
add('sealer.py', Path(__file__).read_bytes())
manifest = {'scope': 'Exact98: actual installed Gender/Portrait creation factory/input/lifetimes and row-scroll correction, Class32 and protocol22 regressions. Authored choices/commits and controlled raster/fonts; no complete creator/level-up/server/original pixels or global coverage acceptance.',
            'nativeChecks': 76, 'protocolChecks': 22, 'sharedChanges': changes,
            'currentUnrelatedDifferences': differences,
            'entries': [{'path': name, 'bytes': len(data), 'sha256': sha(data)} for name, data in sorted(entries.items())]}
add('manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
destination = PROJECT / '.cache/modal-gender-portrait-checkpoints' / (stamp + '-sealed98')
destination.mkdir(parents=True, exist_ok=False)
archive = destination / 'native-modal-gender-portrait-v1.zip'
with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name, data in sorted(entries.items()):
        z.writestr(name, data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and len(z.infolist()) == len(entries)
    for name, data in entries.items():
        assert sha(z.read(name)) == sha(data)
(destination / 'manifest.json').write_bytes(entries['manifest.json'])
result = {'success': True, 'archive': str(archive.relative_to(ROOT)), 'sha256': sha(archive.read_bytes()),
          'bytes': archive.stat().st_size, 'entries': len(entries), 'checks': 98,
          'inputs': len(r['inputs']), 'currentUnrelatedDifferences': differences, 'sharedChanges': changes}
(destination / 'checkpoint.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
