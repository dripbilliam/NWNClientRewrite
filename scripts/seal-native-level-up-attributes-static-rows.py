"""Seal immutable mode1 Attributes raster/input evidence without installed assets.

The before case is an expected rejection, never an accepted production run.
No credential files, installed fonts/textures, or native binaries are copied.
"""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
project = root / 'godot-client'
cases = {
    'after-raster38': project / '.cache/level-up-attributes-static-rows/levelup-static-rows-after-v1',
    'after-input45': project / '.cache/level-up-attributes-text-geometry/levelup-static-rows-input-v1',
    'before-expected25failures': project / '.cache/level-up-attributes-static-rows/levelup-static-rows-before-v1',
}
target = root / 'backups/native-level-up-attributes-static-rows-after-v1.zip'
output = project / 'reports/native-level-up-attributes-static-rows-v1-checkpoint.json'
if target.exists() or output.exists():
    raise RuntimeError('Existing checkpoint preserved')


def sha(data):
    return hashlib.sha256(data).hexdigest()


files = {}
summaries = {}
proofs = {}
for label, directory in cases.items():
    proof = json.loads((directory / 'proof.json').read_text(encoding='utf-8-sig'))
    result = json.loads((directory / 'result.json').read_text(encoding='utf-8-sig'))
    proofs[label] = proof
    assert proof['cleanEngine'] and not proof['changedInputs']
    assert not proof.get('changedNative', [])
    assert proof['error'] is None
    if label.startswith('after-'):
        assert proof['success'] and result['success'] and proof['exitCode'] == 0
        assert not proof['failures']
        assert proof['checks'] == (38 if label == 'after-raster38' else 45)
    else:
        assert proof['baselineSelected'] and not proof['success']
        assert proof['exitCode'] == 1 and proof['checks'] == 38
        assert len(proof['failures']) == 25
    for row in proof['inputs']:
        source = directory / 'inputs' / row['path']
        data = source.read_bytes()
        assert sha(data) == row['sha256'], str(source)
        assert source.suffix.lower() in ['.gd', '.mjs', '.js', '.cjs', '.json', '.gdextension'], str(source)
        files[f'{label}/inputs/{row["path"]}'] = data
    for name in ['proof.json', 'result.json', 'engine.log', 'stdout.log', 'stderr.log']:
        source = directory / name
        if source.exists():
            files[f'{label}/receipts/{name}'] = source.read_bytes()
    image = directory / 'result.json.normal.png'
    if image.exists():
        # Composite UI screenshots only; raw atlas/mesh/font textures stay private.
        files[f'{label}/attributes.png'] = image.read_bytes()
    summaries[label] = {
        'success': proof['success'], 'checks': proof['checks'],
        'failures': proof['failures'], 'exitCode': proof['exitCode'],
        'cleanEngine': proof['cleanEngine'], 'inputs': len(proof['inputs']),
        'sourceDirectory': str(directory.relative_to(root)).replace('\\', '/'),
        'proofSha256': sha((directory / 'proof.json').read_bytes()),
        'engineSha256': proof['engineSha256'],
    }

# Pin only the two owned production files to their current shipping bytes.
# The remaining closure is the exact immutable tested copy, not a later tree.
production = {}
for relative in ['godot-client/systems/native_level_up_attributes.gd',
                 'godot-client/systems/native_data/level_up_attributes_layout.gd']:
    current_hash = sha((root / relative).read_bytes())
    for label in ['after-raster38', 'after-input45']:
        rows = [row for row in proofs[label]['inputs'] if row['path'] == relative]
        assert len(rows) == 1 and rows[0]['sha256'] == current_hash, relative
    production[relative] = current_hash
assert production['godot-client/systems/native_level_up_attributes.gd'] == '4ae651d8ae93a8582f36afdcf6e0762102b6411453bd54535d314efcf2fe9303'

before_rows = [r for r in proofs['before-expected25failures']['inputs']
               if r['path'] == 'godot-client/systems/native_level_up_attributes.gd']
assert len(before_rows) == 1
assert before_rows[0]['sha256'] == '79c5e04d6c9a8414d5edfae86313e9c6761c9368ee75d3e7ee50d7ab6f714cbf'
assert before_rows[0]['sourcePath'] != before_rows[0]['path']

extras = [
    'godot-client/NATIVE-LEVEL-UP-ATTRIBUTES-PRESENTATION.md',
    'godot-client/NATIVE-CREATION-ATTRIBUTES.md',
    'godot-client/reports/native-level-up-attributes-label-owner-original-v1.json',
    'godot-client/reports/native-creator-control-semantics-audit-v1.json',
    'scripts/seal-native-level-up-attributes-static-rows.py',
]
for relative in extras:
    files[f'documentation/{relative}'] = (root / relative).read_bytes()

# Keep finite diagnostic failures and atlas metadata without raw installed art.
retained = {}

notes = {
    'scope': 'Attributes-only static native label artwork plus transparent input overlay; native label text hooks, bounded claimed Title and foreground numeric labels; unchanged fonts, allocation rules and shared Painter.',
    'acceptedChecks': 83,
    'production': production,
    'cases': summaries,
    'retainedDiagnostics': retained,
    'originalOwner': '8dc330 -> 822b60 CGuiCharGenLabel;8ed110 imports names/scores and sets Title bounds flag4.',
    'beforeExpectedFailures': 25,
    'beforeAfterSameRasterAssertions': True,
    'rasterUsesInstalledArtAndFonts': True,
    'input45UsesArtworkDoubleAndInstalledFonts': True,
    'nativeModelCoordinatesChanged': False,
    'nameCaptionPlacementCorrected': True,
    'rulesChanged': False,
    'layoutChanged': True,
    'sharedPainterChanged': False,
    'nativeOutputsUnchanged': proofs['after-raster38']['nativeBefore'],
    'userClientInteraction': False,
    'userClientRestart': False,
    'serverConnections': 0,
    'nativeBuilds': 0,
    'gpuRaster': True,
    'gpuBenchmark': False,
    'originalClientPixelAcceptance': False,
    'claimLimits': 'Exact copied source correctness, not whole creation/gameplay acceptance. No installed raw textures/fonts/native executables or credentials are archived. Composite before/after UI screenshots are evidence.',
}
files['ACCEPTANCE.json'] = (json.dumps(notes, indent=2) + '\n').encode()
manifest = {name: sha(data) for name, data in files.items()}
files['MANIFEST.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
target.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for name, data in files.items():
        archive.writestr(name, data)
with zipfile.ZipFile(target) as archive:
    assert len(archive.namelist()) == len(files)
    for name, data in files.items():
        assert archive.read(name) == data, name
receipt = {
    'success': True, 'archive': str(target.relative_to(root)).replace('\\', '/'),
    'sha256': sha(target.read_bytes()), 'entries': len(files),
    'bytes': target.stat().st_size, 'manifestSha256': sha(files['MANIFEST.json']),
    **notes,
}
output.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: receipt[k] for k in ['success', 'archive', 'sha256', 'entries', 'bytes', 'manifestSha256', 'acceptedChecks', 'production']}))
