"""Seal immutable Attributes raster/input evidence without installed assets.

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
    'after-raster24': project / '.cache/creation-attributes-art-origin/attributes-static-pose-after-v4',
    'after-input42': project / '.cache/creation-attributes-text-geometry/attributes-static-rows-input-v5',
    'before-expected12failures': project / '.cache/creation-attributes-art-origin/attributes-static-pose-baseline-v5',
}
target = root / 'backups/native-attributes-static-rows-after-v1.zip'
output = project / 'reports/native-attributes-static-rows-v1-checkpoint.json'
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
        assert proof['checks'] == (24 if label == 'after-raster24' else 42)
    else:
        assert proof['baselineSelected'] and not proof['success']
        assert proof['exitCode'] == 1 and proof['checks'] == 24
        assert len(proof['failures']) == 12
        assert all('ink centers inside actual native black row interior:' in item for item in proof['failures'])
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
for relative in ['godot-client/systems/native_attributes_chooser.gd',
                 'godot-client/systems/native_data/creation_attributes_layout.gd']:
    current_hash = sha((root / relative).read_bytes())
    for label in ['after-raster24', 'after-input42']:
        rows = [row for row in proofs[label]['inputs'] if row['path'] == relative]
        assert len(rows) == 1 and rows[0]['sha256'] == current_hash, relative
    production[relative] = current_hash
assert production['godot-client/systems/native_attributes_chooser.gd'] == '5616bcd95aebc6875019124aa09a77b90b9b5203bc3af84eda5449b3c65c4e6f'

before_rows = [r for r in proofs['before-expected12failures']['inputs']
               if r['path'] == 'godot-client/systems/native_attributes_chooser.gd']
assert len(before_rows) == 1
assert before_rows[0]['sha256'] == '7e785f8cb4b02be1852e6f23ac2eef00489de1468eb4bc3f7cd43a7fb6b44dcb'
assert before_rows[0]['sourcePath'] != before_rows[0]['path']

extras = [
    'godot-client/NATIVE-CREATION-ATTRIBUTES.md',
    'godot-client/reports/native-attributes-static-label-owner-original-v1.json',
    'scripts/seal-native-attributes-static-rows.py',
]
for relative in extras:
    files[f'documentation/{relative}'] = (root / relative).read_bytes()

# Keep finite diagnostic failures and atlas metadata without raw installed art.
diagnostics = {
    'atlas-v2': project / '.cache/attributes-texture-diagnostic/attrs-atlas-v2',
    'before-v1': project / '.cache/creation-attributes-art-origin/attributes-actual-art-before-v1',
    'before-v2-isolation-rejected': project / '.cache/creation-attributes-art-origin/attributes-actual-art-before-v2',
    'baseline-v3-isolation-rejected': project / '.cache/creation-attributes-art-origin/attributes-static-pose-baseline-v3',
}
retained = {}
for label, directory in diagnostics.items():
    if not directory.exists():
        raise RuntimeError(f'Missing retained diagnostic: {directory}')
    retained[label] = str(directory.relative_to(root)).replace('\\', '/')
    for name in ['proof.json', 'result.json', 'engine.log', 'stdout.log', 'stderr.log']:
        source = directory / name
        if source.exists():
            files[f'diagnostics/{label}/{name}'] = source.read_bytes()

notes = {
    'scope': 'Attributes-only static native label artwork plus transparent input overlay; unchanged coordinates, layout, fonts, allocation rules and shared Painter.',
    'acceptedChecks': 66,
    'production': production,
    'cases': summaries,
    'retainedDiagnostics': retained,
    'originalOwner': '8db730 -> 822b60 CGuiCharGenLabel; label1fe260 retains static pose, separate arrows are timer buttons.',
    'beforeExpectedFailures': 12,
    'beforeAfterSameRasterAssertions': True,
    'rasterUsesInstalledArtAndFonts': True,
    'input42UsesArtworkDoubleAndInstalledFonts': True,
    'coordinatesChanged': False,
    'rulesChanged': False,
    'layoutChanged': False,
    'sharedPainterChanged': False,
    'nativeOutputsUnchanged': proofs['after-raster24']['nativeBefore'],
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
