"""Complete original door/placeable animation-name virtual owners.

All WORD ids0..425 plusFFFF; door destroyed-model fieldF0 at0/1. Alloc/free
and shared replacement/copy boundary are captured with empty override pools.
No model assets, live edits, rendering or full object animation lifecycle proof.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
ranges=[]
for name in ['placeable-animation-names','door-animation-names']:
 d=json.loads((m.root/f'backups/animations/rea-network-combat-{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
value=None
def hook(u,a,n,data):
 global value
 if a==0x140964530:
  z=u.reg_read(UC_X86_REG_R8);p=m.q(z);length=m.si(z+8);value=bytes(u.mem_read(p,length)).decode('ascii');m.finish(u.reg_read(UC_X86_REG_RDX));return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[];actor=m.heap+0x3000;out=m.heap+0x4000
for type_,flag in [(9,0),(10,0),(10,1)]:
 for id_ in list(range(426))+[65535]:
  t.reset(dict(format=1));value=None;m.wi(actor+0xf0,flag);w.call(0x1409b20a0 if type_==9 else 0x1409b0790,[actor,out,id_,0]);assert isinstance(value,str);rows.append(dict(type=type_,id=id_,doorDestroyed=flag,value=value))
outpath=m.root/'backups/animations/native-object-animation-name-observations.json';outpath.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(outpath))))
