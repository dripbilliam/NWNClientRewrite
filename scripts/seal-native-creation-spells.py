"""Seal exact scoped native spell policy/adapter/source-control evidence.

No installation, process, server, native output or existing archive is changed.
This checkpoint does not accept creator/controller/Recommended/server parity.
"""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
ARCHIVE = PROJECT / 'backups/native-creation-spells-v1.zip'
RECEIPT = PROJECT / 'reports/native-creation-spells-checkpoint-v1.json'
CASES = {
    'native-creation-spells-state-v5': 1939,
    'native-creation-spells-snapshot-v2': 18,
    'native-creation-spells-view-v7': 41,
    'native-creation-spells-resources-v2': 3,
}
sha = lambda data: hashlib.sha256(data).hexdigest()
assert not ARCHIVE.exists() and not RECEIPT.exists(), 'Preserve existing checkpoints'
files = {}
cases = []


def add(name, data):
    assert name not in files and not Path(name).is_absolute() and '..' not in Path(name).parts
    files[name] = data


for name, expected in CASES.items():
    receipt_path = PROJECT / 'reports' / (name + '-receipt.json')
    value = json.loads(receipt_path.read_text(encoding='utf-8-sig'))
    assert value['success'] and value['engineClean'] and value['exitCode'] == 0
    assert not value['timedOut'] and not value['changedInputs']
    assert value['result']['success'] and value['result']['checks'] == expected
    run = Path(value['directory']).resolve()
    assert run.is_relative_to((PROJECT / '.cache').resolve())
    log = (run / 'engine.log').read_text(encoding='utf-8-sig')
    assert not re.search(r'(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|Unicode parsing error|ObjectDB instances leaked|Leaked instance|still in use at exit', log)
    for row in value['inputs']:
        relative = Path(row['path'])
        assert not relative.is_absolute() and '..' not in relative.parts
        copied = run / 'project' / relative
        data = copied.read_bytes()
        assert sha(data) == row['sha256'], str(copied)
        assert sha((PROJECT / relative).read_bytes()) == row['sha256'], row['path']
        add('accepted/' + name + '/inputs/' + relative.as_posix(), data)
    for child in run.iterdir():
        if child.is_file():
            add('accepted/' + name + '/' + child.name, child.read_bytes())
    for extra in ['project.godot', 'oracle.json']:
        path = run / 'project' / extra
        if path.is_file():
            add('accepted/' + name + '/project/' + extra, path.read_bytes())
    cases.append({'name': name, 'checks': expected, 'scope': value['scope'],
                  'receiptSha256': sha(receipt_path.read_bytes())})

for name in ['native-creation-spell-selection-original-v1.json',
             'native-creation-spells-static-v1.json',
             'native-creation-spells-information-static-v1.json']:
    add('original-evidence/' + name, (PROJECT / 'reports' / name).read_bytes())
for name in ['inspect-native-creation-spell-selection.py',
             'inspect-native-intratile-coordinator.py',
             'seal-native-creation-spells.py']:
    add('research-scripts/' + name, (ROOT / 'scripts' / name).read_bytes())
for name in ['NATIVE-CREATION-SPELLS.md', 'NATIVE-UI-PARITY-GOAL.md',
             'NATIVE-UI-RESOURCE-INVENTORY.md']:
    add('documentation/' + name, (PROJECT / name).read_bytes())
for name in ['run-native-creation-spells-state-tests.ps1',
             'run-native-creation-spells-snapshot-tests.ps1',
             'run-native-creation-spells-resources-tests.ps1',
             'run-native-creation-spells-resources-v2-tests.ps1',
             'run-native-creation-spells-view-tests.ps1']:
    add('runners/' + name, (PROJECT / 'tests' / name).read_bytes())

# Preserve rejected parse/conditional/helper fixtures and earlier slower input
# cases; never overwrite or relabel their receipts as current acceptance.
for group in ['spells-state-tests', 'spells-resources-tests', 'spells-view-tests']:
    for run in sorted((PROJECT / '.cache' / group).iterdir()):
        if not run.is_dir() or not (run / 'receipt.json').exists():
            continue
        value = json.loads((run / 'receipt.json').read_text(encoding='utf-8-sig'))
        if value['directory'] in [json.loads((PROJECT / 'reports' / (n + '-receipt.json')).read_text(encoding='utf-8-sig'))['directory'] for n in CASES]:
            continue
        prefix = 'preserved-earlier/' + group + '/' + run.name + '/'
        for path in run.iterdir():
            if path.is_file():
                add(prefix + path.name, path.read_bytes())
        for path in (run / 'project' / 'systems').rglob('*spells*.gd'):
            add(prefix + path.relative_to(run / 'project').as_posix(), path.read_bytes())
        for path in (run / 'project' / 'systems').glob('native_spell_information.gd'):
            add(prefix + path.relative_to(run / 'project').as_posix(), path.read_bytes())
        for path in (run / 'project' / 'tests').glob('native_creation_spells*.gd'):
            add(prefix + path.relative_to(run / 'project').as_posix(), path.read_bytes())

manifest = {'schema': 1, 'cases': cases, 'checks': sum(CASES.values()),
            'scope': 'Exact accepted native spell policy/adapter/installed controls, with original evidence and preserved rejected/slower snapshots. No actual creator controller/Recommended/level-up/server upload/original pixel or live-client acceptance.',
            'entries': [{'path': name, 'sha256': sha(data), 'bytes': len(data)}
                        for name, data in sorted(files.items())]}
add('manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(ARCHIVE, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for name, data in sorted(files.items()):
        archive.writestr(name, data)
with zipfile.ZipFile(ARCHIVE) as archive:
    assert archive.testzip() is None and len(archive.infolist()) == len(files)
    for name, data in files.items():
        assert sha(archive.read(name)) == sha(data), name
result = {'success': True, 'archive': str(ARCHIVE.relative_to(ROOT)),
          'sha256': sha(ARCHIVE.read_bytes()), 'bytes': ARCHIVE.stat().st_size,
          'entries': len(files), 'cases': cases, 'checks': sum(CASES.values()),
          'scope': manifest['scope']}
RECEIPT.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
