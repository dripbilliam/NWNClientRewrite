"""Original GetGoldPieceValue140525160..140525213. Typed VM pop/push,
canonical lookup, virtual item cast and GetCost are captured boundaries.
Pop/push succeed; covers resolved command body and raw pushed INT bits.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,itemPtr,appPtr,vmPtr,arrayPtr,vtablePtr=[m.heap+n*0x1000 for n in range(1,7)]
def hook(u,at,n,_):
 global pushed
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x140286160:m.wi(y,17);m.finish(1);return
 if at==0x14055b850:m.finish(arrayPtr);return
 if at==0x140296470:assert x==arrayPtr;calls.append(['lookup',y&0xffffffff]);m.wq(z,objectPtr);m.finish(c['lookup']);return
 if at==m.stop+0x10:assert x==objectPtr;calls.append(['asItem']);m.finish(itemPtr if c['item']else 0);return
 if at==0x140468710:assert x==itemPtr;calls.append(['price',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish(c['price']);return
 if at==0x140286410:pushed=y&0xffffffff;m.finish(1);return
 if not 0x140525160<=at<0x140525214:raise AssertionError(f'Uncaptured gold query dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,pushed
 c=case;calls=[];pushed=None;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(0x1412df910,vmPtr);m.wq(objectPtr,vtablePtr);m.wq(vtablePtr+0x70,m.stop+0x10)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 u.emu_start(0x140525160,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,pushed=pushed,status=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
rows=[run(dict(lookup=status,item=item,price=price))for status,item,price in itertools.product([0,1,2,256],[False,True],[0,1,0x80000000,0xffffffff])]
out=m.root/'backups/animations/native-item-gold-query-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
