"""Original no-path creature model-update7fcd70 and SetBaseAnimation764300.

Executes complete original bodies/classification/base getters. Explicit fixture
state supplies an existing gait, resting base and empty path. Facing/correction,
empty animation queue, model queries/playback and unavailable GetAsCreature are
captured lower boundaries. No live process, actual combat or renderer claim.
"""
import sys, importlib, json, struct, itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,model,vt,mvt=[m.heap+n*0x1000 for n in [40,41,42,43]]
ranges=[(0x140762430,0x140762630),(0x140763220,0x140763225),(0x140765f50,0x140765f79)]
for name in ['rea-network-client-movement-model-update','rea-network-combat-set-base-animation']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
calls=[]
def wh(p,v):u.mem_write(p,struct.pack('<H',v&65535))
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x58:m.finish(0);return
 if a==m.stop+0x70:m.finish(0);return
 if a==m.stop+0x60:calls.append(dict(kind='flag',animation=y&65535,value=z));m.finish();return
 if a==m.stop+0x80:calls.append(dict(kind='play',animation=y&65535));m.finish(1);return
 if a==m.stop+0x150:calls.append(dict(kind='transition',animation=y&65535));m.finish(1);return
 if a==0x140807690:calls.append(dict(kind='facing'));m.finish();return
 if a==0x140804840:calls.append(dict(kind='correction'));m.finish();return
 if a==0x1407632d0:calls.append(dict(kind='empty-queue'));m.finish(0);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for visual,base in itertools.product([2,3,4,78,79,84,85,86,87],[0,1]):
 t.reset(dict(format=1));calls=[];m.wq(actor,vt);m.wq(vt+0x58,m.stop+0x58);m.wq(vt+0x150,m.stop+0x150)
 m.wq(actor+0x78,model);m.wq(model,mvt)
 for off in [0x60,0x70,0x80]:m.wq(mvt+off,m.stop+off)
 u.mem_write(actor+12,bytes([5]));wh(actor+0x5c,visual);wh(actor+0x64,base)
 m.wi(actor+0x3a8,0x7f000000);u.mem_write(actor+0x37e,bytes([2 if base==1 else 0]));m.wf(actor+0x60,1.0)
 w.call(0x1407fcd70,[actor])
 rows.append(dict(case=dict(visual=visual,base=base,pathCount=0,mode=2 if base==1 else 0),result=dict(visual=int.from_bytes(u.mem_read(actor+0x5c,2),'little'),base=int.from_bytes(u.mem_read(actor+0x64,2),'little'),calls=list(calls))))
out=m.root/'godot-client/reports/native-combat-locomotion-handoff-original-v1.json'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,cases=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),output=str(out))))
