"""Verify the live follow-up archive, sealed reports and base-chain identity."""
import hashlib,json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=root/'backups/multiplayer-attack-feedback-20261019-v1.zip'
patterns=[re.compile(rb'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b'),re.compile(rb'(?<![A-Za-z0-9])[A-HJ-NP-Z2-9]{35}(?![A-Za-z0-9])')]
required=['scripts/probe-network-renderer.cjs','test/network-attack-feedback.test.js','evidence/multiplayer-attack-feedback.md','backups/animations/local-network-attack-feedback-v119.json','backups/animations/network-attack-feedback-captured-v119.json','backups/animations/network-attack-feedback-acceptance-v1.json']
with zipfile.ZipFile(base)as old,zipfile.ZipFile(root/'backups/multiplayer-attack-feedback-live-20261019-v1.zip')as new:
 chain=json.loads(new.read('checkpoint-chain.json'));assert hashlib.sha256(base.read_bytes()).hexdigest()==chain['baseSha256'].lower()
 prior={r['path'].casefold():r for r in json.loads(old.read('checkpoint-manifest.json'))};manifest=json.loads(new.read('checkpoint-manifest.json'));names=new.namelist();fold={n.casefold()for n in names};missing=[n for n in required if n.casefold()not in fold];forbidden=[];fresh=0
 for record in manifest:
  n=record['path'];data=new.read(n);assert len(data)==record['bytes']and hashlib.sha256(data).hexdigest()==record['sha256'].lower()
  if Path(n).suffix.casefold()in{'.exe','.dll','.bic','.bif','.key','.nwm','.hak','.mdl','.tga','.dds'}or '-live-v' in n or 'interactive-v' in n or 'network-renderer-control' in n or n.startswith('runtime-logs/'):forbidden.append(n)
  if Path(n).suffix.casefold()in{'.js','.cjs','.mjs','.py','.ps1','.json','.md','.txt'}:
   previous=prior.get(n.casefold());previous_data=old.read(previous['path'])if previous else b'';fresh+=len({v for p in patterns for v in p.findall(data)}-{v for p in patterns for v in p.findall(previous_data)})
 for version in [117,118,119]:
  report=json.loads(new.read(f'backups/animations/local-network-attack-feedback-v{version}.json'));assert report['states'][-1]['phase']=='closed'
  if version==119:assert not report.get('failure')and not report.get('sampleFailure')and not report.get('controlFailure')
 report_bytes=new.read('backups/animations/local-network-attack-feedback-v119.json');compact=json.loads(new.read('backups/animations/network-attack-feedback-captured-v119.json'));assert hashlib.sha256(report_bytes).hexdigest()==compact['source']['sha256']
 result=dict(entries=len(names),verifiedFiles=len(manifest),baseChainVerified=True,sealedReports=3,required=len(required),missing=missing,forbidden=len(forbidden),duplicates=len(names)-len(fold),newCredentialCandidates=fresh);print(json.dumps(result,indent=2));assert not missing and not forbidden and len(names)==len(fold)and fresh==0
