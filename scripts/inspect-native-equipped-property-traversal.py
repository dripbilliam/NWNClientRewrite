"""Complete unchanged ApplyItemProperties/RemoveItemProperties. Capture AI
lookup, materializer callbacks and final RemoveEffectByCreator owner. Mutating
the passive pool inside callbacks checks re-read bounds and current storage.
No concrete effect, equipment admission or lower creator-cleanup claim.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u;u.hook_del(m.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
item,owner,ai,storage,app=[m.heap+i*0x1000 for i in range(5)]
def setPool(values):
 global pool
 pool=list(values);m.wq(item+0x378,storage);m.wi(item+0x380,len(pool))
 for i,value in enumerate(pool):m.wi(storage+i*0x30,value)
def hook(u,a,n,_):
 global callbacks
 if a==m.stop:u.emu_stop();return
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b960:trace.append(['ai']);m.finish(ai if c['ai'] else 0)
 elif a in [0x140559490,0x1405594b0]:
  trace.append(['apply' if a==0x140559490 else 'remove',m.si(z) if z else None,m.si(rsp+0x28)&0xffffffff,*([m.si(rsp+0x30)] if a==0x140559490 else [])]);callbacks+=1
  if callbacks==c.get('mutateAt',-1):setPool(c['after'])
  m.finish()
 elif a==0x140498080:trace.append(['removeCreator',y&0xffffffff]);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x140464d50,0x140464dfe),(0x14046b3e0,0x14046b496)]):raise RuntimeError(f'Unmapped equipped property traversal {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,callbacks
 c=case;trace=[];callbacks=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(item+0x50,123);setPool(c['pool']);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wi(rsp+0x28,c['loading']);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[item,owner,c['slot'],c['loading']]):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(0x140464d50 if c['kind']=='apply' else 0x14046b3e0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,trace=trace,pool=pool)
rows=[]
for kind,ai_,values,slot,loading in itertools.product(['apply','remove'],[False,True],[[],[1],[1,2,3]],[-1,16],[0,1,2]):rows.append(run(dict(kind=kind,ai=ai_,pool=values,slot=slot,loading=loading)))
for kind,before,after,at in itertools.product(['apply','remove'],[[1],[1,2,3]],[[],[7],[7,8,9,10]],[1,2]):rows.append(run(dict(kind=kind,ai=True,pool=before,after=after,mutateAt=at,slot=16,loading=0)))
out=m.root/'backups/animations/native-equipped-property-traversal-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
