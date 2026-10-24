"""Independent hash, parent chain, persistence scope and credential audit."""
import hashlib,json,re,sys,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1];name=sys.argv[1];assert re.fullmatch('[a-z0-9-]+',name)
required=['src/network_character.js','src/network_game_messages.js','src/network_frontend.js','src/style.css','index.html','electron/network_game_session.mjs','electron/network_character_vault.mjs','electron/network_ipc.cjs','electron/preload.cjs','electron/main.cjs','electron/installed_network_session.mjs','scripts/probe-network-renderer.cjs','scripts/inspect-native-character-export-wire.py','scripts/network-character-fixture.html','scripts/network-character-fixture.mjs','scripts/smoke-network-character.cjs','scripts/checkpoint-character-export.ps1','scripts/audit-character-export-checkpoint.py','test/network-character-export.test.js','test/network-character-vault.test.js','test/network-ipc.test.js','evidence/multiplayer-character-persistence.md','evidence/multiplayer-character-export-investigation.md','backups/animations/native-character-export-wire-observations.json','backups/animations/rea-character-export-filename.json','backups/animations/rea-character-export-write-opaque.json','backups/animations/network-character-export-focused-v2.txt','backups/animations/network-character-export-regression-v1.txt','backups/animations/network-character-export-build-v2.txt','backups/animations/network-character-export-ui-v1.json','backups/animations/network-character-export-ui-v1.png','backups/animations/network-character-export-ui-v3.txt']
required+=['scripts/verify-network-character-export.mjs','evidence/multiplayer-chat.md','backups/animations/rea-character-rejoin-load-creature.json','backups/animations/rea-character-rejoin-ready-spell-body.json']
patterns=[re.compile(rb'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b'),re.compile(rb'(?<![A-Za-z0-9])[A-HJ-NP-Z2-9]{35}(?![A-Za-z0-9])')]
with zipfile.ZipFile(root/'backups'/f'{name}.zip')as new:
 names=new.namelist();fold={n.casefold()for n in names};manifest=json.loads(new.read('checkpoint-manifest.json'));chain=json.loads(new.read('checkpoint-chain.json'));parents=[];previous={}
 for record in chain['parents']:
  p=root/'backups'/record['archive'];assert p.parent==root/'backups';assert hashlib.sha256(p.read_bytes()).hexdigest()==record['sha256'].lower();z=zipfile.ZipFile(p);parents.append(z)
  for r in json.loads(z.read('checkpoint-manifest.json')):previous[r['path'].casefold()]=(z,r['path'])
 missing=[n for n in required if n.casefold()not in fold];forbidden=[];secrets=0
 for r in manifest:
  n=r['path'];data=new.read(n);assert len(data)==r['bytes']and hashlib.sha256(data).hexdigest()==r['sha256'].lower()
  if Path(n).suffix.lower()in{'.exe','.dll','.bic','.bif','.key','.nwm','.hak','.mdl','.tga','.dds'}or n.startswith('runtime-logs/')or re.search(r'(-live-v\d+\.json|interactive-v|network-renderer-control)',n):forbidden.append(n)
  if Path(n).suffix in{'.js','.mjs','.cjs','.py','.ps1','.json','.md','.txt','.html','.css'}:
   old=previous.get(n.casefold());before=old[0].read(old[1])if old else b'';secrets+=len({v for p in patterns for v in p.findall(data)}-{v for p in patterns for v in p.findall(before)})
  if Path(n).name.startswith('local-network-'):assert json.loads(data)['states'][-1]['phase']=='closed'
 for z in parents:z.close()
 result=dict(entries=len(names),verifiedFiles=len(manifest),parentsVerified=len(chain['parents']),required=len(required),missing=missing,forbidden=len(forbidden),duplicates=len(names)-len(fold),newCredentialCandidates=secrets);print(json.dumps(result,indent=2));assert not missing and not forbidden and len(names)==len(fold)and secrets==0
