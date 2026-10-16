"""Original CNWSObject destructor14048bf10. Memory-only internal destructors
and storage release captured. Execute registry/effect/action ordering, reverse
effect disposal and forced situation disposal independently of cancellation flags.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,area,app,vt,linked,effects,vm=[m.heap+n*0x1000 for n in range(1,8)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14055b850:m.finish(app)
 elif a==0x140296470:calls.append(['area']);m.wq(z,area if c.get('area') else 0);m.finish(0 if c.get('area') else 1)
 elif a==m.stop+0x10:m.finish(area)
 elif a==0x140364cc0:calls.append(['removeArea',y&0xffffffff]);m.finish(1)
 elif a==0x140296360:calls.append(['registry',y&0xffffffff]);m.finish()
 elif a==0x140423770:calls.append(['effect',m.q(x)]);m.finish()
 elif a==0x1401692a0:
  ptr=nodes.pop(0);m.wq(linked,1 if nodes else 0);m.finish(ptr)
 elif a==0x140280220:calls.append(['situation',m.si(y)]);m.finish()
 elif a in [0x140c4f024,0x140c10360,0x140c10370,0x140168dc0,0x140504df0,0x14035a740]:m.finish()
 elif not 0x14048bf10<=a<0x14048c461:raise AssertionError(f'Uncaptured base destructor dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,nodes
 c=case;calls=[];nodes=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,vm);m.wi(actor+8,99);m.wi(actor+0xa0,88 if c.get('area') else 0x7f000000);m.wq(area,vt);m.wq(vt+0x50,m.stop+0x10);m.wq(actor+0x100,linked)
 for i,type in enumerate(c.get('actions',[])):
  ptr=m.heap+0x10000+i*0x1000;data=ptr+0x200;nodes.append(ptr);m.wi(ptr+0x9c,c.get('ready',0));u.mem_write(ptr+0x9a,struct.pack('<H',1));m.wi(ptr+4,type);m.wq(ptr+0x38,data);m.wi(data,i+1)
 m.wq(linked,1 if nodes else 0);m.wq(actor+0x150,effects);values=c.get('effects',[]);m.wi(actor+0x158,len(values))
 for i,id in enumerate(values):ptr=m.heap+0x20000+i*0x1000;m.wq(effects+i*8,ptr if id is not None else 0);m.wq(ptr,id or 0)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor)
 u.emu_start(0x14048bf10,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,areaId=m.si(actor+0xa0)&0xffffffff,effectCount=m.si(actor+0x158),actions=len(nodes))
rows=[run(dict(area=area,ready=ready,actions=actions,effects=effects)) for area,ready,actions,effects in itertools.product([False,True],[0,1],[[],[1],[5],[5,4,5],[4,1,5]],[[],[1],[1,2,3],[1,None,2]])]
out=m.root/'backups/animations/native-base-destruction-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
