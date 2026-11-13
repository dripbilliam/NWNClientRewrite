"""Seal exact functional runtime Tail acceptance before responsiveness follow-up."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import difflib,hashlib,json
root=Path(__file__).resolve().parents[1];project=root/'godot-client';run=project/'.cache/creation-tail-binding/runtime-tail-v4'
receipt=json.loads((run/'runner.json').read_text());assert receipt['success'] and not receipt['changedInputs'] and not receipt['changedCopy']
sha=lambda data:hashlib.sha256(data).hexdigest()
files={}
for entry in receipt['inputs']:
    data=(run/'inputs'/entry['path']).read_bytes();assert sha(data)==entry['sha256'];assert sha((root/entry['path']).read_bytes())==entry['sha256']
    files['accepted-inputs/'+entry['path']]=data
for version in [1,2,3,4]:
    folder=run.parent/f'runtime-tail-v{version}'
    for file in folder.iterdir():
        if file.is_file():files[f'evidence/v{version}/'+file.name]=file.read_bytes()
before=project/'.cache/creation-tail-integration-before-20261103-155509'
pins=json.loads((before/'pins.json').read_text(encoding='utf-8-sig'))
diffs=[]
for entry in pins:
    old=(before/entry['path']).read_bytes();assert sha(old)==entry['sha256']
    new=(project/entry['path']).read_bytes();files['before/'+entry['path']]=old
    patch=''.join(difflib.unified_diff(old.decode('utf-8-sig').replace('\r\n','\n').splitlines(True),new.decode('utf-8-sig').replace('\r\n','\n').splitlines(True),fromfile='a/godot-client/'+entry['path'],tofile='b/godot-client/'+entry['path']))
    files['diffs/'+entry['path']+'.patch']=patch.encode();diffs.append({'path':entry['path'],'beforeSha256':sha(old),'afterSha256':sha(new)})
for path in ['scripts/seal-native-creation-tail-integration.py','godot-client/NATIVE-CREATION-TAIL-INTEGRATION.md']:files['owned/'+path]=(root/path).read_bytes()
result=json.loads((run/'binding.json').read_text())
manifest={'shippingIntegrated':True,'functionalAccepted':True,'responsiveAcceptance':False,'checks':67,'sourcePins':len(receipt['inputs']),'diffs':diffs,'newRuntime':'systems/native_creation_tail.gd','tailBicHelperChange':'Header comment only; the sealed typed helper is now imported for verified source transactions.','preview':{'ready':result['previewAdmission']['ready'],'meshes':result['previewAdmission']['meshes'],'providerWorker':result['providerWorker']},'callbackTimings':result['callbackTimings'],'scope':'Runtime automatic CG_MAIN entry and physical Package prerequisite chain -> Customize source Appearance -> Information -> Main/actual summary -> worker-generated typed BIC, independent parser, active TYPE2 voice, exact private/stale/Cancel/class-skill-feat guards and explicit mode1 no-save rejection. No pixel/audio playback/server admission/FPS claim.','knownLimit':'Functional checkpoint only: main deep table capture134-148ms; native preview replacement can synchronously drain workers369.6ms. Owned bounded retirement and metadata-preserving projection follow-up remains required before responsive-ready claim.','safety':{'serverConnections':0,'nativeBuilds':0,'userProcessActions':0,'gpu':False},'files':[{'path':name,'sha256':sha(data),'bytes':len(data)} for name,data in sorted(files.items())]}
files['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
destination=run.parent/'sealed-functional-v1';destination.mkdir();archive=destination/'native-creation-tail-integration-v1.zip'
with ZipFile(archive,'x',compression=ZIP_DEFLATED,compresslevel=5) as output:
    for name,data in sorted(files.items()):output.writestr(name,data)
with ZipFile(archive) as output:
    assert set(output.namelist())==set(files)
    for name,data in files.items():assert sha(output.read(name))==sha(data),name
proof={'success':True,'shippingIntegrated':True,'functionalAccepted':True,'responsiveAcceptance':False,'archive':str(archive.relative_to(project)).replace('\\','/'),'sha256':sha(archive.read_bytes()),'bytes':archive.stat().st_size,'entries':len(files),'readbackVerified':True,'manifest':manifest}
(project/'reports/native-creation-tail-integration-v1.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps({key:value for key,value in proof.items() if key!='manifest'}))
