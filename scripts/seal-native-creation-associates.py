"""Seal the staged associate data/layout slice; never accept an unbound UI."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
ARCHIVE = PROJECT / 'backups/native-creation-associates-v1.zip'
RECEIPT = PROJECT / 'reports/native-creation-associates-checkpoint-v1.json'
CASES = {'native-creation-associate-state-v2': 563,
         'native-creation-associate-resources-v2': 4}
sha = lambda data: hashlib.sha256(data).hexdigest()
assert not ARCHIVE.exists() and not RECEIPT.exists(), 'Preserve existing checkpoints'
files, cases = {}, []


def add(name, data):
    assert not Path(name).is_absolute() and '..' not in Path(name).parts
    if name in files:
        assert files[name] == data
    files[name] = data


for name, expected in CASES.items():
    path = PROJECT / 'reports' / (name + '-receipt.json')
    value = json.loads(path.read_text(encoding='utf-8-sig'))
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
        data = (run / 'project' / relative).read_bytes()
        assert sha(data) == row['sha256']
        assert sha((PROJECT / relative).read_bytes()) == row['sha256'], row['path']
        add('accepted-inputs/' + relative.as_posix(), data)
    add('accepted/' + name + '/receipt.json', path.read_bytes())
    for child in run.iterdir():
        if child.is_file():
            add('accepted/' + name + '/' + child.name, child.read_bytes())
    for extra in ['project.godot', 'oracle.json']:
        child = run / 'project' / extra
        if child.is_file():
            add('accepted/' + name + '/project/' + extra, child.read_bytes())
    cases.append({'name': name, 'checks': expected, 'scope': value['scope'],
                  'receiptSha256': sha(path.read_bytes())})

for name in ['native-creation-associate-original-v1.json', 'native-creation-associate-static-v1.json']:
    add('original-evidence/' + name, (PROJECT / 'reports' / name).read_bytes())
for name in ['inspect-native-creation-associate.py', 'inspect-native-intratile-coordinator.py',
             'seal-native-creation-associates.py']:
    add('research-scripts/' + name, (ROOT / 'scripts' / name).read_bytes())
for name in ['NATIVE-CREATION-ASSOCIATES.md', 'NATIVE-UI-RESOURCE-INVENTORY.md']:
    add('documentation/' + name, (PROJECT / name).read_bytes())
for name in ['run-native-creation-associate-state-tests.ps1', 'run-native-creation-associate-resources-tests.ps1']:
    add('runners/' + name, (PROJECT / 'tests' / name).read_bytes())

# Keep the initial metadata-label mistake and initial resource inventory as
# evidence, without upgrading them to accepted controls or controller behavior.
for name in ['native-creation-associate-state-v1', 'native-creation-associate-resources-v1']:
    value = json.loads((PROJECT / 'reports' / (name + '-receipt.json')).read_text(encoding='utf-8-sig'))
    run = Path(value['directory'])
    for child in run.iterdir():
        if child.is_file():
            add('preserved-earlier/' + name + '/' + child.name, child.read_bytes())

scope = ('Staged native associate physical-row/selection policy and installed layout only. '
         'Actual source controls, active name generator, draft/UTC summary binding, '
         'BIC/server admission, pixels, full creator and level-up remain open.')
manifest = {'schema': 1, 'cases': cases, 'checks': sum(CASES.values()), 'scope': scope,
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
          'entries': len(files), 'cases': cases, 'checks': sum(CASES.values()), 'scope': scope}
RECEIPT.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in result.items() if key != 'cases'}, indent=2))
