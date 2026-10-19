"""Original SpellFailure/MissChance VM constructors and both school/arcane
apply/remove handlers. Original clearing copies, scalar accessors and both cache
setters execute. VM/base allocation/free, object/dead, child application, std
function cleanup and synchronous UpdateCombatInformation are captured
lower boundaries; no complete combat-cache or casting-release acceptance claim.
"""
import importlib,itertools,json,struct
from native_effect_copy_fixture import NativeEffectCopyFixture
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,stats,effect,ints,pool,vt,commands,app=[m.heap+n*0x3000 for n in range(8)];copy=NativeEffectCopyFixture(m)
ranges=[(0x14051b940,0x14051bb37),(0x14051a5d0,0x14051a72a),(0x140433700,0x1404338ee),(0x140438920,0x140438a7d),(0x140427330,0x140427402),(0x140435db0,0x140435eaa),(0x140416ae0,0x140416af1),(0x140415250,0x14041525b),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]
# Verified direct-call cookie target: compare/rotate/test/RET success path only;
# unlike a generic finish(0), it preserves the owner's EAX error return.
ranges.append((0x140c10410,0x140c10428))
def snapshot(e):
 flags=int.from_bytes(u.mem_read(e+10,2),'little');return dict(id=f'{m.q(e):016x}',type=int.from_bytes(u.mem_read(e+8,2),'little'),subtype=flags&~7,durationType=flags&7,creatorId=m.si(e+24)&0xffffffff,spellId=m.si(e+28),casterLevel=m.si(e+40),exposed=m.si(e+32),showIcon=m.si(e+36),integers=[m.si(m.q(e+0x48)+i*4)for i in range(8)])
def hook(u,a,n,_):
 global cursor,pops,output
 if a==m.stop:u.emu_stop();return
 if copy.handle(a):return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop+0x10:calls.append(['creature']);m.finish(actor if c.get('creature',True) else 0)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x140c10324:cursor+=0x1000;m.finish(m.heap+cursor)
 elif a==0x1404233d0:m.wq(x,101);m.wq(x+0x48,x+0x400);m.wi(x+0x40,8);m.wi(x+24,0x7f000000);m.wi(x+28,-1);m.wi(x+40,-1);m.wi(x+32,1);m.wi(x+36,1);m.finish(x)
 elif a==0x140425110:calls.append(['creator',y&0xffffffff]);m.wi(x+24,y);m.finish()
 elif a==0x140286110:
  pops+=1;calls.append(['pop']);values=[c.get('amount',50),c.get('school',0),c.get('kind',0)]if c['mode']=='constructor' else[c.get('amount',50),c.get('kind',0)];m.wi(y,values[pops-1]);m.finish(0 if c.get('failPop')==pops else 1)
 elif a==0x140286330:output=snapshot(z);calls.append(['push']);m.finish(c.get('push',1))
 elif a in [0x140423770,0x140c10360,0x140553430,0x140553780]:m.finish()
 elif a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(1)
 elif a==0x1404171e0:calls.append(['updateCombat']);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected spell failure dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,pops,output
 c=case;calls=[];cursor=0x50000;pops=0;output=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(actor+0xad0,stats);m.wq(0x1412df910,app);m.wi(commands+12,98)
 m.wq(effect,77);m.wq(effect+0x48,ints);u.mem_write(effect+8,struct.pack('<HH',c.get('type',92),8|c.get('durationType',2)));m.wi(effect+24,98);m.wi(effect+28,11);m.wi(effect+40,7);m.wi(effect+32,1);m.wi(effect+36,c.get('showIcon',1));copy.prepare(effect);m.wi(ints,c.get('amount',50));m.wi(ints+4,c.get('school',0))
 u.mem_write(stats+0xd78,bytes([c.get('cache',0)&255]));u.mem_write(stats+0xd7b,bytes(range(9,18)));m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])))
 for i,e in enumerate(c.get('effects',[])):
  ptr=effect if e.get('samePointer') else m.heap+0x30000+i*0x200;m.wq(pool+i*8,ptr)
  if ptr!=effect:m.wq(ptr,e.get('id',88));m.wq(ptr+0x48,ptr+0x100);u.mem_write(ptr+8,struct.pack('<H',e['type']));m.wi(ptr+0x100,e.get('amount',0));m.wi(ptr+0x104,e.get('school',0))
 mode=c['mode'];entry=0x14051b940 if mode=='constructor' else 0x14051a5d0 if mode=='miss' else {(92,'apply'):0x140433700,(92,'remove'):0x140438920,(25,'apply'):0x140427330,(25,'remove'):0x140435db0}[(c.get('type',92),mode)]
 args=[commands,690 if mode=='constructor' else 477,c.get('argc',3 if mode=='constructor' else 2),0] if mode in ['constructor','miss'] else [app,actor,0 if c.get('nullEffect') else effect,c.get('loading',0)]
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(r,v)
 u.emu_start(entry,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;return dict(case=c,result=(result^0x80000000)-0x80000000,calls=calls,output=output,arcane=u.mem_read(stats+0xd78,1)[0],schools=list(u.mem_read(stats+0xd7b,9)),dirty=m.si(actor+0x53c))
rows=[]
for type_,creature,loading,dead,duration,amount in itertools.product([25,92],[False,True],[0,1],[0,1],range(5),[-5,0,50,150]):rows.append(run(dict(mode='apply',type=type_,creature=creature,loading=loading,dead=dead,durationType=duration,amount=amount)))
for type_,mode,school,amount in itertools.product([25,92],['apply','remove'],[-1,0,3,8,9,256],[-2147483648,100,2147483647]):
 lists=[[],[dict(type=type_,amount=70,school=school)],[dict(type=type_,amount=80,school=school,id=77),dict(type=type_,amount=15,school=school,id=88)],
 [dict(type=type_,samePointer=True),dict(type=type_,amount=-20,school=school,id=77)],[dict(type=type_-1,amount=999),dict(type=type_,amount=20,school=school),dict(type=type_+1,amount=999)],
 [dict(type=type_+1,amount=999),dict(type=type_,amount=20,school=school)],[dict(type=type_,amount=20,school=(school+1)&255)]]
 for values in lists:rows.append(run(dict(mode=mode,type=type_,school=school,amount=amount,effects=values)))
for cache,amount in itertools.product([-128,-100,-1,0,100,127],[-2147483648,-150,-10,0,30,2147483647]):rows.append(run(dict(mode='apply',type=25,cache=cache,amount=amount)))
for type_,mode,creature in itertools.product([25,92],['apply','remove'],[False,True]):rows.append(run(dict(mode=mode,type=type_,creature=creature,nullEffect=True,cache=99)))
for argc,amount,school,kind in itertools.product([1,2,3],[-2147483648,-5,0,100,2147483647],[-1,0,8,9,256],[-1,0,1,2]):rows.append(run(dict(mode='constructor',argc=argc,amount=amount,school=school,kind=kind)))
for argc,amount,kind in itertools.product([1,2],[-2147483648,-1,0,1,50,100,101,2147483647],[-1,0,1,2,3]):rows.append(run(dict(mode='miss',argc=argc,amount=amount,kind=kind)))
for mode,maxPops in [('constructor',3),('miss',2)]:
 for i in range(1,maxPops+1):rows.append(run(dict(mode=mode,failPop=i)))
 rows.append(run(dict(mode=mode,push=0)))
out=m.root/'backups/animations/native-spell-failure-effects-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,copyConstructorExecutions=copy.executions,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy.executions,output=str(out))))
