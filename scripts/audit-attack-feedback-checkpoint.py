"""Independent full archive hash/scope and changed-text credential-pattern audit."""
import hashlib,json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
required=['src/network_attack_feedback.js','src/network_game_messages.js','src/network_feedback_view.js','src/network_frontend.js','src/main.js','src/network_floating_text_view.js','test/network-attack-feedback.test.js','scripts/inspect-native-attack-feedback.py','scripts/inspect-native-attack-feedback-wire.py','scripts/checkpoint-attack-feedback.ps1','scripts/probe-network-renderer.cjs','evidence/multiplayer-attack-feedback.md','backups/animations/native-client-attack-feedback-observations.json','backups/animations/native-network-attack-feedback-wire.json','backups/animations/network-attack-feedback-build-v1.txt','backups/animations/network-attack-feedback-regression-v1.txt','backups/animations/network-attack-feedback-entry-v1.png','backups/animations/network-attack-feedback-replay-v1.json','backups/animations/local-network-spell-feedback-v114.json','backups/animations/local-network-damage-feedback-v115.json','backups/animations/local-network-damage-feedback-v116.json']
patterns=[re.compile(rb'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b'),re.compile(rb'(?<![A-Za-z0-9])[A-HJ-NP-Z2-9]{35}(?![A-Za-z0-9])')]
extensions={'.js','.mjs','.cjs','.json','.md','.txt','.ps1','.py','.java','.css','.html','.c','.h','.toml','.jsonl'}
with zipfile.ZipFile(root/'backups/multiplayer-damage-feedback-20261019-v1.zip')as old,zipfile.ZipFile(root/'backups/multiplayer-attack-feedback-20261019-v1.zip')as new:
 previous={r['path'].casefold():r for r in json.loads(old.read('checkpoint-manifest.json'))};manifest=json.loads(new.read('checkpoint-manifest.json'));names=new.namelist();fold={n.casefold()for n in names};missing=[n for n in required if n.casefold()not in fold];forbidden=[];changed=fresh=0
 for n in names:
  p=Path(n);low=n.casefold()
  if p.suffix.casefold()in{'.exe','.dll','.bic','.bif','.key','.nwm','.hak','.mdl','.tga','.dds'}or low.startswith('runtime-logs/')and low!='runtime-logs/rea-session-stderr.txt'or re.search(r'(?:network-attack-feedback-(?:interactive|live)|network-renderer-control|local-network-attack-feedback)-v11[789]',p.name):forbidden.append(n)
 for record in manifest:
  n=record['path'];data=new.read(n);assert len(data)==record['bytes']and hashlib.sha256(data).hexdigest().casefold()==record['sha256'].casefold()
  prior=previous.get(n.casefold())
  if Path(n).suffix.casefold()not in extensions or prior and prior['sha256']==record['sha256']and prior['bytes']==record['bytes']:continue
  changed+=1;hits={v for pattern in patterns for v in pattern.findall(data)};old_data=old.read(prior['path'])if prior else b'';fresh+=len(hits-{v for pattern in patterns for v in pattern.findall(old_data)})
 result=dict(entries=len(names),verifiedFiles=len(manifest),required=len(required),missing=missing,forbidden=len(forbidden),duplicates=len(names)-len(fold),changedNewTextScanned=changed,newCredentialCandidates=fresh,baselineAudit='network-damage-feedback-scope-audit-v1.txt');print(json.dumps(result,indent=2));assert not missing and not forbidden and len(names)==len(fold)and fresh==0
