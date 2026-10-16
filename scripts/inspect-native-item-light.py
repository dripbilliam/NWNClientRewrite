"""Complete unchanged ApplyLight materializer and OnApplyLight with the real
effect constructor/copy constructor. Capture property lookup, creator binding,
virtual creature casts, integer read and lower ApplyEffect calls. The remove
leaf is statically verified return1. Generic ApplyEffect bookkeeping, nonzero
fourth-flag loading behavior and actual visual rendering are separate owners.
"""
import importlib,json,itertools
b=importlib.import_module('inspect-native-item-property-materializers');m=b.m;u=b.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(b.hook_handle)
def hook(u,a,n,_):
 if a==m.stop+0x10:b.trace.append(['creature']);m.finish(b.owner if b.c.get('creature',True) else 0)
 elif a==0x140423fc0:
  x,y=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]];b.trace.append(['integer',y&0xffffffff]);m.finish(m.si(m.q(x+0x48)+(y&0xffffffff)*4))
 else:b.hook(u,a,n,_)
u.hook_add(UC_HOOK_CODE,hook)
rows=[b.run(dict(kind='light',type=44,param1Value=color,costValue=intensity,has=has,loading=loading))for color,intensity,has,loading in itertools.product([0,1,2,3,4,5,6,7,255],[0,1,2,3,4,5,65535],[0,1],[0,1,3])]
effects=[]
for creature,loading,visual in itertools.product([False,True],[0,1,3],[153,160,180]):
 b.run(dict(kind='light',type=44,param1Value=0,costValue=1));source=m.heap+0x10000;m.wi(m.q(source+0x48),visual);b.trace=[];b.c=dict(creature=creature)
 vt=m.heap+0xf000;m.wq(b.owner,vt);m.wq(vt+0x60,m.stop+0x10);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[b.handler,b.owner,source,loading]):u.reg_write(reg,value)
 u.emu_start(0x14042ed70,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 effects.append(dict(case=dict(creature=creature,loading=loading,visual=visual),result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,source=b.snapshot(source),trace=b.trace))
out=m.root/'backups/animations/native-item-light-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,effects=effects),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),effects=len(effects))))
