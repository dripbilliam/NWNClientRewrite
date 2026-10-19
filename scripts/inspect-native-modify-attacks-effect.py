"""Complete original bonus-attacks constructor51a730/apply42f010/remove4378d0.
VM/base effect allocation/deletion and object cast/dead are captured boundaries.
Original Get/SetInteger, signed sums, cap, pointer exclusion, scan differences
and combat-round2f64 writes execute. No attack animation/network acceptance.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,round_,effect,ints,pool,vt,commands,app=[m.heap+n*0x4000 for n in range(8)]
ranges=[(0x14051a730,0x14051a822),(0x14042f010,0x14042f107),(0x1404378d0,0x14043797c),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]
def snapshot(e):
 flags=int.from_bytes(u.mem_read(e+10,2),'little');return dict(id=f'{m.q(e):016x}',type=int.from_bytes(u.mem_read(e+8,2),'little'),subtype=flags&~7,durationType=flags&7,creatorId=m.si(e+24)&0xffffffff,integers=[m.si(m.q(e+0x48)+i*4) for i in range(8)])
def hook(u,a,n,_):
 global output
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop+0x10:calls.append(['creature']);m.finish(actor if c.get('creature',True) else 0)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x140286110:calls.append(['pop']);m.wi(y,c.get('amount',1));m.finish(c.get('pop',1))
 elif a==0x140c10324:m.finish(m.heap+0x80000)
 elif a==0x1404233d0:m.wq(x,101);m.wq(x+0x48,x+0x400);m.wi(x+24,0x7f000000);m.finish(x)
 elif a==0x140425110:calls.append(['creator',y&0xffffffff]);m.wi(x+24,y);m.finish()
 elif a==0x140286330:calls.append(['push']);output=snapshot(z);m.finish(c.get('push',1))
 elif a in [0x140423770,0x140c10360]:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected modify-attacks dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,output
 c=case;calls=[];output=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0x880,round_);m.wi(round_+0x2f64,c.get('current',0));m.wi(commands+12,99);m.wq(0x1412df910,app)
 m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',44,8|c.get('durationType',2)));m.wi(ints,c.get('amount',1))
 m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])))
 for i,e in enumerate(c.get('effects',[])):
  ptr=effect if e.get('samePointer') else m.heap+0x40000+i*0x200;m.wq(pool+i*8,ptr)
  if ptr!=effect:m.wq(ptr,e.get('id',77));m.wq(ptr+0x48,ptr+0x100);u.mem_write(ptr+8,struct.pack('<H',e['type']));m.wi(ptr+0x100,e.get('amount',0))
 mode=c['mode'];args=[commands,485,1] if mode=='constructor' else [app,actor,effect,c.get('loading',0)]
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v)
 u.emu_start(dict(constructor=0x14051a730,apply=0x14042f010,remove=0x1404378d0)[mode],m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;return dict(case=c,calls=calls,result=(result^0x80000000)-0x80000000,bonusAttacks=m.si(round_+0x2f64),output=output)
rows=[]
for amount in [-2147483648,-9,-1,0,1,4,5,6,7,2147483647]:rows.append(run(dict(mode='constructor',amount=amount)))
rows.extend([run(dict(mode='constructor',pop=0)),run(dict(mode='constructor',push=0))])
for creature,loading,dead,duration,current,amount in itertools.product([False,True],[0,1],[0,1],range(5),[-1,0,5,6],[-3,0,2,5]):rows.append(run(dict(mode='apply',creature=creature,loading=loading,dead=dead,durationType=duration,current=current,amount=amount)))
lists=[[],[dict(type=44,amount=3)],[dict(type=44,amount=4),dict(type=44,amount=3)],[dict(type=43,amount=99),dict(type=44,amount=-4),dict(type=45,amount=100)],
 [dict(type=44,samePointer=True),dict(type=44,amount=4,id=77)],[dict(type=44,amount=2147483647),dict(type=44,amount=10)],
 [dict(type=45,amount=100),dict(type=44,amount=4)]]
for mode,creature,values,amount in itertools.product(['apply','remove'],[False,True],lists,[-2147483648,-5,1,5,2147483647]):rows.append(run(dict(mode=mode,creature=creature,effects=values,amount=amount,current=3)))
out=m.root/'backups/animations/native-modify-attacks-effect-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
