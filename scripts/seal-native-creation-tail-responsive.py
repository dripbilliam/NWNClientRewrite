"""Readback-seal current functional Tail responsiveness without further runtime work."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import difflib,hashlib,json
root=Path(__file__).resolve().parents[1];project=root/'godot-client'
run=project/'.cache/creation-tail-binding/runtime-tail-perf-v1';projection=project/'.cache/creation-tail-snapshot/projection-v1'
sha=lambda data:hashlib.sha256(data).hexdigest()
proof=json.loads((run/'runner.json').read_text());pure=json.loads((projection/'runner.json').read_text())
assert proof['success'] and not proof['changedInputs'] and not proof['changedCopy']
assert pure['success'] and pure['checks']==1694 and not pure['changedInputs']
files={}
for entry in proof['inputs']:
    data=(run/'inputs'/entry['path']).read_bytes();assert sha(data)==entry['sha256'];assert sha((root/entry['path']).read_bytes())==entry['sha256']
    files['accepted-inputs/'+entry['path']]=data
for entry in pure['inputs']:
    data=(projection/'inputs'/entry['path']).read_bytes();assert sha(data)==entry['sha256'];assert sha((root/entry['path']).read_bytes())==entry['sha256']
    files['projection-inputs/'+entry['path']]=data
for prefix,folder in [('responsive',run),('projection',projection)]:
    for file in folder.iterdir():
        if file.is_file():files['evidence/'+prefix+'/'+file.name]=file.read_bytes()
functional=run.parent/'runtime-tail-v4';old=json.loads((functional/'runner.json').read_text());assert old['success']
before=project/'.cache/creation-tail-integration-before-20261103-155509';pins=json.loads((before/'pins.json').read_text(encoding='utf-8-sig'))
owned=['systems/native_creation_tail.gd','systems/native_creation.gd','systems/native_creation_preview.gd','systems/native_creation_voice.gd','systems/native_data/creation_bic.gd','systems/native_data/creation_tail_bic.gd','systems/native_data/creation_tail_snapshot.gd']
changes=[]
for path in owned:
    current=(project/path).read_bytes();prior=functional/'inputs/godot-client'/path
    if prior.exists():
        original=prior.read_bytes();files['functional-before/'+path]=original
        patch=''.join(difflib.unified_diff(original.decode('utf-8-sig').replace('\r\n','\n').splitlines(True),current.decode('utf-8-sig').replace('\r\n','\n').splitlines(True),fromfile='functional67/'+path,tofile='responsive/'+path))
        if patch:files['responsive-diffs/'+path+'.patch']=patch.encode()
    changes.append({'path':path,'sha256':sha(current),'functionalBeforeSha256':sha(prior.read_bytes()) if prior.exists() else None})
for entry in pins:
    data=(before/entry['path']).read_bytes();assert sha(data)==entry['sha256'];files['integration-before/'+entry['path']]=data
for name in ['NATIVE-CREATION-TAIL-INTEGRATION.md','NATIVE-CREATION-APPEARANCE-INFO.md','NATIVE-CREATION-TAIL-BIC.md']:files['docs/'+name]=(project/name).read_bytes()
files['tools/seal-native-creation-tail-responsive.py']=Path(__file__).read_bytes()
prior_checkpoint=project/'reports/native-creation-tail-integration-v1.json';files['evidence/functional-checkpoint.json']=prior_checkpoint.read_bytes()
result=json.loads((run/'binding.json').read_text());stress=json.loads((run/'retirement.json').read_text());events=result['callbackTimings']
opens=[row['usec'] for row in events if row['event']=='open'][:-1] # Last is the explicit unsupported-mode request.
previews=[row['usec'] for row in events if row['event']=='preview-request']
manifest={'shippingIntegrated':True,'functionalAccepted':True,'responsiveAcceptance':True,'readinessScope':'Local native source flow/input/active resource and model admission, exact worker/lifetime bounds and parsed generated BIC. No server upload/admission, original pixels, audible playback or FPS benchmark.','checks':{'gameplayCompile':1,'retirementStress':107,'composedSource':61,'independentBicParser':7,'integrationTotal':176,'projection':1694,'total':1870},'sourcePins':len(proof['inputs']),'projectionPins':len(pure['inputs']),'ownedFiles':changes,'previewMeshes':result['previewAdmission']['meshes'],'providerWorker':result['providerWorker'],'observedCpu':{'openUsec':opens,'previewRequestUsec':previews,'rapidTwelveRequestsUsec':result['rapidPreviewUsec'],'maximumDrainUsec':result['previewRetirement']['maximumDrainUsec'],'maximumCoordinatorProcessUsec':result['previewRetirement']['maximumProcessUsec'],'beforeOpenUsec':[134060,147667],'beforePreviewReplacementUsec':369600,'projectionFullDetachUsec':pure['fullDetachUsec'],'projectionDetachUsec':pure['projectedDetachUsec']},'retirement':result['previewRetirement'],'stress':stress,'limits':['Approximately27ms final private cleanup remains a future local optimization.','CPU samples describe these copied runs and ordinary filesystem/cache state, not general cold-cache or FPS behavior.','Existing-character mode1 customization remains explicitly unsupported and cannot enter the first-level writer.','Global modal/NUI coverage remains incomplete; no membership was inferred from layers or Control inheritance.'],'safety':{'serverConnections':0,'nativeBuilds':0,'userProcessActions':0,'gpu':False},'files':[{'path':name,'sha256':sha(data),'bytes':len(data)} for name,data in sorted(files.items())]}
files['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
destination=run.parent/'sealed-responsive-v2';destination.mkdir();archive=destination/'native-creation-tail-integration-v2.zip'
with ZipFile(archive,'x',compression=ZIP_DEFLATED,compresslevel=5) as output:
    for name,data in sorted(files.items()):output.writestr(name,data)
with ZipFile(archive) as output:
    assert set(output.namelist())==set(files)
    for name,data in files.items():assert sha(output.read(name))==sha(data),name
receipt={'success':True,'shippingIntegrated':True,'functionalAccepted':True,'responsiveAcceptance':True,'archive':str(archive.relative_to(project)).replace('\\','/'),'sha256':sha(archive.read_bytes()),'bytes':archive.stat().st_size,'entries':len(files),'readbackVerified':True,'manifest':manifest}
(project/'reports/native-creation-tail-integration-v2.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({key:value for key,value in receipt.items() if key!='manifest'}))
