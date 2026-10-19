"""Verify the movement-facing checkpoint scope and changed-text credential patterns.
Print counts only; never print possible credential values.
"""
import json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
baseline=root/'backups/multiplayer-hud-buttons-20261018-v2.zip'
checkpoint=root/'backups/multiplayer-movement-facing-20261018-v1.zip'
required=["src/network_facing.js","src/network_motion.js","src/network_scene.js","test/network-facing-native.test.js","test/network-motion-native.test.js","scripts/inspect-native-network-facing.py","scripts/replay-network-facing.mjs","scripts/inspect-movement-video.cjs","scripts/movement-video-fixture.html","scripts/checkpoint-combat.ps1","scripts/audit-movement-facing-checkpoint.py","evidence/multiplayer-movement-facing.md","CASTING_RESUME_NOTE.md","REPLACEMENT_CLIENT_ROADMAP.MD","backups/animations/native-network-facing-observations.json","backups/animations/native-movement-reader-path-install-v2.txt","backups/animations/network-facing-oracle-v2.txt","backups/animations/network-facing-replay-v1.json","backups/animations/network-facing-replay-v1.txt","backups/animations/network-motion-before-facing-v1.mjs","backups/animations/network-motion-before-facing-v1.txt","backups/animations/local-network-movement-v91.json","backups/animations/network-movement-facing-acceptance-v1.json","backups/animations/movement-video-metadata-v1.json","backups/animations/movement-video-contact-v1.png","backups/animations/network-movement-ready-v91.png","backups/animations/network-movement-ready-v92.png","backups/animations/network-movement-smoothing-build-v1.txt","backups/animations/network-movement-smoothing-tests-v2.txt"]
patterns=[re.compile(rb'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b'),re.compile(rb'(?<![A-Za-z0-9])[A-HJ-NP-Z2-9]{35}(?![A-Za-z0-9])')]
text_extensions={'.js','.mjs','.cjs','.json','.md','.txt','.ps1','.py','.java','.css','.html','.c','.h','.toml','.jsonl'}
with zipfile.ZipFile(baseline)as old,zipfile.ZipFile(checkpoint)as new:
 old_manifest={r['path'].casefold():r for r in json.loads(old.read('checkpoint-manifest.json'))}
 manifest=json.loads(new.read('checkpoint-manifest.json'));names=[n.filename for n in new.infolist()];fold={n.casefold():n for n in names}
 missing=[n for n in required if n.casefold()not in fold];forbidden=[];unchanged=changed=candidates=fresh=0
 for n in names:
  p=Path(n);low=n.casefold()
  if p.suffix.casefold()in {'.exe','.dll','.bic','.bif','.key','.nwm','.hak','.mdl','.tga','.dds'}or low.startswith('runtime-logs/')and low!='runtime-logs/rea-session-stderr.txt'or p.name in {'network-spellbook-interactive-v88.txt','network-spellbook-interactive-v88-stderr.txt','network-spellbook-live-v88.json','network-renderer-control-v88.json','network-spellbook-checkpoint-v1.txt','network-hud-buttons-interactive-v90.txt','network-hud-buttons-interactive-v90-stderr.txt','network-hud-buttons-live-v90.json','network-renderer-control-v90.json','network-hud-buttons-checkpoint-v1.txt','network-hud-buttons-checkpoint-v2.txt','network-movement-interactive-v92.txt','network-movement-interactive-v92-stderr.txt','network-movement-live-v92.json','network-renderer-control-v92.json','network-movement-facing-checkpoint-v1.txt'}:forbidden.append(n)
 for row in manifest:
  n=row['path'];prior=old_manifest.get(n.casefold())
  if Path(n).suffix.casefold()not in text_extensions:continue
  if prior and prior['sha256']==row['sha256']and prior['bytes']==row['bytes']:unchanged+=1;continue
  changed+=1;data=new.read(n);hits={v for pattern in patterns for v in pattern.findall(data)};candidates+=len(hits)
  old_data=old.read(prior['path'])if prior else b'';prior_hits={v for pattern in patterns for v in pattern.findall(old_data)};fresh+=len(hits-prior_hits)
 result=dict(entries=len(names),required=len(required),missing=missing,forbidden=len(forbidden),casefoldDuplicates=len(names)-len(fold),inheritedUnchangedText=unchanged,changedNewTextScanned=changed,changedTextCandidates=candidates,newCredentialCandidates=fresh,baselineAudit='network-hud-buttons-scope-audit-v2.txt')
 print(json.dumps(result,indent=2));assert not missing and not forbidden and len(names)==len(fold)and fresh==0
