"""Read-only original client target reply writer7c0110 and mask registration
98d5f0. Allocation/transport, controller reset/registration and preview/activation
are captured boundaries. Executes native packet framing/scalar writers and mask
branches; no live process, joins, server scripts or original asset copies.
"""
import importlib,sys,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
w=importlib.import_module('inspect-native-message-writer');m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(w.hook_handle)
body=json.loads((m.root/'backups/animations/rea-nui-target-controller-start-v1.json').read_text())['structuredContent']['normalized_result']['procedure']['body']['ranges']
ranges=[(0x1407c0110,0x1407c01ed),(0x1409737f0,0x140973838)]+[(int(r['start'],16),int(r['end'],16)+1)for r in body]
def hook(u,a,n,_):
 if a==0x1407c25c0:
  sp=u.reg_read(UC_X86_REG_RSP);ptr=u.reg_read(UC_X86_REG_R9);size=m.si(sp+0x28)&0xffffffff
  packets.append(bytes([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255])+bytes(u.mem_read(ptr,size))[3:]);m.finish(1);return
 if a in [0x14098cb10,0x140704bd0,0x14083b9e0]:m.finish();return
 if a==0x14083bac0:
  kinds.append([u.reg_read(UC_X86_REG_RDX)&0xffffffff,u.reg_read(UC_X86_REG_R8)&0xffffffff]);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 w.hook(u,a,n,_)
u.hook_add(UC_HOOK_CODE,hook)
packets=[];cases=[];point=m.heap+0x9000;owner=m.heap+0x7000
for target,position in itertools.product([0x7f000000,0xffffffff,0xffffffce,0x80000002],[[0,0,0],[1.25,-2.5,.3097555],[-0.,65536,-65536]]):
 w.run(dict(format=1,ops=[]));packets=[];u.mem_write(point,struct.pack('<fff',*position));w.call(0x1407c0110,[w.message,target,point]);assert len(packets)==1
 cases.append(dict(targetId=target,position=position,packet=packets[0].hex()))
masks=[]
for mask in [0,*[1<<b for b in range(10)],1023,0xffffffff]:
 kinds=[];w.run(dict(format=1,ops=[]));w.call(0x14098d5f0,[owner,mask,7,13]);masks.append(dict(mask=mask,kinds=kinds,badCursor=m.si(owner+0x118)))
out=m.root/'backups/animations/native-script-targeting-v1.json';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=cases,masks=masks),indent=2)+'\n');print(json.dumps(dict(success=True,packets=len(cases),masks=len(masks))))
