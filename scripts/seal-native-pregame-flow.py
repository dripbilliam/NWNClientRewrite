"""Seal actual24 pregame flow, current571 closure and exact session delta."""
from pathlib import Path
import datetime, difflib, hashlib, json, zipfile

ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'godot-client'
r=json.loads((PROJECT/'reports/native-pregame-flow-v1-receipt.json').read_text(encoding='utf-8-sig'))
assert r['success'] and not r['checkOnly'] and r['checks']==24 and r['cleanEngine'] and r['exitCode']==0
assert not r['timedOut'] and not r['changedInputs'] and not r['changedCopiedInputs']
run=Path(r['directory']).resolve()
assert run.is_relative_to(PROJECT/'.cache/pregame-navigation-tests')
sha=lambda b:hashlib.sha256(b).hexdigest()
entries={}
def add(name,data):
    assert name not in entries and not Path(name).is_absolute() and '..' not in Path(name).parts
    entries[name]=data
current_differences=[]
closure=set(r['staticClosure'])
for row in r['inputs']:
    copied=run/'project'/row['path'];data=copied.read_bytes()
    assert sha(data)==row['sha256'],row['path']
    current=sha((PROJECT/row['path']).read_bytes())
    if current!=row['sha256']:current_differences.append({'path':row['path'],'acceptedSha256':row['sha256'],'currentSha256':current,'inStaticClosure':row['path'] in closure})
    add('accepted-inputs/godot-client/'+row['path'],data)
before=PROJECT/'.cache/pregame-navigation-tests/20261103-063831-before'
old=(before/'native_session_world.gd').read_bytes()
new=(run/'project/native_session_world.gd').read_bytes()
text=new.decode().replace('\r\n','\n')
start=text.index('func creation_entry_current(');end=text.index('func open_chat_settings()',start)
text=text[:start]+text[end:]
text=text.replace('var pending_creator: Dictionary={}\nvar creation_request_serial:=0','var pending_creator:=false',1)
old_binding=next(line for line in old.decode().splitlines() if 'character_lobby.creation_requested.connect(' in line)
text=text.replace('\tcharacter_lobby.creation_requested.connect(request_creation)',old_binding,1)
text=text.replace('\tif not pending_creator.is_empty():open_pending_creation()','\tif pending_creator and is_instance_valid(gameplay_ui) and not closing:\n\t\tpending_creator=false; gameplay_ui.creator.open(session_connection)',1)
text=text.replace('\t\t\tif not pending_creator.is_empty() and not creation_entry_current(int(pending_creator.connection)):pending_creator.clear()\n','',1)
text=text.replace('\tpending_creator.clear()\n\tloading_announced=false','\tpending_creator=false\n\tloading_announced=false',1)
assert text==old.decode().replace('\r\n','\n'),'Session delta exceeds approved entry reservation'
add('dirty-before/native_session_world.gd',old);add('dirty-before/before.json',(before/'before.json').read_bytes())
add('session-entry-only.patch',''.join(difflib.unified_diff(old.decode().splitlines(True),new.decode().splitlines(True),fromfile='dirty-before/native_session_world.gd',tofile='accepted24/native_session_world.gd')).encode())
for p in run.iterdir():
    if p.is_file():add('accepted-run/'+p.name,p.read_bytes())
add('accepted-run/project.godot',(run/'project/project.godot').read_bytes())
for folder in ['20261103-065223-72e2d0b2','20261103-065354-e6a158c7','20261103-065422-c377706b','20261103-065751-e0584f9b','20261103-070917-c477b82f']:
    source=PROJECT/'.cache/pregame-navigation-tests'/folder
    for p in source.iterdir():
        if p.is_file():add('preserved-evidence/'+folder+'/'+p.name,p.read_bytes())
    add('preserved-evidence/'+folder+'/native_pregame_flow_test.gd',(source/'project/tests/native_pregame_flow_test.gd').read_bytes())
add('evidence/NATIVE-PREGAME-FLOW.md',(PROJECT/'NATIVE-PREGAME-FLOW.md').read_bytes())
add('sealer.py',Path(__file__).read_bytes())
manifest={'scope':'Actual24 composed native pregame entry/navigation with authored received replies and controlled presentation; current571 static closure at acceptance, copied source retained, no server/login/GPU/pixels/full-character/levelup acceptance. Root creator/frontend/host integration is not attributed to the session patch.',
          'checks':24,'staticClosure':sorted(closure),'copiedInputs':len(r['inputs']),'currentDifferences':current_differences,
          'sharedChange':{'path':'godot-client/native_session_world.gd','beforeSha256':sha(old),'acceptedSha256':sha(new)},
          'entries':[{'path':name,'bytes':len(data),'sha256':sha(data)} for name,data in sorted(entries.items())]}
add('manifest.json',(json.dumps(manifest,indent=2)+'\n').encode())
destination=PROJECT/'.cache/pregame-navigation-checkpoints'/(datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')+'-sealed24')
destination.mkdir(parents=True,exist_ok=False);archive=destination/'native-pregame-flow-v1.zip'
with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name,data in sorted(entries.items()):z.writestr(name,data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None and len(z.infolist())==len(entries)
    for name,data in entries.items():assert sha(z.read(name))==sha(data)
(destination/'manifest.json').write_bytes(entries['manifest.json'])
result={'success':True,'archive':str(archive.relative_to(ROOT)),'sha256':sha(archive.read_bytes()),'entries':len(entries),'bytes':archive.stat().st_size,'checks':24,'staticClosure':len(closure),'currentDifferences':current_differences,'sharedChange':manifest['sharedChange']}
(destination/'checkpoint.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
