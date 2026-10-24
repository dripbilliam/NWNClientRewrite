"""Independent incremental archive chain, entry hashes, scope and secret audit."""
import hashlib,json,re,sys,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1];name=sys.argv[1];assert re.fullmatch('[a-z0-9-]+',name)
patterns=[re.compile(rb'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b'),re.compile(rb'(?<![A-Za-z0-9])[A-HJ-NP-Z2-9]{35}(?![A-Za-z0-9])')]
required=['src/visual_type10.js','src/client_projectile_presentation.js','src/visual_scene_runtime.js','src/network_projectile_presentation.js','src/network_visual_presentation.js','src/main.js','test/visual-type10-native.test.js','test/visual-type10-presentation.test.js','evidence/multiplayer-procedural-projectiles.md','backups/animations/native-visual-type10-observations.json','backups/animations/network-procedural-projectile-replay-v1.json']
with zipfile.ZipFile(root/'backups'/f'{name}.zip')as new:
 names=new.namelist();fold={n.casefold()for n in names};chain=json.loads(new.read('checkpoint-chain.json'));manifest=json.loads(new.read('checkpoint-manifest.json'));previous={};parent_zips=[]
 for p in chain['parents']:
  path=root/'backups'/p['archive'];assert path.parent==root/'backups';assert hashlib.sha256(path.read_bytes()).hexdigest()==p['sha256'].lower();z=zipfile.ZipFile(path);parent_zips.append(z)
  for r in json.loads(z.read('checkpoint-manifest.json')):previous[r['path'].casefold()]=(z,r)
 missing=[n for n in required if n.casefold()not in fold];forbidden=[];fresh=0
 for r in manifest:
  n=r['path'];data=new.read(n);assert len(data)==r['bytes']and hashlib.sha256(data).hexdigest()==r['sha256'].lower()
  if Path(n).suffix.casefold()in{'.exe','.dll','.bic','.bif','.key','.nwm','.hak','.mdl','.tga','.dds'}or re.search(r'(?:-live-v\d+\.json|interactive-v|network-renderer-control)',n)or n.startswith('runtime-logs/'):forbidden.append(n)
  if Path(n).suffix in{'.js','.mjs','.cjs','.py','.ps1','.json','.md','.txt','.html'}:
   old=previous.get(n.casefold());old_data=old[0].read(old[1]['path'])if old else b'';fresh+=len({v for p in patterns for v in p.findall(data)}-{v for p in patterns for v in p.findall(old_data)})
  if Path(n).name.startswith('local-network-'):
   report=json.loads(data);assert report['states'][-1]['phase']=='closed'
 for z in parent_zips:z.close()
 result=dict(entries=len(names),verifiedFiles=len(manifest),parentsVerified=len(chain['parents']),required=len(required),missing=missing,forbidden=len(forbidden),duplicates=len(names)-len(fold),newCredentialCandidates=fresh);print(json.dumps(result,indent=2));assert not missing and not forbidden and len(names)==len(fold)and fresh==0
