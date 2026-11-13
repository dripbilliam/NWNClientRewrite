"""Seal exact copied offline Warlock evidence; never reads keys/install/SQLite."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
project = root / 'godot-client'
archive = root / 'backups/native-cached-warlock-creation-after-v1.zip'
checkpoint = project / 'reports/native-cached-warlock-creation-v1-checkpoint.json'
assert not archive.exists() and not checkpoint.exists(), 'Preserve prior checkpoint'

def sha(value):
    return hashlib.sha256(value).hexdigest()

blobs, reads = {}, {}
def blob(file, expected=None):
    file = file.resolve()
    assert file.is_relative_to(root), str(file)
    assert file.suffix.lower() not in ['.dpapi', '.sqlite', '.sqlite3', '.db']
    if file not in reads:
        value = file.read_bytes()
        digest = sha(value)
        blobs.setdefault(digest, value)
        reads[file] = digest
    digest = reads[file]
    assert expected is None or digest == expected, str(file)
    return {'blob': 'blobs/' + digest, 'sha256': digest}

receipt_file = project / 'reports/native-cached-warlock-creation-v1-receipt.json'
receipt = json.loads(receipt_file.read_text(encoding='utf-8-sig'))
assert receipt['success'] and receipt['scopedAssertionSum'] == 2787
manifest = {'version': 1, 'scope': receipt['scope'], 'receipt': blob(receipt_file),
            'accepted': {}, 'preserved_rejections': {}, 'data': {}, 'documents': {},
            'limits': receipt['limits'], 'credentialsIncluded': False,
            'originalInstallIncluded': False, 'nativeBuilds': 0}

def case(directory, proof_name, accepted, expected_checks=None):
    proof_file = directory / proof_name
    proof = json.loads(proof_file.read_text(encoding='utf-8-sig'))
    assert proof['success'] == accepted
    if accepted:
        assert proof['cleanEngine'] and proof['exitCode'] == 0 and not proof['error']
        assert proof['checks'] == expected_checks
    for name in ['changedInputs', 'changedCopy', 'changedData', 'changedNative']:
        assert not proof.get(name, [])
    sources = {}
    for row in proof['inputs']:
        relative = Path(row['path'])
        assert not relative.is_absolute() and '..' not in relative.parts
        sources[row['path']] = blob(directory / 'inputs' / relative, row['sha256'])
    for row in proof.get('dataInputs', []):
        file = Path(row['file']).resolve()
        relative = file.relative_to(root).as_posix()
        assert relative.startswith('godot-client/.cache/cached-warlock-creation/')
        manifest['data'][relative] = blob(file, row['sha256'])
    evidence = {}
    for name in [proof_name, 'result.json', 'engine.log', 'stdout.log', 'stderr.log', 'result.json.bic']:
        file = directory / name
        if file.exists():
            evidence[name] = blob(file)
    return {'directory': directory.relative_to(root).as_posix(), 'success': accepted,
            'checks': proof['checks'], 'cleanEngine': proof['cleanEngine'],
            'sourceMap': sources, 'evidence': evidence}

for label, value in receipt['cases'].items():
    manifest['accepted'][label] = case(root / value['directory'], value['proof'], True, value['checks'])

rejected = [
    ('source-readiness', '.cache/cached-warlock-source/cached-warlock-source-v1'),
    ('source-diagnostic', '.cache/cached-warlock-source/cached-warlock-source-v2'),
    ('mapped-template-and-icons', '.cache/cached-warlock-complete/cached-warlock-complete-v1'),
    ('missing-voice-gate', '.cache/cached-warlock-complete/cached-warlock-complete-v2'),
    ('head-supermodel-gap', '.cache/cached-warlock-complete/cached-warlock-complete-v3'),
    ('next-supermodel-gap', '.cache/cached-warlock-complete/cached-warlock-complete-v4'),
    ('automatic-slot-gate', '.cache/cached-warlock-complete/cached-warlock-recommended-310-v1'),
    ('unpublished-preference-fixture', '.cache/cached-warlock-complete/cached-warlock-feat-comparison-v1'),
]
for label, directory in rejected:
    manifest['preserved_rejections'][label] = case(project / directory, 'runner.json', False)

owned = [
    'scripts/probe-cached-warlock-creation.mjs', 'scripts/prepare-cached-warlock-catalog.mjs',
    'scripts/extend-cached-warlock-fixture.mjs', 'scripts/record-cached-warlock-voice-gap.mjs',
    'scripts/record-cached-warlock-feat-finding.mjs', 'scripts/record-cached-warlock-creation.mjs',
    'scripts/seal-cached-warlock-creation.py',
    'godot-client/reports/native-cached-warlock-voice-initialization-original-v1.json',
    'godot-client/reports/native-cached-warlock-automatic-feats-finding-v1.json',
    'godot-client/reports/native-package-feat-recommendation-source-v1.json',
    'godot-client/reports/native-creation-voice-caption-original-v1.json',
    'godot-client/reports/native-package-integer-followup-v1.json',
]
for file in owned:
    manifest['documents'][file] = blob(root / file)
manifest['payloads'] = {digest: len(value) for digest, value in sorted(blobs.items())}
manifest_bytes = (json.dumps(manifest, indent=2) + '\n').encode()
archive.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED, compresslevel=6) as output:
    output.writestr('MANIFEST.json', manifest_bytes)
    for digest, value in sorted(blobs.items()):
        output.writestr('blobs/' + digest, value)
with zipfile.ZipFile(archive) as sealed:
    assert sealed.read('MANIFEST.json') == manifest_bytes
    assert len(sealed.namelist()) == len(blobs) + 1
    for digest in blobs:
        assert sha(sealed.read('blobs/' + digest)) == digest
result = {'success': True, 'archive': str(archive.relative_to(root)).replace('\\', '/'),
          'archiveSha256': sha(archive.read_bytes()), 'manifestSha256': sha(manifest_bytes),
          'entries': len(blobs) + 1, 'bytes': archive.stat().st_size,
          'acceptedScopes': len(manifest['accepted']), 'preservedRejections': len(rejected),
          'scopedAssertionSum': 2787, 'independentParsedBicArtifacts': 6,
          'networkConnections': 0, 'protectedProfilesRead': 0, 'userProcessActions': 0,
          'nativeBuilds': 0, 'gpu': False, 'readbackVerified': True}
checkpoint.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
