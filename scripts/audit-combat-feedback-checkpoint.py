"""Independently check archive scope/hashes and changed-text credential patterns.
Print counts only. The inherited runtime-sync checkpoint has a sealed scope audit.
"""
import hashlib,json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
required=['src/network_feedback_message.js','src/client_feedback_format.js',
 'src/client_feedback_descriptors.js','src/network_feedback_view.js','src/native_rich_text.js',
 'src/network_game_messages.js','src/network_world.js','src/network_text.js',
 'src/network_frontend.js','src/network_speech_view.js','src/main.js',
 'electron/network_game_session.mjs','test/network-feedback.test.js',
 'scripts/inspect-native-feedback-layouts.py','scripts/inspect-native-feedback-format.py',
 'scripts/build-feedback-descriptors.mjs','scripts/checkpoint-combat-feedback.ps1',
 'scripts/audit-combat-feedback-checkpoint.py','evidence/multiplayer-combat-feedback.md',
 'backups/animations/native-client-feedback-layouts.json',
 'backups/animations/native-client-feedback-format-observations.json',
 'backups/animations/network-feedback-regression-v1.txt',
 'backups/animations/network-feedback-build-v1.txt',
 'backups/animations/network-feedback-entry-v1.png']
patterns=[re.compile(rb'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b'),
 re.compile(rb'(?<![A-Za-z0-9])[A-HJ-NP-Z2-9]{35}(?![A-Za-z0-9])')]
text_extensions={'.js','.mjs','.cjs','.json','.md','.txt','.ps1','.py','.java','.css','.html','.c','.h','.toml','.jsonl'}
with zipfile.ZipFile(root/'backups/multiplayer-runtime-sync-20261019-v1.zip')as old,zipfile.ZipFile(root/'backups/multiplayer-combat-feedback-20261019-v2.zip')as new:
 previous={r['path'].casefold():r for r in json.loads(old.read('checkpoint-manifest.json'))}
 manifest=json.loads(new.read('checkpoint-manifest.json'));names=new.namelist();fold={n.casefold()for n in names}
 missing=[n for n in required if n.casefold()not in fold];forbidden=[];changed=fresh=0
 for n in names:
  p=Path(n);low=n.casefold()
  if p.suffix.casefold()in{'.exe','.dll','.bic','.bif','.key','.nwm','.hak','.mdl','.tga','.dds'}or low.startswith('runtime-logs/')and low!='runtime-logs/rea-session-stderr.txt'or re.search(r'(?:network-runtime-(?:interactive|live)|network-renderer-control|local-network-runtime)-v111',p.name):forbidden.append(n)
 for record in manifest:
  n=record['path'];data=new.read(n);assert len(data)==record['bytes']and hashlib.sha256(data).hexdigest().casefold()==record['sha256'].casefold()
  prior=previous.get(n.casefold())
  if Path(n).suffix.casefold()not in text_extensions or prior and prior['sha256']==record['sha256']and prior['bytes']==record['bytes']:continue
  changed+=1;hits={v for pattern in patterns for v in pattern.findall(data)};old_data=old.read(prior['path'])if prior else b''
  fresh+=len(hits-{v for pattern in patterns for v in pattern.findall(old_data)})
 result=dict(entries=len(names),verifiedFiles=len(manifest),required=len(required),missing=missing,forbidden=len(forbidden),duplicates=len(names)-len(fold),changedNewTextScanned=changed,newCredentialCandidates=fresh,baselineAudit='network-runtime-scope-audit-v1.txt')
 print(json.dumps(result,indent=2));assert not missing and not forbidden and len(names)==len(fold)and fresh==0
