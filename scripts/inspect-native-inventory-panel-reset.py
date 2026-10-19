"""Execute original client inventory panel8562e0 and sender7be060.
Grid clear882700 and app transport lookup are captured GUI boundaries. Actual
field writes, ordering and native message serialization execute unchanged.
No canonical item destruction or gameplay simulation is inferred.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);gui=m.heap+0x30000
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140882700:assert x==gui+0x1b08;events.append(dict(kind='gridClear',panel=m.si(gui+0x1cd8)&0xffffffff));m.finish();return
 if a==0x1406abf90:events.append(dict(kind='transport'));m.finish(w.message if c['transport']else 0);return
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;packet=bytes([112,y&255,z&255])+bytes(u.mem_read(k,size))[3:];events.append(dict(kind='send',packet=packet.hex()));m.finish(1);return
 if 0x1408562e0<=a<=0x140856334 or 0x1407be060<=a<0x1407be10e:return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for c in [dict(panel=p,self=s,transport=tx,format=f)for p,s,tx,f in itertools.product([0,1,9,255,65535],[0,1],[False,True],[0,1])]:
 events=[];t.reset(dict(format=c['format']));m.wi(gui+0x2f6c,c['self']);w.call(0x1408562e0,[gui,c['panel']]);assert events[0]==dict(kind='gridClear',panel=c['panel']);assert events[1]['kind']=='transport';assert len(events)==(3 if c['transport']else 2);rows.append(dict(case=c,events=list(events)))
out=m.root/'backups/animations/native-inventory-panel-reset-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
