import hashlib,json,re,sys,zipfile
from pathlib import Path
root=Path(__file__).resolve().parent.parent
archive=root/'backups'/(sys.argv[1]+'.zip')
required=re.findall(r"^ '([^']+)'[,]?$",(root/'scripts/checkpoint-renderer-fullscreen.ps1').read_text(),re.M)
patterns=[re.compile(rb'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b'),re.compile(rb'(?<![A-Za-z0-9])[A-HJ-NP-Z2-9]{35}(?![A-Za-z0-9])')]
with zipfile.ZipFile(archive) as new:
 names=new.namelist();manifest=json.loads(new.read('checkpoint-manifest.json'));chain=json.loads(new.read('checkpoint-chain.json'));previous={};parents=[]
 for record in chain['parents']:
  p=root/'backups'/record['archive'];assert p.parent==root/'backups';assert hashlib.sha256(p.read_bytes()).hexdigest()==record['sha256'].lower();z=zipfile.ZipFile(p);parents.append(z)
  for r in json.loads(z.read('checkpoint-manifest.json')):previous[r['path']]=(z,r['path'])
 secrets=0
 for r in manifest:
  n=r['path'];data=new.read(n);assert len(data)==r['bytes'] and hashlib.sha256(data).hexdigest()==r['sha256'].lower()
  assert Path(n).suffix.lower() not in {'.exe','.dll','.bic','.bif','.key','.nwm','.hak','.mdl','.tga','.dds','.wav','.bmu'}
  assert not n.startswith('runtime-logs/') and not re.search(r'(-live-v\d+\.json|interactive-v|network-renderer-control)',n)
  old=previous.get(n);before=old[0].read(old[1]) if old else b'';secrets+=len({v for p in patterns for v in p.findall(data)}-{v for p in patterns for v in p.findall(before)})
  if Path(n).name.startswith('local-network-'):assert json.loads(data)['states'][-1]['phase']=='closed'
 for z in parents:z.close()
 missing=sorted(set(required)-set(names));assert not missing and len(names)==len(set(n.casefold() for n in names)) and secrets==0
 print(json.dumps(dict(verifiedFiles=len(manifest),parentsVerified=len(chain['parents']),required=len(required),missing=missing,newCredentialCandidates=secrets)))
