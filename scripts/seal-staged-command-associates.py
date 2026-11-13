"""Seal the accepted new Commands policy/adapter without changing imported producers."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib,json
root=Path(__file__).resolve().parents[1];project=root/'godot-client'
run=project/'.cache/staged-command-associates/20261103101436364-fc497d90'
receipt=json.loads((run/'runner.json').read_text());assert receipt['success'] and not receipt['changedInputs']
sha=lambda data:hashlib.sha256(data).hexdigest()
destination=project/'.cache/staged-command-associates/sealed-v1';destination.mkdir()
files={}
for entry in receipt['inputs']:
    data=(run/'inputs'/entry['path']).read_bytes();assert sha(data)==entry['sha256'],entry['path']
    assert sha((root/entry['path']).read_bytes())==entry['sha256'],entry['path']
    files['accepted-inputs/'+entry['path']]=data
for file in run.iterdir():
    if file.is_file():files['evidence/accepted/'+file.name]=file.read_bytes()
for name in ['20261103101330088-919d5c24','20261103101348184-7885510d']:
    folder=run.parent/name
    for file in folder.iterdir():
        if file.is_file():files['evidence/rejected/'+name+'/'+file.name]=file.read_bytes()
    for entry in json.loads((folder/'runner.json').read_text())['inputs']:
        if 'native_command_associate' in entry['path'] or entry['path'].endswith('staged_command_associates.gd'):
            data=(folder/'inputs'/entry['path']).read_bytes();assert sha(data)==entry['sha256']
            files['evidence/rejected/'+name+'/inputs/'+entry['path']]=data
for name in ['godot-client/NATIVE-COMMAND-ASSOCIATES-STAGED.md','scripts/seal-staged-command-associates.py','scripts/inspect-native-command-associate-ownership.py','godot-client/reports/native-command-associate-ownership-unwind-v1.json','godot-client/reports/native-command-associate-ownership-unwind-v1.failure.json']:
    files['owned/'+name]=(root/name).read_bytes()
manifest={'success':True,'productionIntegrated':False,'deferredUserProcess':53284,'checks':{'policy':6772,'nativePointer':17,'controlledPeer':37,'total':6826},'originalCases':{'v1':80,'v2':96,'signedCallbacks':18},'acceptedSourcePins':len(receipt['inputs']),'scope':'New staged scalar policy and test-only Desktop integration. Original PE menu/query/callback comparisons and actual native input -> unchanged Session -> controlled peer. No server/login/socket/GPU/user-process action. Normal world five rows preserved; DM executable remains separately unbound.','files':[{'path':name,'bytes':len(data),'sha256':sha(data)} for name,data in sorted(files.items())]}
files['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
archive=destination/'native-command-associates-staged-v1.zip'
with ZipFile(archive,'x',compression=ZIP_DEFLATED,compresslevel=5) as output:
    for name,data in sorted(files.items()):output.writestr(name,data)
with ZipFile(archive) as output:
    assert set(output.namelist())==set(files)
    for name,data in files.items():assert sha(output.read(name))==sha(data),name
proof={'success':True,'productionIntegrated':False,'archive':str(archive.relative_to(project)).replace('\\','/'),'sha256':sha(archive.read_bytes()),'bytes':archive.stat().st_size,'entries':len(files),'readbackVerified':True,'manifest':manifest}
(project/'reports/native-command-associates-staged-v1.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps({key:value for key,value in proof.items() if key!='manifest'}))
