"""Execute the original SetBaseAnimation764300 body and classification leaves.

Fixtures supply creature/model vtables and explicit playback/current/base/countdown
state. Model query/flag/playback and GetAsCreature (unavailable in this narrow
fixture) are captured boundaries. Native branching/stores/classification execute;
no renderer, actual assets, packets, timing benchmark or live process mutation.
"""
import sys, importlib, json, struct, itertools
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
t = importlib.import_module('inspect-native-message-text')
w, m, u = t.w, t.w.m, t.w.m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor, model, vt, mvt = [m.heap + n * 0x1000 for n in [40, 41, 42, 43]]
descriptor = json.loads((m.root / 'backups/animations/rea-network-combat-set-base-animation.json').read_text())['structuredContent']['raw_result']['value']
ranges = [(int(r['start'],16), int(r['end'],16)+1) for r in descriptor['procedure']['body']['ranges']]
ranges += [(0x140762430,0x140762630)]
calls = []
def wh(p,v): u.mem_write(p, struct.pack('<H',v & 65535))
def hook(u,a,n,data):
 x,y,z,k = [u.reg_read(q) for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a == m.stop+0x58: m.finish(0); return
 if a == m.stop+0x70: m.finish(0); return
 if a == m.stop+0x60: calls.append(dict(kind='flag',animation=y & 65535,value=z)); m.finish(); return
 if a == m.stop+0x80:
  calls.append(dict(kind='play',animation=y & 65535)); m.finish(1); return
 if a == m.stop+0x150:
  calls.append(dict(kind='transition',animation=y & 65535)); m.finish(1); return
 if any(lo <= a < hi for lo,hi in ranges): return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for current,desired,remaining in itertools.product([0,1,2,3,4,78,79,84,85,86,87,200], [250,251,252,253,261], [0,500]):
 t.reset(dict(format=1)); calls=[]
 m.wq(actor,vt); m.wq(vt+0x58,m.stop+0x58); m.wq(vt+0x150,m.stop+0x150)
 m.wq(actor+0x78,model); m.wq(model,mvt)
 for off in [0x60,0x70,0x80]: m.wq(mvt+off,m.stop+off)
 u.mem_write(actor+12,bytes([5])); wh(actor+0x5c,current); wh(actor+0x64,0)
 m.wi(actor+0x74,remaining); m.wf(actor+0x60,1.0)
 w.call(0x140764300,[actor,desired])
 rows.append(dict(case=dict(current=current,desired=desired,remaining=remaining),result=dict(current=int.from_bytes(u.mem_read(actor+0x5c,2),'little'),base=int.from_bytes(u.mem_read(actor+0x64,2),'little'),calls=list(calls))))
out=m.root/'godot-client/reports/native-combat-base-handoff-original-v1.json'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,cases=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),output=str(out))))
