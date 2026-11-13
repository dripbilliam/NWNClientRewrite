"""Unchanged full Gob::Animate: prior-view/light-exemption clock behavior.

Derives only lower-provider/reset variants from the retained independent clock
harness. Original Gob machine instructions are untouched. Scene-less outer
gate stays open; view-volume virtual result is an explicit per-frame provider.
No scene traversal/BSP/live room or cost claim. Never run during FPS hold.
"""
from pathlib import Path
import hashlib, json, sys
root = Path(__file__).resolve().parents[5]
sys.path.insert(0,str(root/'scripts'))
source_file = root/'scripts/inspect-native-model-run-clock.py'
source = source_file.read_text()
source = source[:source.index('rows=[run(')]
def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old,new)
source = replace_once(source,"u.mem_write(model+0x92,b'\\1')","u.mem_write(model+0x92,bytes([c.get('source_flags',1)]))")
source = replace_once(source,'elif a==m.stop+0x30:m.finish(0)',"elif a==m.stop+0x30:m.finish(c.get('view_sequence',[0])[min(c.get('_frame_index',0),len(c.get('view_sequence',[0]))-1)])")
source = replace_once(source,"m.wi(gob+0xe8,len(c['initial']))","m.wi(gob+0xf0,c.get('light_exemption_f0',0));m.wi(gob+0xe8,len(c['initial']))")
source = replace_once(source,"for delta in c['deltas']:","for index,delta in enumerate(c['deltas']):\n  c['_frame_index']=index")
namespace={'__name__':'owned_clock_exemption_boundary'}
exec(compile(source,str(source_file), 'exec'),namespace)
run, profile, entry = [namespace[k] for k in ('run','profile','entry')]
rows=[]
for flags,f0,view in [(0,0,0),(2,0,0),(4,0,0),(8,0,0),(1,0,0),(4,1,0),(4,7,0),(4,0,1),(2,1,0),(8,1,0)]:
    case=profile([entry(time=.1,previous=.025,length=10)],deltas=[.1,.1],source_flags=flags,light_exemption_f0=f0,view_sequence=[view,view])
    observed=run(case);gate=bool(view or f0 or flags&1)
    times=[frame['runs'][0]['time14'] for frame in observed['frames']]
    if gate:assert times[0]>.1 and times[1]>times[0]
    else:assert times[0]==times[1] and not observed['calls']
    rows.append(dict(input={k:v for k,v in case.items() if not k.startswith('_')},innerGateOpen=gate,observed=observed))
case=profile([entry(time=.1,previous=.025,length=10)],deltas=[.5,.75,.1],source_flags=4,light_exemption_f0=0,view_sequence=[0,0,1])
observed=run(case);times=[frame['runs'][0]['time14'] for frame in observed['frames']]
assert times[0]==times[1] and .199<times[2]<.201
assert sum(call[0]=='applyClip' for call in observed['calls'])==1
rows.append(dict(input={k:v for k,v in case.items() if not k.startswith('_')},innerGateOpen=[False,False,True],noElapsedCatchup=True,observed=observed))
m=namespace['m'];u=namespace['u']
out=root/'godot-client/.cache/native-render-gap/original/admission-chain/clock-exemption-instructions-a.json'
assert not out.exists(),'Preserve prior observations'
result=dict(version=1,success=True,subjectSha256=m.digest,sourceProviderFile=str(source_file),sourceProviderSha256=hashlib.sha256(source_file.read_bytes()).hexdigest(),derivedProviderSha256=hashlib.sha256(source.encode()).hexdigest(),originalBody=dict(address='0x14004dbd0',end='0x14004e9dd',sha256=hashlib.sha256(bytes(u.mem_read(0x14004dbd0,0xe0d))).hexdigest()),limits=__doc__,rows=rows,scope='Original clock pauses on failed prior-view/light/effect inner gate; no elapsed catchup when view returns. Numeric f0 from separately-proven original light constructor opens the gate. Sceneless outer gate deliberately remains open; force/pause gates, hooks, BSP membership and room cohort remain separate.')
out.write_text(json.dumps(result,indent=2))
print(json.dumps(dict(output=str(out),sha256=hashlib.sha256(out.read_bytes()).hexdigest(),cases=len(rows))))
