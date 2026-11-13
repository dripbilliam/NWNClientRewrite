"""Seal exact accepted staged tail inputs/receipts; never package native assets.

This checkpoint is not a release, production integration or live-client proof.
Only sources from successful copied closures, authored tests/oracles, sanitized
logs, and documentation are included. Owned original LTR capture-gap bytes,
installed assets, protected profiles, user data and native outputs are excluded.
"""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
project=root/'godot-client'
hash_bytes=lambda data:hashlib.sha256(data).hexdigest()
cases=[
 ('names',project/'.cache/creation-character-names/character-names-routing-v3'),
 ('names-owner',project/'.cache/creation-character-names-owner/character-names-owner-v2'),
 ('active-provider',project/'.cache/creation-tail-provider/tail-provider-active-v6'),
 ('information-input',project/'.cache/creation-character-info-view/character-info-name-readiness-v5'),
 ('font-geometry',project/'.cache/creation-tail-text-geometry/tail-real-font-current-provider-v3')]
files={};acceptance=[]
def add(name,data):
 if name in files:assert files[name]==data,('Conflicting accepted source',name)
 files[name]=data
for label,directory in cases:
 proof=json.loads((directory/'proof.json').read_text())
 assert proof['success'] and proof['cleanEngine'] and proof['exitCode']==0 and not proof['changedInputs'] and not proof['error'],label
 for item in proof['inputs']:
  path=Path(item['path']);assert not path.is_absolute() and '..' not in path.parts
  data=(directory/'inputs'/path).read_bytes();assert hash_bytes(data)==item['sha256'],item['path']
  add('accepted-inputs/'+path.as_posix(),data)
 for file in ['proof.json','result.json','engine.log','stdout.log','stderr.log']:add('receipts/'+label+'/'+file,(directory/file).read_bytes())
 acceptance.append({'case':label,'checks':proof['checks'],'proofSha256':hash_bytes((directory/'proof.json').read_bytes()),'directory':directory.relative_to(root).as_posix()})
for relative in [
 'godot-client/NATIVE-CREATION-APPEARANCE-INFO.md',
 'scripts/seal-native-creation-tail-provider.py',
 'godot-client/reports/native-creation-tail-field-getters-original-v1.json',
 'godot-client/reports/native-creation-tail-typed-owners-original-v1.json',
 'godot-client/reports/native-creation-tail-callbacks-original-v1.json',
 'godot-client/reports/native-creation-tail-string-name-original-v1.json',
 'godot-client/reports/native-creation-tail-name-routing-original-v1.json',
 'godot-client/reports/native-two-da-missing-token-original-v1.json',
 'godot-client/reports/native-creation-voice-metadata-original-v1.json',
 'godot-client/reports/native-creation-voice-tab-index-original-v1.json']:
 add('support/'+relative,(root/relative).read_bytes())
current=[]
for name,data in files.items():
 if name.startswith('accepted-inputs/'):
  relative=name.removeprefix('accepted-inputs/');actual=root/relative
  current.append({'path':relative,'sameCurrent':actual.is_file() and hash_bytes(actual.read_bytes())==hash_bytes(data)})
assert all(row['sameCurrent'] for row in current),'Current input diverged before sealing; do not rewrite history'
manifest={'scope':__doc__,'integrated':False,'liveClientValidated':False,'gpu':False,'serverConnections':0,'nativeBuilds':0,'checks':sum(row['checks'] for row in acceptance),'cases':acceptance,'originalRoutingCases':446,'entries':[{'path':name,'bytes':len(data),'sha256':hash_bytes(data)} for name,data in sorted(files.items())],'currentInputs':current,'remaining':['Shipping creator/frontend providers and private preview/audio binding','Parsed BIC source body/head WORD and typed outfit preservation','Composed Appearance-to-Information-to-main completion/cancel','Selected swatch and actual 3D/audio/pixel acceptance','Arbitrary Unicode/locale input parity']}
manifest_data=(json.dumps(manifest,indent=2)+'\n').encode();add('checkpoint.json',manifest_data)
output=root/'backups/native-creation-tail-provider-after-v1.zip';assert not output.exists(),'Preserve earlier checkpoints'
with zipfile.ZipFile(output,'x',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
 for name,data in sorted(files.items()):archive.writestr(name,data)
with zipfile.ZipFile(output) as archive:
 assert len(archive.infolist())==len(files)
 for name,data in files.items():assert archive.read(name)==data,name
receipt={'success':True,'zip':output.relative_to(root).as_posix(),'sha256':hash_bytes(output.read_bytes()),'bytes':output.stat().st_size,'entries':len(files),'manifestSha256':hash_bytes(manifest_data),'acceptedChecks':manifest['checks'],'originalRoutingCases':446,'integrated':False,'liveClientValidated':False,'currentInputsMatching':len(current),'gpu':False,'serverConnections':0,'nativeBuilds':0}
receipt_path=project/'reports/native-creation-tail-provider-v1-checkpoint.json';assert not receipt_path.exists(),'Preserve prior receipt';receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))
