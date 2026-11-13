"""Preserve exact existing creator activation witnesses, including counterexamples."""
from pathlib import Path
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--report', required=True)
output = Path(p.parse_args().report).resolve()
if output.exists():
    raise SystemExit('Refusing to overwrite original evidence')


def read(relative):
    return json.loads((ROOT / relative).read_text(encoding='utf-8-sig'))


index_path = 'godot-client/reports/native-modal-activation-callers-v2.json'
package_path = 'godot-client/reports/native-creation-package-research-v1.json'
skills_path = 'godot-client/reports/native-creation-skills-research-v1.json'
index = read(index_path)
package = read(package_path)
skills = read(skills_path)
assert index['binarySha256'] == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
package_open = package['procedures']['main-entry']
skills_open = package['procedures']['configure']
continuation = next(r for r in skills['functions'] if r['name'] == 'skills-next')
assert 'CGuiModalPanel::Activate' in package_open['pseudocode']
assert 'FUN_1409c3040' in skills_open['pseudocode'] and 'CGuiModalPanel::Activate' in skills_open['pseudocode']
assert 'CCharacterDomainPanel::vftable' in continuation['pseudocode']
assert 'CGuiPanel::Activate(this)' in continuation['pseudocode']
bodies = [r for r in index['procedures'] if r['start'] in ['0x1408e5770', '0x1408e1ec0', '0x1409c69a0', '0x1409c8d10']]
assert len(bodies) == 4
result = {
    'success': True,
    'authority': 'Saved original Ghidra dossiers plus exact PE unwind direct-call bodies; static evidence, not UI execution acceptance',
    'binarySha256': index['binarySha256'],
    'inputHashes': [{'path': n, 'sha256': hashlib.sha256((ROOT / n).read_bytes()).hexdigest()}
                    for n in [index_path, package_path, skills_path]],
    'package': package_open,
    'skillsFromConfigure': skills_open,
    'domainFamiliarOrdinaryActivationCounterexample': continuation,
    'directCallBodies': bodies,
    'limits': ['No modal classification based only on RTTI, native SourceModal inheritance or CanvasLayer',
               'Skills proof is the explicit Package Configure path; other entry paths need their own review',
               'Domain/Familiar ordinary activation does not establish a general negative membership proof',
               'No original pixels, user process, server, GPU or native build'],
}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'success': True, 'directBodies': len(bodies), 'report': str(output)}))
