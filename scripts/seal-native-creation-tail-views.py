"""Seal the deferred source views' exact accepted font/input copies and the
preserved before-presentation failure. No live source rollback or installed
asset/credential/native-binary archive is performed.
"""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1];project=root/'godot-client'
cases={
 'tail-real-font66':project/'.cache/creation-tail-text-geometry/tail-real-font-title-order-v2',
 'appearance-input23':project/'.cache/creation-appearance-view/appearance-title-order-input-v6',
 'character-info-input21':project/'.cache/creation-character-info-view/character-info-title-input-v3',
 'before-tail-font66-failure9':project/'.cache/creation-tail-text-geometry/tail-real-font-before-v1',
}
def sha(data):return hashlib.sha256(data).hexdigest()
files={};summaries={}
for name,directory in cases.items():
 proof=json.loads((directory/'proof.json').read_text());summaries[name]={'success':proof['success'],'checks':proof['checks'],'cleanEngine':proof['cleanEngine'],'exitCode':proof['exitCode'],'proofSha256':sha((directory/'proof.json').read_bytes()),'scope':proof['scope']}
 if not name.startswith('before-'):assert proof['success']and proof['cleanEngine']and not proof['changedInputs']
 for row in proof['inputs']:
  source=directory/'inputs'/row['path'];data=source.read_bytes();assert sha(data)==row['sha256'],str(source)
  assert source.suffix.lower()not in ['.exe','.dll','.dpapi','.key']
  files[f'{name}/inputs/{row["path"]}']=data
 for part in ['proof.json','result.json','engine.log','stdout.log','stderr.log']:
  source=directory/part
  if source.exists():files[f'{name}/receipts/{part}']=source.read_bytes()
notes={'acceptedChecks':110,'cases':summaries,'integrated':False,'scope':'Deferred Appearance/Character Information source views only: original owner-specific Title bounds, real FontFile/atlas ink, row paint order and physical scoped controls. Creator/frontend/active provider/BIC/3D/audio/server integration is pending.','nativeBuilds':0,'gpu':False,'serverConnections':0}
files['ACCEPTANCE.json']=(json.dumps(notes,indent=2)+'\n').encode()
files['MANIFEST.json']=(json.dumps({name:sha(data)for name,data in files.items()},indent=2)+'\n').encode()
target=root/'backups/native-creation-tail-views-after-v1.zip'
if target.exists():raise RuntimeError('Existing checkpoint preserved')
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=9)as archive:
 for name,data in files.items():archive.writestr(name,data)
with zipfile.ZipFile(target)as archive:
 assert len(archive.namelist())==len(files)
 for name,data in files.items():assert archive.read(name)==data,name
result={'success':True,'archive':str(target.relative_to(root)).replace('\\','/'),'sha256':sha(target.read_bytes()),'entries':len(files),'bytes':target.stat().st_size,'manifestSha256':sha(files['MANIFEST.json']),'acceptedChecks':110,'cases':summaries,'integrated':False,'scope':notes['scope']}
output=project/'reports/native-creation-tail-views-v1-checkpoint.json'
if output.exists():raise RuntimeError('Existing receipt preserved')
output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
