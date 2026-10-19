"""Bounded original creature event5 block38e51e..565 and ApplyEffect
post-handler flag branches48e3ce..68b/907..934. Effect application, integer
lookup and removal/destruction are captured. This validates offset180 behavior
and special argument ordering, not the full generic ApplyEffect owner.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,effect,ints=[m.heap+n*0x1000 for n in range(3)]
def hook(u,a,n,_):
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in[0x14038e565,0x14048e68b,0x14048e928]:u.emu_stop();return
 if a==0x14048e934:trace.append(['dispose']);u.emu_stop();return
 if a==0x14048e350:
  trace.append(['apply',m.si(actor+0x180),z&0xffffffff,w&0xffffffff]);
  if c.get('after')is not None:m.wi(actor+0x180,c['after'])
  m.finish()
 elif a==0x140423fc0:m.finish(c.get('visual',207))
 elif a==0x140498280:trace.append(['remove',f'{y:016x}']);m.finish()
 elif not any(lo<=a<hi for lo,hi in[(0x14038e51e,0x14038e566),(0x14048e3ce,0x14048e68c),(0x14048e907,0x14048e935)]):raise AssertionError(f'Unmapped effect flag boundary {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace
 c=case;trace=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(actor+0x180,c.get('flag',0));m.wq(effect,123);u.mem_write(effect+8,(c.get('type',40)&65535).to_bytes(2,'little'));m.wq(effect+0x48,ints);rsp=m.stack+0x1fe08;u.reg_write(UC_X86_REG_RSP,rsp)
 if c['mode']=='event':
  entry=0x14038e51e;registers={UC_X86_REG_RSI:actor,UC_X86_REG_R14:effect if c.get('payload',True)else 0,UC_X86_REG_R13D:c.get('event',5),UC_X86_REG_RDI:0}
 else:entry=0x14048e3ce;registers={UC_X86_REG_RSI:effect,UC_X86_REG_R14:actor,UC_X86_REG_RAX:c.get('consumed',0),UC_X86_REG_RBP:0,UC_X86_REG_RDI:0,UC_X86_REG_RBX:c.get('special',0)}
 for reg,v in registers.items():u.reg_write(reg,v)
 u.emu_start(entry,m.stop,count=20000)
 return dict(case=c,flag=m.si(actor+0x180),trace=trace)
cases=[dict(mode='tail',type=30,visual=v,flag=flag)for v,flag in itertools.product(range(261),[0,1,2])]
cases +=[dict(mode='tail',type=t,visual=v,consumed=consumed,special=special,flag=flag)for(t,v),consumed,special,flag in itertools.product([(3,0),(40,0),(67,0),(30,0),(30,153),(30,207)],range(3),range(3),range(3))]
cases +=[dict(mode='event',type=t,flag=flag,after=after)for t,flag,after in itertools.product([3,30,40,67,65576],[0,1,2],[None,0,1,2])]
cases +=[dict(mode='event',payload=False),dict(mode='event',event=6)]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-effect-application-flag-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
