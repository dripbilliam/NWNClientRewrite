"""Seal current staged typed-tail and non-P dependency evidence.

Exact copied source inputs and authored BIC/UTI fixtures only; no installed game
assets, profiles, user data, original binary, native outputs or running processes.
This is not shipping builder/creator/server integration acceptance.
"""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1];project=root/'godot-client'
digest=lambda data:hashlib.sha256(data).hexdigest()
files={};cases=[]
def add(name,data):
 if name in files:assert files[name]==data,('Conflicting exact accepted inputs',name)
 files[name]=data
for label,relative in [
 ('typed-bic','.cache/creation-tail-bic/typed-tail-bic-v3'),
 ('nonp-provider','.cache/creation-tail-provider/tail-provider-nonp-v7'),
 ('nonp-input','.cache/creation-nonp-appearance/nonp-source-input-v1')]:
 directory=project/relative;proof=json.loads((directory/'proof.json').read_text())
 assert proof['success'] and proof['cleanEngine'] and proof['exitCode']==0 and not proof['changedInputs'] and not proof['error'] and not proof.get('independentError'),label
 for item in proof['inputs']:
  path=Path(item['path']);assert not path.is_absolute() and '..' not in path.parts
  data=(directory/'inputs'/path).read_bytes();assert digest(data)==item['sha256'];assert digest((root/path).read_bytes())==item['sha256'],item['path']
  add('accepted-inputs/'+path.as_posix(),data)
 for name in ['proof.json','result.json','engine.log','stdout.log','stderr.log']:add('receipts/'+label+'/'+name,(directory/name).read_bytes())
 if label=='typed-bic':
  for extension in ['.bic','.uti']:add('authored-fixtures/typed-tail'+extension,(directory/('result.json'+extension)).read_bytes())
 cases.append({'case':label,'checks':proof['checks'],'nativeChecks':proof.get('nativeChecks',proof['checks']),'independentChecks':proof.get('independentChecks',0),'proofSha256':digest((directory/'proof.json').read_bytes())})
for relative in [
 'scripts/seal-native-creation-tail-bic.py',
 'godot-client/NATIVE-CREATION-TAIL-BIC.md',
 'godot-client/NATIVE-CREATION-APPEARANCE-INFO.md',
 'godot-client/reports/native-creation-tail-save-owners-original-v1.json',
 'godot-client/reports/native-creation-tail-client-item-save-original-v1.json',
 'godot-client/reports/native-creation-tail-save-labels-original-v1.json',
 'godot-client/reports/native-creation-tail-buffer-save-original-v1.json',
 'godot-client/reports/native-creation-nonp-head-check-original-v1.json']:
 add('support/'+relative,(root/relative).read_bytes())
manifest={'scope':__doc__,'checks':sum(case['checks'] for case in cases),'cases':cases,'originalObservations':{'wordAndByte':40,'clientAppearanceSlices':12,'itemAppearanceSlices':12},'integrated':False,'liveClientValidated':False,'gpu':False,'serverConnections':0,'nativeBuilds':0,'entries':[{'path':name,'bytes':len(data),'sha256':digest(data)} for name,data in sorted(files.items())],'limitations':['Not a complete original client save','Tail/wings remain unavailable when owner omitted them','Private UTI overlay is never the first-level equipped row','Shipping source-tail flag and creator/preview/audio/builder still root-owned','No live or authoritative server admission claim']}
body=(json.dumps(manifest,indent=2)+'\n').encode();add('checkpoint.json',body)
output=root/'backups/native-creation-tail-bic-after-v1.zip';assert not output.exists(),'Preserve prior checkpoint'
with zipfile.ZipFile(output,'x',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
 for name,data in sorted(files.items()):archive.writestr(name,data)
with zipfile.ZipFile(output) as archive:
 assert len(archive.infolist())==len(files)
 for name,data in files.items():assert archive.read(name)==data,name
receipt={'success':True,'zip':output.relative_to(root).as_posix(),'sha256':digest(output.read_bytes()),'bytes':output.stat().st_size,'entries':len(files),'manifestSha256':digest(body),'acceptedChecks':manifest['checks'],'originalObservations':64,'integrated':False,'liveClientValidated':False,'gpu':False,'serverConnections':0,'nativeBuilds':0}
path=project/'reports/native-creation-tail-bic-v1-checkpoint.json';assert not path.exists(),'Preserve receipt';path.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
