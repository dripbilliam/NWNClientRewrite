"""Seal tested native name generation and resource-index changes, not the UI."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import zipfile
ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
ARCHIVE = PROJECT / 'backups/native-name-generation-v1.zip'
RECEIPT = PROJECT / 'reports/native-name-generation-checkpoint-v1.json'
CASES = {'native-name-generation-v2': 188, 'native-associate-names-v4': 27,
         'native-resource-extensions-v1': 380}
sha = lambda data: hashlib.sha256(data).hexdigest()
assert not ARCHIVE.exists() and not RECEIPT.exists(), 'Preserve existing checkpoints'
files, cases, accepted_dirs = {}, [], set()


def add(name, data):
    assert not Path(name).is_absolute() and '..' not in Path(name).parts
    if name in files: assert files[name] == data
    files[name] = data


for name, expected in CASES.items():
    path = PROJECT / 'reports' / (name + '-receipt.json')
    value = json.loads(path.read_text(encoding='utf-8-sig'))
    assert value['success'] and value['engineClean'] and value['exitCode'] == 0
    assert not value['timedOut'] and not value['changedInputs']
    assert value['result']['success'] and value['result']['checks'] == expected
    run = Path(value['directory']).resolve(); accepted_dirs.add(run)
    assert run.is_relative_to((PROJECT / '.cache').resolve())
    log = (run / 'engine.log').read_text(encoding='utf-8-sig')
    assert not re.search(r'(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|Unicode parsing error|ObjectDB instances leaked|Leaked instance|still in use at exit', log)
    for row in value['inputs']:
        relative = Path(row['path']); assert not relative.is_absolute() and '..' not in relative.parts
        data = (run / 'project' / relative).read_bytes()
        assert sha(data) == row['sha256']
        assert sha((PROJECT / relative).read_bytes()) == row['sha256'], row['path']
        add('accepted-inputs/' + relative.as_posix(), data)
    for child in run.iterdir():
        if child.is_file():add('accepted/' + name + '/' + child.name, child.read_bytes())
    for extra in ['project.godot', 'oracle.json']:
        child = run / 'project' / extra
        if child.is_file():add('accepted/' + name + '/project/' + extra, child.read_bytes())
    cases.append({'name': name, 'checks': expected, 'scope': value['scope'], 'receiptSha256': sha(path.read_bytes())})

before = PROJECT / '.cache/name-service-checkpoints/20261103-053600-before'
for manifest_name in ['manifest.json', 'loose-index-manifest.json']:
    path = before / manifest_name; row = json.loads(path.read_text(encoding='utf-8-sig'))
    data = (before / Path(row['path']).name).read_bytes(); assert sha(data) == row['sha256']
    current = (PROJECT / row['path']).read_bytes()
    add('dirty-before/' + row['path'], data);add('dirty-before/' + manifest_name, path.read_bytes())
    delta = ''.join(difflib.unified_diff(data.decode('utf-8-sig').splitlines(True), current.decode('utf-8-sig').splitlines(True), fromfile='dirty-before/' + row['path'], tofile='integrated/' + row['path']))
    add('owned-diffs/' + row['path'] + '.patch', delta.encode())

for name in ['native-name-generation-original-v1.json', 'native-resource-extensions-original-v1.json',
             'native-creation-associate-namegen-static-v1.json', 'native-resource-extensions-static-v1.json',
             'native-resource-extensions-inspector-rejected-v1.py']:
    add('original-evidence/' + name, (PROJECT / 'reports' / name).read_bytes())
for name in ['inspect-native-name-generation.py', 'inspect-native-resource-extensions.py',
             'inspect-native-intratile-coordinator.py', 'seal-native-name-generation.py']:
    add('research-scripts/' + name, (ROOT / 'scripts' / name).read_bytes())
for name in ['NATIVE-NAME-GENERATION.md', 'NATIVE-UI-RESOURCE-INVENTORY.md']:
    add('documentation/' + name, (PROJECT / name).read_bytes())
for name in ['run-native-name-generation-tests.ps1', 'run-native-associate-names-tests.ps1', 'run-native-resource-extensions-tests.ps1']:
    add('runners/' + name, (PROJECT / 'tests' / name).read_bytes())
for group in ['name-generation-tests', 'associate-names-tests']:
    for run in sorted((PROJECT / '.cache' / group).iterdir()):
        if not run.is_dir() or run.resolve() in accepted_dirs or not (run / 'receipt.json').is_file():continue
        for name in ['receipt.json', 'engine.log', 'stdout.log', 'stderr.log', 'result.json']:
            path = run / name
            if path.is_file():add('preserved-earlier/' + group + '/' + run.name + '/' + name, path.read_bytes())
        for path in (run / 'project' / 'tests').glob('native*name*.gd'):
            add('preserved-earlier/' + group + '/' + run.name + '/' + path.relative_to(run / 'project').as_posix(), path.read_bytes())

scope = ('Native LTR parser/generator, actual asynchronous asset/cache/scoped-name owner and complete original resource-extension mapping with real loose payload reads. '
         'Name service/creation Control binding, full creator/level-up, authoritative admission and original pixels remain open; no live-client/GPU/server acceptance.')
manifest = {'schema': 1, 'checks': sum(CASES.values()), 'cases': cases, 'scope': scope,
            'entries': [{'path': name, 'sha256': sha(data), 'bytes': len(data)} for name, data in sorted(files.items())]}
add('manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(ARCHIVE, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for name, data in sorted(files.items()):archive.writestr(name, data)
with zipfile.ZipFile(ARCHIVE) as archive:
    assert archive.testzip() is None and len(archive.infolist()) == len(files)
    for name, data in files.items():assert sha(archive.read(name)) == sha(data), name
result = {'success': True, 'archive': str(ARCHIVE.relative_to(ROOT)), 'sha256': sha(ARCHIVE.read_bytes()),
          'entries': len(files), 'bytes': ARCHIVE.stat().st_size, 'checks': sum(CASES.values()), 'cases': cases, 'scope': scope}
RECEIPT.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: v for k, v in result.items() if k != 'cases'}, indent=2))
