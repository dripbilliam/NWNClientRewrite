"""Independent incremental archive chain, entry hashes, scope and secret audit."""
import hashlib,json,re,sys,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1];name=sys.argv[1];assert re.fullmatch('[a-z0-9-]+',name)
patterns=[re.compile(rb'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b'),re.compile(rb'(?<![A-Za-z0-9])[A-HJ-NP-Z2-9]{35}(?![A-Za-z0-9])')]
required=["src/renderer_light_slots.js","src/main.js","test/renderer-light-slots.test.js","test/renderer-shadow-budget.test.js","scripts/renderer-light-slots-fixture.html","scripts/renderer-light-slots-fixture.mjs","scripts/smoke-renderer-light-slots.cjs","scripts/probe-network-renderer.cjs","scripts/checkpoint-renderer-light.ps1","scripts/audit-renderer-light-checkpoint.py","evidence/renderer-light-capacity.md","backups/animations/renderer-light-capacity-tests-v2.txt","backups/animations/renderer-light-capacity-build-v1.txt","backups/animations/renderer-light-capacity-gpu-v2.json"]
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
