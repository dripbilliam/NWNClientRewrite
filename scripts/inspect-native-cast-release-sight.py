"""Unchanged AIActionCastSpell release-sight block1403af22d..1403af3f7,
entered after a valid caster area lookup. Capture virtual casts, target-area
lookup and actual ClearLineOfSight vectors/result. This bounded comparison
does not execute the full cast, geometry implementation or authored spell.
"""
import importlib,sys,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
actor,target,item,area,vtable=[m.heap+i*0x1000 for i in range(5)]

def hook(u,a,n,_):
 global accepted
 if a in [0x1403af2d6,0x1403af3ff]:accepted=int(a==0x1403af2d6);u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(target if c['object'] else 0)
 elif a==m.stop+0x20:m.finish(item if c['item'] else 0)
 elif a==0x140494e80:trace.append(['area','target']);m.finish(area if c['placed'] else 0)
 elif a==0x14035c590:
  trace.append(['los',[m.rf(y+i*4)for i in range(3)],[m.rf(z+i*4)for i in range(3)],m.si(rsp+0x30)&0xffffffff,m.si(rsp+0x38)&0xffffffff,m.si(rsp+0x40)]);m.finish(c['los'])
 elif not 0x1403af22d<=a<0x1403af3ff:raise RuntimeError(f'Unmapped release-sight dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,trace,accepted
 c=case;trace=[];accepted=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(target,vtable);m.wq(vtable+0x20,m.stop+0x10);m.wq(vtable+0x70,m.stop+0x20);m.wi(actor+8,0x80000042);m.wi(item+0x3c8,c['possessor'])
 for obj,point in [(actor,[1.25,-2.5,3.75]),(target,[-4.5,5.25,-6.75])]:
  for i,value in enumerate(point):m.wf(obj+0xa4+i*4,value)
 rsp=m.stack+0x17000;rbp=m.stack+0x18000;m.wi(rsp+0x74,91 if c['target'] else 0x7f000000)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RBP,rbp),(UC_X86_REG_RSI,actor),(UC_X86_REG_R12,target if c['target'] else 0),(UC_X86_REG_RBX,area)]:u.reg_write(reg,value)
 for reg,value in [(UC_X86_REG_XMM9,8.25),(UC_X86_REG_XMM10,-9.5),(UC_X86_REG_XMM8,10.75)]:u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
 u.emu_start(0x1403af22d,m.stop,count=10000);assert accepted is not None
 return dict(case=c,trace=trace,accepted=accepted)
rows=[run(dict(target=target_,object=object_,item=item_,placed=placed,possessor=possessor,los=los))for target_,object_,item_,placed,possessor,los in itertools.product([False,True],[False,True],[False,True],[False,True],[0x80000042,91,0x7f000000],[0,1])]
out=m.root/'backups/animations/native-cast-release-sight-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
