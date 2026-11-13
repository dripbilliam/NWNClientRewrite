"""Verify and seal immutable first-level tail UI correctness evidence.

Never reads credentials, original installed assets or native executable bytes.
Before/failure cases retain their original rejected status and exact inputs.
"""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
project = root / 'godot-client'
target = root / 'backups/native-creation-tail-ui-after-v2.zip'
output = project / 'reports/native-creation-tail-ui-v2-checkpoint.json'
if target.exists() or output.exists():
    raise RuntimeError('Existing checkpoint preserved')


def sha(data):
    return hashlib.sha256(data).hexdigest()


cases = {
    'keyboard24': (project / '.cache/creation-tail-keyboard/tail-keys-modal-voice-current-v3', 24, True),
    'actual-raster30': (project / '.cache/creation-tail-visual/tail-visual-voice-after-v3', 30, True),
    'voice-input28': (project / '.cache/creation-character-info-view/info-native-voice-caption-input-v6', 28, True),
    'before-voice3failures': (project / '.cache/creation-tail-visual/tail-visual-voice-before-v3', 30, False),
}

files = {}
summaries = {}
proofs = {}
for label, (directory, checks, success) in cases.items():
    proof = json.loads((directory / 'proof.json').read_text(encoding='utf-8-sig'))
    result = json.loads((directory / 'result.json').read_text(encoding='utf-8-sig'))
    proofs[label] = proof
    assert proof['success'] == success and result['success'] == success
    assert proof['checks'] == checks and proof['cleanEngine']
    assert proof['error'] is None and not proof['changedInputs']
    assert not proof.get('changedNative', [])
    if success:
        assert proof['exitCode'] == 0 and not result['failures']
    elif label == 'before-voice3failures':
        assert proof['baselineSelected'] and proof['exitCode'] == 1
        assert len(result['failures']) == 3
        assert all('voice' in value.lower() for value in result['failures'])
    else:
        assert proof['exitCode'] == 1 and result['failures'] == ['Backspace remains available above the source character limit']
    for row in proof['inputs']:
        source = directory / 'inputs' / row['path']
        data = source.read_bytes()
        assert sha(data) == row['sha256'], str(source)
        assert source.suffix.lower() in ['.gd', '.gdextension', '.mjs', '.js', '.cjs', '.json'], str(source)
        files[f'{label}/inputs/{row["path"]}'] = data
    for name in ['proof.json', 'result.json', 'engine.log', 'stdout.log', 'stderr.log']:
        source = directory / name
        if source.exists():
            files[f'{label}/receipts/{name}'] = source.read_bytes()
    # Only composite UI evidence is included, never source palette/PLT/TGA/font images.
    for image in directory.glob('result.json.*.png'):
        files[f'{label}/screenshots/{image.name}'] = image.read_bytes()
    summaries[label] = {
        'success': success, 'checks': checks, 'cleanEngine': True,
        'exitCode': proof['exitCode'], 'failures': result['failures'],
        'inputs': len(proof['inputs']),
        'directory': str(directory.relative_to(root)).replace('\\', '/'),
        'proofSha256': sha((directory / 'proof.json').read_bytes()),
        'scope': result['scope'],
    }

owned = [
    'godot-client/systems/native_appearance_chooser.gd',
    'godot-client/systems/native_character_info_chooser.gd',
    'godot-client/systems/native_generic_edit.gd',
    'godot-client/systems/native_data/creation_character_info_layout.gd',
]
production = {}
for relative in owned:
    current_hash = sha((root / relative).read_bytes())
    for case in ['keyboard24', 'actual-raster30', 'voice-input28']:
        rows = [row for row in proofs[case]['inputs'] if row['path'] == relative]
        assert len(rows) == 1 and rows[0]['sha256'] == current_hash, (case, relative)
    production[relative] = current_hash
baseline = next(row for row in proofs['before-voice3failures']['inputs']
                if row['path'] == 'godot-client/systems/native_character_info_chooser.gd')
assert baseline['sourcePath'] != baseline['path']
assert baseline['sha256'] == 'd78b14de6f592a7a47c851f3dfede531d13047d15b3ed77df60f1d6be4ca4af1'

for relative in [
    'godot-client/NATIVE-CREATION-APPEARANCE-INFO.md',
    'godot-client/reports/native-creation-tail-visual-keys-original-v1.json',
    'godot-client/reports/native-generic-edit-message-owner-original-v1.json',
    'godot-client/reports/native-creation-voice-caption-original-v1.json',
    'scripts/seal-native-creation-tail-ui-voice.py',
]:
    files[f'documentation/{relative}'] = (root / relative).read_bytes()

notes = {
    'scope': 'First-level source Appearance/Information keyboard, top Deity modal and installed-art swatch/message raster. Source voice-caption left alignment/font/text attachment follow-up retaining prior swatch and GenericEdit fixes; no blanket Painter/Dialog edit.',
    'acceptedUiChecks': 82,
    'supportingResourceChecks': 0,
    'production': production,
    'cases': summaries,
    'originalSources': {
        'appearanceEscape': 'vtable140e64168+140 ->1408e3300, Cancel2',
        'informationEscape': 'vtable140e647c8+140 ->1408e3380, Cancel2',
        'genericMessage': 'InitializeModel140201960 flags(this+220)|=4 before MessageLabel import',
        'parentEscape': 'CCharacterGenerationPanel140e64678+140 ->1401eea30 returns0/no action; unchanged',
        'selectedSwatch': '8eb480 gui_replace01 ->GUI_CG_COLOR_TMP with one ushort packed palette selector:0skin,1hair,6tattoo',
    },
    'nativeOutputsUnchanged': proofs['actual-raster30']['nativeBefore'],
    'gpuRaster': True, 'gpuBenchmark': False,
    'serverConnections': 0, 'nativeBuilds': 0,
    'userClientInteraction': False, 'userClientRestart': False,
    'limits': [
        'Actual raster uses installed source models/fonts; empty preview slot is deliberate. Shipping private model preview/BIC has separate owner acceptance.',
        'Keyboard/modal and Generic input use artwork publication doubles; Generic input uses installed fonts.',
        'Authored active palette-row fixture proves source provenance and actual pixels, not a live server or whole creator outcome.',
        'Audible playback, original-client pixel identity, environment-map reflections, arbitrary locale/IME and unproven voice-list key shortcuts remain outside scope.',
        'The first visual24 case caught vertical Deity text on manual review; only later27 case with explicit source-message/ink assertions is accepted here.',
        'Root shared palette helper has its own74-check acceptance; those checks are not counted here.',
        'Prior tail UI v1 checkpoint64+resource10, including Generic input13, remains separately immutable; overlapping regression counts are not added to this82.',
        'No raw installed palettes/fonts/models, credential files or native binaries are archived.',
    ],
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
    'sha256': sha(target.read_bytes()), 'entries': len(files), 'bytes': target.stat().st_size,
    'manifestSha256': sha(files['MANIFEST.json']), **notes,
}
output.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: receipt[key] for key in ['success', 'archive', 'sha256', 'entries', 'bytes', 'manifestSha256', 'acceptedUiChecks', 'supportingResourceChecks', 'production']}))
