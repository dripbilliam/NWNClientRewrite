"""Original projectile stage985510 and CNWCAnimBaseProjectile9ddd00. Actual
projectile animation handler executes; Gob::PlayAnimation is a captured lower.
Does not prove model loading, clip availability, run/pose or scene lifetime.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,handle,vt,model,mvt=[m.heap+n*0x1000 for n in range(1,6)];play=m.stop+0x10
ranges=[(0x1409ddd00,0x1409ddd9e),(0x140985510,0x14098556b)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==play:
  x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];assert x==model;rsp=u.reg_read(UC_X86_REG_RSP)
  name=bytes(u.mem_read(y,32)).split(b'\0')[0].decode('ascii');calls.append(dict(name=name,speed=u.reg_read(UC_X86_REG_XMM2)&0xffffffff,flags=w&0xffffffff,start=m.si(rsp+0x28)&0xffffffff));m.finish(c['playResult'])
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured animation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x10000));m.wq(actor+0x78,handle if c['hasModel'] else 0);u.mem_write(actor+0x5c,struct.pack('<H',123));m.wq(handle,vt);m.wq(vt+0x80,0x1409ddd00);m.wq(handle+0xc8,model);m.wq(model,mvt);m.wq(mvt+0x30,play)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,handle if c['mode']=='play' else actor);u.reg_write(UC_X86_REG_RDX,c['stage']);u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',c['speed']),'little'));u.reg_write(UC_X86_REG_R9,c['flags']);m.wf(rsp+0x28,c['start'])
 u.emu_start(0x1409ddd00 if c['mode']=='play' else 0x140985510,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,stage=int.from_bytes(u.mem_read(actor+0x5c,2),'little'))
default=dict(stage=1,speed=1,flags=0,start=0,hasModel=1,playResult=1)
rows=[run(default|dict(mode='play',stage=stage,speed=speed,flags=flags,start=start,playResult=result))for stage,speed,flags,start,result in itertools.product([0,1,2,3,0xffff,0x10000],[0,-0.0,1,-1,.5],[0,1,2,3,0x80000000,0xffffffff],[0,.25,-1],[0,1])]
rows += [run(default|dict(mode='set',stage=stage,hasModel=model,playResult=result))for stage,model,result in itertools.product([0,1,2,3,0xffff,0x10000],[0,1],[0,1])]
out=m.root/'backups/animations/native-client-projectile-animation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
