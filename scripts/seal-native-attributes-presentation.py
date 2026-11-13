"""Seal exact copied acceptance and failure inputs; no current-source rollback,
installed assets, credential material or native binaries are archived.
"""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1];project=root/'godot-client'
cases={
 'real-font-input42':project/'.cache/creation-attributes-text-geometry/attributes-real-font-input-v4',
 'original-rules2690':project/'.cache/creation-ability-rule-regression/attributes-original-rules-v1',
 'before-title-failure16':project/'.cache/creation-attributes-text-geometry/attributes-text-before-v1',
 'fixture-arity-rejection':project/'.cache/creation-attributes-text-geometry/attributes-text-order-hook-v2',
}
def sha(data):return hashlib.sha256(data).hexdigest()
files={};summaries={}
for label,directory in cases.items():
 proof=json.loads((directory/'proof.json').read_text());summaries[label]={'success':proof['success'],'checks':proof['checks'],'cleanEngine':proof['cleanEngine'],'exitCode':proof['exitCode'],'proofSha256':sha((directory/'proof.json').read_bytes()),'scope':proof['scope']}
 if label in ['real-font-input42','original-rules2690']:assert proof['success']and proof['cleanEngine']and not proof['changedInputs']
 for row in proof['inputs']:
  source=directory/'inputs'/row['path'];data=source.read_bytes();assert sha(data)==row['sha256'],str(source)
  assert source.suffix.lower()not in ['.exe','.dll','.dpapi','.key'],str(source)
  files[f'{label}/inputs/{row["path"]}']=data
 for name in ['proof.json','result.json','engine.log','stdout.log','stderr.log']:
  source=directory/name
  if source.exists():files[f'{label}/receipts/{name}']=source.read_bytes()
notes={'scope':'Attributes presentation only: original layer order/name hook/claimed Title, real installed fonts+CPU atlas ink, physical controls and unchanged ability rules. No GPU/live-server/user-client validation.','acceptedChecks':2732,'cases':summaries,'metadataNotes':['original-rules2690/proof.scope was a template description error; actual native_creation_ability_points_test.gd and immutable1344-action corpus identify the accepted rule test. Original receipt/input bytes are retained.','The first real-font baseline contains no sibling-layer/ink checks; title failure and actual numeric text/fonts were observed before the new coverage was added. The current case explicitly checks the row draw order.'],'productionOwners':['godot-client/systems/native_attributes_chooser.gd','godot-client/systems/native_data/creation_attributes_layout.gd'],'rulesChanged':False,'gpu':False,'serverConnections':0,'nativeBuilds':0}
files['ACCEPTANCE.json']=(json.dumps(notes,indent=2)+'\n').encode()
manifest={name:sha(data)for name,data in files.items()};files['MANIFEST.json']=(json.dumps(manifest,indent=2)+'\n').encode()
target=root/'backups/native-attributes-presentation-after-v1.zip'
if target.exists():raise RuntimeError('Existing checkpoint preserved')
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=9)as archive:
 for name,data in files.items():archive.writestr(name,data)
with zipfile.ZipFile(target)as archive:
 assert len(archive.namelist())==len(files)
 for name,data in files.items():assert archive.read(name)==data,name
result={'success':True,'archive':str(target.relative_to(root)).replace('\\','/'),'sha256':sha(target.read_bytes()),'entries':len(files),'bytes':target.stat().st_size,'manifestSha256':sha(files['MANIFEST.json']),'acceptedChecks':2732,'cases':summaries,'scope':notes['scope']}
output=project/'reports/native-attributes-presentation-v1-checkpoint.json'
if output.exists():raise RuntimeError('Existing checkpoint receipt preserved')
output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
