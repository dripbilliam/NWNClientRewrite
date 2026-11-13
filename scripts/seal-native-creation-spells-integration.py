"""Seal the exact tested first-level source spell integration, without binaries.

Never overwrite a checkpoint or interpret this scoped acceptance as full parity.
"""
from pathlib import Path
import difflib
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot-client'
ARCHIVE = PROJECT / 'backups/native-creation-spells-integration-v2.zip'
RECEIPT = PROJECT / 'reports/native-creation-spells-integration-checkpoint-v2.json'
CASES = {
    'native-creation-spells-state-v5': 1939,
    'native-creation-spells-snapshot-v3': 18,
    'native-creation-spells-resources-v2': 3,
    'native-creation-spells-view-v8': 41,
    'native-creation-spell-preferences-v4': 1449,
    'native-creation-spell-recommendations-v1': 20,
    'native-creation-spell-selection-v1': 22,
    'native-creation-spells-binding-v3': 47,
    'native-creation-spells-spontaneous-v1': 15,
    'native-creation-school-binding-post-spells-v2': 25,
}
sha = lambda data: hashlib.sha256(data).hexdigest()
assert not ARCHIVE.exists() and not RECEIPT.exists(), 'Preserve existing checkpoints'
files, cases = {}, []


def add(name, data):
    assert not Path(name).is_absolute() and '..' not in Path(name).parts
    if name in files:
        assert files[name] == data, 'Conflicting source snapshots: ' + name
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

before = PROJECT / '.cache/spells-integration-checkpoints/20261103-034934-before'
rows = json.loads((before / 'manifest.json').read_text(encoding='utf-8-sig'))
add('dirty-before/manifest.json', (before / 'manifest.json').read_bytes())
ownership = []
for row in rows:
    relative = row['path']
    original = (before / relative).read_bytes()
    assert sha(original) == row['sha256']
    after = (PROJECT / relative).read_bytes()
    add('dirty-before/' + relative, original)
    add('integrated/' + relative, after)
    prior_text = original.decode('utf-8-sig')
    current_text = after.decode('utf-8-sig')
    # Race/Subrace's four factory mappings belong to the other agent. Keep
    # their real integrated bytes but exclude their added lines from our diff.
    other_lines = []
    if relative == 'systems/native_creation.gd':
        lines = current_text.splitlines(keepends=True)
        for line in lines:
            if ('source_frontend.race' in line and
                ('set_modal_owner(' in line or 'bind_layer(' in line) and
                line not in prior_text):
                other_lines.append(line)
        current_text = ''.join(line for line in lines if line not in other_lines)
    ownership.append({'path': relative, 'dirtyBeforeSha256': sha(original),
                      'integratedSha256': sha(after),
                      'preservedOtherAgentAddedLines': other_lines})
    delta = ''.join(difflib.unified_diff(prior_text.splitlines(True), current_text.splitlines(True),
                    fromfile='dirty-before/' + relative, tofile='root-spells-owned/' + relative))
    add('root-owned-diffs/' + relative + '.patch', delta.encode())
add('ownership.json', (json.dumps(ownership, indent=2) + '\n').encode())

for name in ['native-creation-spell-selection-original-v1.json',
             'native-creation-spell-recommendations-original-v1.json',
             'native-creation-spells-static-v1.json',
             'native-creation-spells-information-static-v1.json',
             'native-creation-spells-save-static-v1.json']:
    add('original-evidence/' + name, (PROJECT / 'reports' / name).read_bytes())
for name in ['inspect-native-creation-spell-selection.py',
             'inspect-native-creation-spell-recommendations.py',
             'seal-native-creation-spells-integration.py']:
    add('research-scripts/' + name, (ROOT / 'scripts' / name).read_bytes())
for name in ['NATIVE-CREATION-SPELLS.md', 'NATIVE-UI-PARITY-GOAL.md',
             'NATIVE-UI-RESOURCE-INVENTORY.md']:
    add('documentation/' + name, (PROJECT / name).read_bytes())
for path in (PROJECT / 'tests').glob('run-native-creation-spell*-tests.ps1'):
    add('runners/' + path.name, path.read_bytes())

# Preserve rejected/earlier receipts and fixtures, without accepting them or
# bundling the installation, cache binaries, credentials or user documents.
accepted_dirs = {json.loads((PROJECT / 'reports' / (n + '-receipt.json')).read_text(encoding='utf-8-sig'))['directory'] for n in CASES}
for group in ['spells-binding-tests', 'spell-preferences-tests', 'spells-view-tests']:
    for run in sorted((PROJECT / '.cache' / group).iterdir()):
        if not run.is_dir() or not (run / 'receipt.json').is_file():
            continue
        value = json.loads((run / 'receipt.json').read_text(encoding='utf-8-sig'))
        if value['directory'] in accepted_dirs:
            continue
        prefix = 'preserved-earlier/' + group + '/' + run.name + '/'
        for name in ['receipt.json', 'engine.log', 'stdout.log', 'stderr.log', 'result.json']:
            path = run / name
            if path.is_file():
                add(prefix + name, path.read_bytes())
        for path in (run / 'project' / 'tests').glob('native_creation_spell*.gd'):
            add(prefix + path.relative_to(run / 'project').as_posix(), path.read_bytes())

manifest = {'schema': 1, 'cases': cases, 'checks': sum(CASES.values()),
            'uniqueFeatureCount': False,
            'scope': 'Exact scoped first-level source spell policy, active rules, Recommended, controller, physical controls and real memorizing/non-memorizing BIC workers. Full source creator, level-up, authoritative server admission/upload, original pixels and live-client validation remain open.',
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
print(json.dumps({key: value for key, value in result.items() if key != 'cases'}, indent=2))
