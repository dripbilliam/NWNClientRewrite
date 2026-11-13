"""Seal a tested patch without importing it into the live user's worktree."""
from pathlib import Path
import difflib
import hashlib
import json
from zipfile import ZipFile, ZIP_DEFLATED

workspace=Path(__file__).resolve().parents[1]
project=workspace/'godot-client'
root=project/'.cache/picker-switch-responsiveness'
cases={'baseline':'20261103-091231-407672','staged_first':'20261103-091940-588274','policy':'20261103-092221-118684','worker_lifecycle':'20261103-092228-669625','staged_final':'20261103-092235-150589'}
destination=root/'sealed-staged-v1'
destination.mkdir()
sha=lambda data:hashlib.sha256(data).hexdigest()
files={}
receipts={}
for name,run in cases.items():
    folder=root/run
    receipt=json.loads((folder/'runner.json').read_text())
    assert receipt['success'] and not receipt['changedInputs'] and not receipt['changedCopiedInputs'] and not receipt['changedData']
    receipts[name]=receipt
    for path in folder.iterdir():
        if path.is_file():files[f'evidence/{name}/{path.name}']=path.read_bytes()
    for entry in receipt['inputs']:
        data=(folder/'project'/entry['path']).read_bytes()
        assert sha(data)==entry['instrumentedCopySha256'],entry['path']
        files[f'evidence/{name}/project/{entry["path"]}']=data
work_path='systems/native_data/character_picker_work.gd'
before=(project/work_path).read_bytes()
assert sha(before)=='5ffb265ec77616f1b83c8afc686f8c2d34f74381725f1d82855806e5e619eb6e'
normalized=before.decode('utf-8-sig').replace('\r\n','\n')
old='table_copies[name]={"orderedRows":tables[name].get("orderedRows",[]).duplicate(true)}; stats.table_copies+=1'
new='table_copies[name]=PickerSnapshot.capture_spells(tables[name],table_copies.get("classes",{})) if name=="spells" else {"orderedRows":tables[name].get("orderedRows",[]).duplicate(true)}; stats.table_copies+=1'
assert normalized.count(old)==1
after=normalized.replace('extends Node\n','extends Node\nconst PickerSnapshot=preload("res://systems/native_data/picker_table_snapshot.gd")\n',1).replace(old,new,1)
staged=(root/cases['staged_final']/'project'/work_path).read_text()
staged=staged.replace('var diagnostic_table_captures: Array=[]\n','',1)
staged=staged.replace('\t\t\tvar table_began:=Time.get_ticks_usec()\n','',1)
staged=staged.replace('\n\t\t\tif diagnostic_table_captures.size()<128:diagnostic_table_captures.append({"name":name,"us":Time.get_ticks_usec()-table_began,"rows":tables[name].get("orderedRows",[]).size()})','',1)
assert staged==after,'Tested staged runtime must equal the proposed patch after diagnostic-only timing removal'
after_bytes=after.replace('\n','\r\n').encode() if b'\r\n' in before else after.encode()
patch=''.join(difflib.unified_diff(normalized.splitlines(True),after.splitlines(True),fromfile='a/godot-client/'+work_path,tofile='b/godot-client/'+work_path))
files['patch/character_picker_work.before.gd']=before
files['patch/character_picker_work.after.gd']=after_bytes
files['patch/character_picker_work.patch']=patch.encode()
owned=['systems/native_data/picker_table_snapshot.gd','tests/native_picker_switch_responsiveness_test.gd','tests/native_picker_snapshot_clone_test.gd']
for relative in owned:files['new-files/'+relative]=(project/relative).read_bytes()
files['tools/profile-native-picker-switch.py']=(workspace/'scripts/profile-native-picker-switch.py').read_bytes()
files['tools/seal-staged-picker-switch.py']=Path(__file__).read_bytes()
for relative in owned[:2]:
    accepted=(root/cases['staged_final']/'project'/relative).read_bytes()
    assert accepted==(project/relative).read_bytes()
manifest={
 'kind':'staged-picker-switch-responsiveness-v1',
 'productionApplied':False,
 'deferredUserProcess':53284,
 'importedFileReservation':'Only CharacterPickerWork helper preload and spells-only capture assignment; no lobby, record, preview, session, protocol or renderer edit.',
 'beforeWorkSha256':sha(before),'proposedWorkSha256':sha(after_bytes),
 'helperSha256':sha((project/owned[0]).read_bytes()),
 'checks':{'actual_source_control_record':123,'canonical_physical_getters_and_isolation':26472,'existing_worker_lifecycle':48,'total_final':26643},
 'evidence':{name:str((root/run).relative_to(project)).replace('\\','/') for name,run in cases.items()},
 'observed_cpu':{'baseline_cold':{'callback_sync_us':35568,'snapshot_ms':34.598,'spells_copy_us':30945},'first_staged_cold':{'callback_sync_us':13934,'snapshot_ms':13.288,'spells_copy_us':11049},'final_staged_cold':{'callback_sync_us':17884,'snapshot_ms':17.202,'spells_copy_us':14009},'final_warm_callback_sync_us':[788,1297]},
 'scope':'Observed copied-source CPU phases with actual default native Controls, original installed source assets/fonts, three previously received server-vault BIC tickets and authored exact acknowledgments. Complete projection equality checked. User client remained open; no GPU/FPS, live network latency or live-window improvement claim.',
 'safety':{'publicConnections':0,'nativeBuilds':0,'userProcessTouched':False,'mainImportedWorkChanged':False},
 'semantics':'Every physical spell row and every active class SpellTableColumn retained from the already-detached classes snapshot. Case precedence, absent fields, future classes/book IDs and nested/packed mutation isolation preserved. All other table snapshots unchanged.',
 'data':'Private captured BIC/resource bytes remain in their pre-existing fixture directory; archive includes hashes and derived measurements, not raw character files.',
 'limits':['Staged only: root applies the reviewed hash-guarded patch after the user finishes with the open client.','Cold work is reduced, not eliminated; resource-publication/reconnect capture still has a one-time cost.','No renderer/FPS or current-server delay claim.','Historical1295 modifier corpus was not rerun in the48-case focused worker regression.'],
 'files':[{'path':name,'sha256':sha(data),'bytes':len(data)} for name,data in sorted(files.items())]
}
files['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
archive=destination/'native-picker-switch-staged-v1.zip'
with ZipFile(archive,'x',compression=ZIP_DEFLATED,compresslevel=5) as output:
    for name,data in sorted(files.items()):output.writestr(name,data)
with ZipFile(archive) as output:
    assert set(output.namelist())==set(files)
    for name,data in files.items():assert sha(output.read(name))==sha(data),name
for name,data in files.items():
    if name.startswith('patch/'):(destination/Path(name).name).write_bytes(data)
receipt={'success':True,'staged':True,'productionApplied':False,'archive':str(archive.relative_to(project)).replace('\\','/'),'sha256':sha(archive.read_bytes()),'entries':len(files),'bytes':archive.stat().st_size,'readbackVerified':True,'manifest':manifest}
(project/'reports/native-picker-switch-staged-v1.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({key:value for key,value in receipt.items() if key!='manifest'},indent=2))
