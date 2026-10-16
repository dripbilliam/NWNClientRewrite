"""Original decoded Input30 block140455373..14045541e. Captured wire
OBJECT_ID/overflow, creature lookup and RemoveEffectById. Shared function entry,
packet transport and lower deferred removal validated separately, not here.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,app,pool,message=[m.heap+n*0x2000 for n in range(4)]
def hook(u,a,n,_):
 if a in [m.stop,0x140453780]:u.emu_stop();return
 x,y=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==0x140476130:calls.append(['readObject']);m.finish(c.get('target',99))
 elif a==0x1402d9460:calls.append(['overflow']);m.finish(c.get('overflow',0))
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if c.get('exists',True)else 0)
 elif a==0x140498280:calls.append(['remove',f'{y:016x}']);m.finish(1)
 elif not 0x140455373<=a<0x140455423:raise RuntimeError(f'Unexpected cancel input dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for overflow,exists,blocked,locked,effects in itertools.product([0,1],[False,True],[0,1,-1],[0,1,-1],[[],[62],[15,62,62,68],[15,61,68]]):
 c=dict(overflow=overflow,exists=exists,blocked=blocked,locked=locked,effects=effects);calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(actor+0x8ac,blocked);m.wi(actor+0x9f8,locked);m.wq(actor+0x150,pool);m.wi(actor+0x158,len(effects))
 for n,t in enumerate(effects):
  e=m.heap+0x10000+n*0x200;m.wq(pool+n*8,e);m.wq(e,500+n);u.mem_write(e+8,struct.pack('<H',t))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RDI,message);u.reg_write(UC_X86_REG_RSI,0)
 u.emu_start(0x140455373,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==0x140453780;rows.append(dict(case=c,calls=calls))
out=m.root/'backups/animations/native-polymorph-input-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
