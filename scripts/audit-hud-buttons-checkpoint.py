"""Verify the HUD-buttons checkpoint scope and changed-text credential patterns.
Print counts only; never print possible credential values.
"""
import json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
baseline=root/'backups/multiplayer-spellbook-menus-20261018-v1.zip'
checkpoint=root/'backups/multiplayer-hud-buttons-20261018-v2.zip'
required=["src/network_hud_input.js","src/network_hud_messages.js","src/network_automap.js","src/network_map.js","src/network_timing_view.js","src/network_panels.js","src/network_world.js","src/network_game_messages.js","src/network_frontend.js","src/map_ui.js","src/main.js","src/style.css","electron/network_game_session.mjs","electron/network_ipc.cjs","electron/preload.cjs","scripts/inspect-native-hud-requests.py","scripts/network-hud-fixture.mjs","scripts/smoke-network-hud.cjs","scripts/probe-network-renderer.cjs","scripts/checkpoint-combat.ps1","scripts/audit-hud-buttons-checkpoint.py","test/network-hud-buttons.test.js","test/network-game-session.test.js","evidence/multiplayer-hud-buttons.md","CASTING_RESUME_NOTE.md","REPLACEMENT_CLIENT_ROADMAP.md","backups/animations/native-hud-request-observations.json","backups/animations/native-hud-client-automap-reader-v1.txt","backups/animations/native-hud-sheet-page-state-v1.txt","backups/animations/native-hud-request-oracle-v3.txt","backups/animations/network-hud-buttons-acceptance-v1.json","backups/animations/local-network-hud-buttons-v89.json","backups/animations/network-hud-buttons-readiness-v90.json","backups/animations/network-hud-buttons-replay-v1.json","backups/animations/network-hud-buttons-prepared-v1.png","backups/animations/network-hud-buttons-spontaneous-v1.png","backups/animations/network-hud-rest-v89.png","backups/animations/network-hud-journal-v89.png","backups/animations/network-hud-skills-v90.png","backups/animations/network-hud-feats-v90.png","backups/animations/network-hud-map-v90.png","backups/animations/network-hud-options-v90.png","backups/animations/network-hud-players-v90.png","backups/animations/network-hud-ready-v90.png","backups/animations/network-hud-buttons-focused-v4.txt","backups/animations/network-hud-buttons-build-v5.txt","backups/animations/network-hud-buttons-ui-v6.txt","backups/animations/network-hud-buttons-ui-v6-stderr.txt"]
patterns=[re.compile(rb'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b'),re.compile(rb'(?<![A-Za-z0-9])[A-HJ-NP-Z2-9]{35}(?![A-Za-z0-9])')]
text_extensions={'.js','.mjs','.cjs','.json','.md','.txt','.ps1','.py','.java','.css','.html','.c','.h','.toml','.jsonl'}
with zipfile.ZipFile(baseline)as old,zipfile.ZipFile(checkpoint)as new:
 old_manifest={r['path'].casefold():r for r in json.loads(old.read('checkpoint-manifest.json'))}
 manifest=json.loads(new.read('checkpoint-manifest.json'));names=[n.filename for n in new.infolist()];fold={n.casefold():n for n in names}
 missing=[n for n in required if n.casefold()not in fold];forbidden=[];unchanged=changed=candidates=fresh=0
 for n in names:
  p=Path(n);low=n.casefold()
  if p.suffix.casefold()in {'.exe','.dll','.bic','.bif','.key','.nwm','.hak','.mdl','.tga','.dds'}or low.startswith('runtime-logs/')and low!='runtime-logs/rea-session-stderr.txt'or p.name in {'network-spellbook-interactive-v88.txt','network-spellbook-interactive-v88-stderr.txt','network-spellbook-live-v88.json','network-renderer-control-v88.json','network-spellbook-checkpoint-v1.txt','network-hud-buttons-interactive-v90.txt','network-hud-buttons-interactive-v90-stderr.txt','network-hud-buttons-live-v90.json','network-renderer-control-v90.json','network-hud-buttons-checkpoint-v1.txt'}:forbidden.append(n)
 for row in manifest:
  n=row['path'];prior=old_manifest.get(n.casefold())
  if Path(n).suffix.casefold()not in text_extensions:continue
  if prior and prior['sha256']==row['sha256']and prior['bytes']==row['bytes']:unchanged+=1;continue
  changed+=1;data=new.read(n);hits={v for pattern in patterns for v in pattern.findall(data)};candidates+=len(hits)
  old_data=old.read(prior['path'])if prior else b'';prior_hits={v for pattern in patterns for v in pattern.findall(old_data)};fresh+=len(hits-prior_hits)
 result=dict(entries=len(names),required=len(required),missing=missing,forbidden=len(forbidden),casefoldDuplicates=len(names)-len(fold),inheritedUnchangedText=unchanged,changedNewTextScanned=changed,changedTextCandidates=candidates,newCredentialCandidates=fresh,baselineAudit='network-spellbook-scope-audit-v1.txt')
 print(json.dumps(result,indent=2));assert not missing and not forbidden and len(names)==len(fold)and fresh==0
