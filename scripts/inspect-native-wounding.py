"""Original wounding/vampiric apply owners, ApplyWounding damage/visual owner
and wounding UpdateEffectList branch. Original copy, INT access, damage-index
and world subtraction execute. Base construction/allocation, SetNumIntegers,
SetCreator, active blood string, source/dead providers and event/apply boundaries
are captured. Allocation failure is a native null dereference, not exercised.
"""
import importlib,itertools,json,struct
from native_effect_copy_fixture import NativeEffectCopyFixture
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,effect,ints,source,vt,app,timer,rules,tables,blood=[m.heap+n*0x1000 for n in range(10)]
copy=NativeEffectCopyFixture(m)
ranges=[(0x140435640,0x1404356cd),(0x140434d80,0x140434e7a),(0x140382570,0x1403828fb),(0x14049e0ce,0x14049e1e2),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c),(0x1402a3b60,0x1402a3b71),(0x140597a20,0x140597a6b)]
def snapshot(p):
 flags=int.from_bytes(u.mem_read(p+10,2),'little')
 return dict(id=f'{m.q(p):016x}',type=int.from_bytes(u.mem_read(p+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(p+12),creatorId=m.si(p+24)&0xffffffff,spellId=m.si(p+28),casterLevel=m.si(p+40),exposed=m.si(p+32),showIcon=m.si(p+36),integers=[m.si(m.q(p+0x48)+i*4)for i in range(m.si(p+0x40))])
def hook(u,a,n,_):
 global allocations,ids
 if a==m.stop or c['mode']=='poll'and a==0x14049e046:u.emu_stop();return
 if copy.handle(a):return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x100:trace.append(['asCreature']);m.finish(actor if c.get('creature',True)else 0)
 elif a==0x1404953b0:trace.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x14055b3d0:trace.append(['creature',y&0xffffffff]);m.finish(source if c.get('source',True)else 0)
 elif a==0x140c10324:allocations+=1;assert x==0x110;m.finish(m.heap+0x10000+allocations*0x1000)
 elif a==0x1404233d0:
  ids+=1;copy.prepare(x);m.wq(x,100+ids);m.wq(x+0x48,x+0x200);m.wi(x+32,1);m.wi(x+36,1);m.wi(x+28,-1);m.wi(x+40,-1);m.wi(x+24,0x7f000000);m.finish(x)
 elif a==0x140425110:m.wi(x+24,y);m.wi(x+28,c.get('spell',-1));m.wi(x+40,c.get('casterLevel',-1));m.finish()
 elif a==0x140425230:assert y==39;m.wi(x+0x40,y);m.finish()
 elif a==0x14048e350:trace.append(['apply',m.si(x+8)&0xffffffff,snapshot(y),z&0xffffffff]);m.finish()
 elif a==0x14055b960:m.finish(app)
 elif a==0x1405570b0:trace.append(['event',m.si(rsp+0x30),w&0xffffffff,m.si(rsp+0x28)&0xffffffff,snapshot(m.q(rsp+0x38))]);m.finish()
 elif a==0x1401a68f0:
  column=bytes(u.mem_read(m.q(z),16)).split(b'\0')[0].decode();trace.append(['blood',y&0xffffffff,column]);value=c.get('blood','R').encode()+b'\0';u.mem_write(blood,value);m.wq(w,blood);m.wi(w+8,len(value)-1);m.finish(1)
 elif a==0x140c10368:assert x==10;m.finish(m.heap+0x30000)
 elif a==0x140c10370:m.finish()
 elif a==0x140115890:trace.append(['warning']);m.finish()
 elif a==0x1402a3b60:trace.append(['damageIndex',y&0xffffffff])
 elif a==0x140382570 and c['mode']=='poll':trace.append(['tick']);m.finish(1)
 elif a==0x140597a20:trace.append(['subtract',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff])
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unmapped wounding dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,allocations,ids
 c=case;trace=[];allocations=ids=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x100,tables)
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x100);m.wi(actor+8,99);m.wi(source+8,98);m.wi(actor+0xa0,500);m.wi(source+0xa0,c.get('sourceArea',500));m.wi(timer+0x30,c.get('length',1000000));u.mem_write(actor+0x771,bytes([c.get('state',0)&255]));u.mem_write(actor+0xa74,(c.get('appearance',7)&65535).to_bytes(2,'little'))
 m.wq(effect,77);u.mem_write(effect+8,struct.pack('<HH',84,8|(c.get('durationType',2)&7)));m.wq(effect+0x48,ints);copy.prepare(effect);m.wf(effect+12,3.25);m.wi(effect+24,98);m.wi(effect+28,11);m.wi(effect+40,7);m.wi(effect+32,1);m.wi(effect+36,c.get('showIcon',1))
 for i,v in enumerate(c.get('integers',[4,3,500,0,0,0,0,0])):m.wi(ints+i*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);args=[]
 if c['mode']=='apply':entry=0x140435640;args=[app,actor,0 if c.get('nullEffect')else effect,c.get('loading',0)]
 elif c['mode']=='vampiric':entry=0x140434d80;args=[app,actor,effect,c.get('loading',0)]
 elif c['mode']=='tick':entry=0x140382570;args=[actor,effect]
 else:
  entry=0x14049e0ce;rsp=m.stack+0x1fe00;u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rsp+0xa0);now=c.get('now',dict(day=3,time=6501))
  for reg,value in[(UC_X86_REG_R14,effect),(UC_X86_REG_R15,actor),(UC_X86_REG_RSI,timer),(UC_X86_REG_R13,now['day']),(UC_X86_REG_RDI,now['time'])]:u.reg_write(reg,value)
  m.wi(rsp+0x48,c.get('scratch',dict(day=0,time=0))['time']);m.wi(rsp+0x4c,c.get('scratch',dict(day=0,time=0))['day'])
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v)
 try:u.emu_start(entry,m.stop,count=50000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==(0x14049e046 if c['mode']=='poll'else m.stop)
 return dict(case=c,trace=trace,effect=snapshot(effect),result=None if c['mode']=='poll'else u.reg_read(UC_X86_REG_RAX)&0xffffffff,scratch=dict(day=m.si(rsp+0x4c)&0xffffffff,time=m.si(rsp+0x48)&0xffffffff)if c['mode']=='poll'else None)
cases=[dict(mode='apply',durationType=dt,showIcon=icon,loading=loading)for dt,icon,loading in itertools.product(range(5),[0,1],[0,1,0xffffffff])]+[dict(mode='apply',nullEffect=True)]
cases +=[dict(mode='vampiric',integers=[a,b]+[0]*6,source=source,loading=loading)for a,b,source,loading in itertools.product([-2147483648,-1,0,4,2147483647],[-1,0,7,2147483647],[False,True],[0,1])]
cases +=[dict(mode='tick',blood=b,state=s,integers=[v,0,0,0,0,0,0,0])for b,s,v in itertools.product(['R','G','Y','W','','r','Red','R\0X'],[0,15,271],[-1,0,1,2147483647])]
cases +=[dict(mode='poll',now=now,creature=creature,dead=dead,source=source,sourceArea=area)for now,creature,dead,source,area in itertools.product([dict(day=3,time=6500),dict(day=3,time=6501),dict(day=4,time=500),dict(day=3,time=499)],[False,True],[0,1],[False,True],[500,501])]
cases +=[dict(mode='poll',now=dict(day=2,time=500),scratch=dict(day=6,time=t))for t in[0,6000,6001,0xffffffff]]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-wounding-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),copies=copy.executions)))
