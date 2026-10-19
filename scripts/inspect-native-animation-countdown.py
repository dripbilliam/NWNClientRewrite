"""Complete native placeable sequence owner870480 and real classifications.

Synthetic countdown and queued-cue fixtures; base setter, destruction cleanup,
GetNext/Remove queue and model playback are captured lower boundaries. Verifies
UINT cue storage as signed remaining74 and strict-negative expiry; no rendering,
sound lookup, actual queue allocation or full object lifecycle claim.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
d=json.loads((m.root/'backups/animations/rea-network-combat-placeable-sequence.json').read_text())['structuredContent']['raw_result']['value'];ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]+[(0x140762430,0x1407625d0),(0x140763220,0x140763225)]
actor,model,vt,mvt=m.heap+0x3000,m.heap+0x4000,m.heap+0x5000,m.heap+0x6000
case={};calls=[]
def wh(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def hook(u,a,n,data):
 x,y,z=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140871e60:calls.append('destroy');m.finish();return
 if a==m.stop+0x18:m.finish(actor);return
 if a==0x140764300:calls.append('base');wh(x+0x5c,y);m.finish(1);return
 if a==0x1407632d0:
  calls.append('next');
  if case['queued']:
   wh(y,214);m.wf(z,1.5e-8);m.wi(u.reg_read(UC_X86_REG_R9),0xfffffff2);m.wq(m.q(u.reg_read(UC_X86_REG_RSP)+0x28),0)
  m.finish(int(case['queued']));return
 if a==m.stop+0x80:calls.append('play');m.finish(1);return
 if a==0x140763fb0:calls.append('remove');m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for remaining,elapsed,queued in itertools.product([0,1,50,66,916,0x7fffffff,0xfffffff2,0xffffffff],[0,1,16,80],[False,True]):
 case=dict(remaining=remaining,elapsed=elapsed,queued=queued);t.reset(dict(format=1));calls=[]
 m.wq(actor,vt);m.wq(vt+0x18,m.stop+0x18);u.mem_write(actor+12,bytes([9]));m.wq(actor+0x78,model);m.wq(model,mvt);m.wq(mvt+0x80,m.stop+0x80);wh(actor+0x5c,214);wh(actor+0x64,72);m.wi(actor+0x74,remaining);m.wi(actor+0x58,elapsed)
 w.call(0x140870480,[actor]);rows.append(dict(case=case,remaining=m.si(actor+0x74),animation=int.from_bytes(u.mem_read(actor+0x5c,2),'little'),calls=calls))
out=m.root/'backups/animations/native-animation-countdown-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
