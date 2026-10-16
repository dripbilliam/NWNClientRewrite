"""Original creature event24 block14038fb0f..14038fc54. Event dispatch entry,
payload getters/disposal and lower area/script/associate/effect owners captured.
Proves ordering and native548 write, not the captured owners or full event loop.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,target,payload,area,effect,ints,app=[m.heap+n*0x1000 for n in range(1,8)]
def hook(u,a,n,_):
 global areaCalls
 if a==0x14038fc54:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404c6ad0:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c.get('point',[1,2,3])[y]),'little'));m.finish()
 elif a==0x1404c6b10:m.finish(c.get('id',100))
 elif a==0x1404c6af0:m.finish(c.get('appear',0))
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(target if c.get('exists',True) else 0)
 elif a==0x140494e80:
  areaCalls+=1;calls.append(['area',99]);m.finish(0 if c.get('noArea') or c.get('vanishArea') and areaCalls==2 else area)
 elif a==0x140380470:calls.append(['addToArea',100,None if y==0 else 88,[m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28)],m.si(rsp+0x30),m.si(rsp+0x38)]);m.finish()
 elif a==0x1404998a0:calls.append(['script',100,y,z,m.si(target+0x548)]);m.finish()
 elif a==0x1403d0410:calls.append(['associate',y&0xffffffff,z&65535]);m.finish()
 elif a==0x140c10324:m.finish(effect)
 elif a==0x1404233d0:m.wq(effect+0x48,ints);m.wi(effect+0x40,8);m.finish(effect)
 elif a==0x140425110:m.wi(effect+0x18,y);m.finish()
 elif a==0x14048e350:calls.append(['effect',100,int.from_bytes(u.mem_read(effect+8,2),'little'),m.si(effect+0x18)&0xffffffff,m.si(ints),z,w]);m.finish()
 elif a in [0x1404c64d0,0x140c10360]:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14038fb0f,0x14038fc54),(0x140425210,0x14042521c)]):raise AssertionError(f'Uncaptured summon event dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,areaCalls
 c=case;calls=[];areaCalls=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(actor+8,99);m.wi(target+8,100);m.wi(target+0x548,7)
 rsp=m.stack+0x1f000;u.mem_write(rsp-0x100,bytes(0x800));u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rsp+0x100)
 for reg,v in zip([UC_X86_REG_RSI,UC_X86_REG_R14,UC_X86_REG_R12,UC_X86_REG_RDI],[actor,payload,1,0]):u.reg_write(reg,v)
 u.emu_start(0x14038fb0f,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==0x14038fc54
 return dict(case=c,calls=calls,field548=m.si(target+0x548))
rows=[run(dict(appear=appear,exists=exists,noArea=noArea,point=point)) for appear,exists,noArea,point in itertools.product([-1,0,1,2,99],[False,True],[False,True],[[1,2,3],[-11,0,8.25]])]+[run(dict(vanishArea=True,appear=1))]
out=m.root/'backups/animations/native-summon-event-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
