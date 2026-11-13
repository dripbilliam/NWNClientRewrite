"""Preserve existing original Video/Key modal witnesses without rerunning REA.

Static evidence only. The constructor/open path determines membership; source
artwork, Godot inheritance and CanvasLayer order do not establish it.
"""
from pathlib import Path
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--report', required=True)
output = Path(parser.parse_args().report).resolve()
if output.exists():
    raise SystemExit('Refusing to overwrite original evidence')


def load(relative):
    return json.loads((ROOT / relative).read_text(encoding='utf-8-sig'))


binary_sha = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
index_path = 'godot-client/reports/native-modal-activation-callers-v2.json'
index = load(index_path)
assert index['binarySha256'] == binary_sha
video_path = 'backups/animations/rea-native-video-options-v1.json'
keys_path = 'backups/animations/rea-native-key-settings-v1.json'
video = next(r for r in load(video_path)['rows']
             if r['procedure']['address'] == '0x140822e40')
keys = next(r for r in load(keys_path)['dossiers']
            if r.get('result', {}).get('procedure', {}).get('address') == '0x1408b94d0')
assert 'CVideoModePanel::vftable' in video['pseudocode']
assert 'CGuiMan::SetModal' in keys['result']['pseudocode']
opens = [r for r in index['procedures'] if r['start'] in
         ['0x1408bd240', '0x14082f2b0', '0x1408bc670']]
assert len(opens) == 3 and all(r['completeLinearDecode'] for r in opens)
assert opens[-1]['start'] == '0x1408bd240'
assert any(c['service'] == 'modal_activate' for c in opens[-1]['calls'])

report = {
    'success': True,
    'authority': 'Existing pinned original static dossiers and exact PE unwind bodies; not runtime execution acceptance',
    'binarySha256': binary_sha,
    'inputHashes': [{'path': p, 'sha256': hashlib.sha256((ROOT / p).read_bytes()).hexdigest()}
                    for p in [index_path, video_path, keys_path]],
    'video': {
        'open': '0x1408bd240',
        'constructor': '0x140822e40',
        'modalActivateAt': '0x1408bd287',
        'initializerNotConstructor': '0x140830160',
        'constructorEvidence': video,
    },
    'keys': {
        'opens': ['0x14082f2b0', '0x1408bc670'],
        'constructor': '0x1408b94d0',
        'explicitModalInsertAt': '0x1408b9590',
        'ordinaryActivateAfterConstructor': True,
        'constructorEvidence': keys,
    },
    'openBodies': opens,
    'nativeBoundary': 'Replacement prewarms these owners; register only successful logical show_page, never configure/build/art or settings refresh. Retire at finish/scope/close/exit.',
    'limits': ['No whole modal inventory or NUI membership claim',
               'No original pixels, user-client interaction, GPU or server execution',
               'Underlying PE unwind body may not include separately chained cold fragments'],
    'servers': 0, 'gpu': False, 'nativeBuilds': 0,
}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'success': True, 'openBodies': len(opens), 'constructors': 2, 'report': str(output)}))
