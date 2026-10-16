"""Original regeneration constructor/apply and verified update branch, complete
healing/resurrection handlers and resurrection GUI message sender. Actual world
subtraction and copy constructor execute. Allocation/base construction, VM pops/
pushes, nested apply, removal, feedback and HP/dead/time providers are captured.
Not the whole scheduler, lower damage/AI/encumbrance owners, renderer or campaign.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,effect,ints,vt,app,timer,command,source,pool=[m.heap+n*0x1000 for n in range(9)]
ranges=[(0x140430d80,0x140430e60),(0x14049dba3,0x14049dd55),(0x140597a20,0x140597a6b),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c),(0x140423570,0x140423768),(0x1405180b0,0x140518a6e),(0x14042df10,0x14042e32e),(0x140430e60,0x140430fd7),(0x14051ad30,0x14051adf2),(0x1404d5ec0,0x1404d5ee4)]
def allocate(size):
 global allocation
 target=m.heap+0x10000+allocation;allocation+=(size+15)&~15;assert allocation<0xe0000;return target
def snapshot(ptr):
 flags=int.from_bytes(u.mem_read(ptr+10,2),'little')
 return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(ptr+12),creatorId=m.si(ptr+24)&0xffffffff,spellId=m.si(ptr+28),casterLevel=m.si(ptr+40),showIcon=m.si(ptr+36),exposed=m.si(ptr+32),bypassImmunity=m.si(ptr+0x108),integers=[m.si(m.q(ptr+0x48)+i*4)for i in range(m.si(ptr+0x40))])
def hook(u,a,n,_):
 global output,ids
 if a==m.stop or c['mode']=='poll'and a in [0x14049e042,0x14049e046,0x14049e04a]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(actor if c.get('creature',True)else 0)
 elif a in [m.stop+0x40,m.stop+0x50]:m.finish(actor if c.get('slot')==('30'if a==m.stop+0x40 else'98')else 0)
 elif a==m.stop+0x20:
  if c['mode']not in ['heal','resurrect']:calls.append(['maximum',y&0xffffffff])
  m.finish(c.get('maximum',20)&65535)
 elif a==m.stop+0x30:
  if c['mode']not in ['heal','resurrect']:calls.append(['current',y&0xffffffff])
  m.finish((m.si(actor+0xe0)+(c.get('temporaryHP',0)if y==0 else 0))&65535)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x140495620:calls.append(['dying']);m.finish(c.get('dying',0)if not healed[0]else c.get('dyingAfter',0));healed[0]=True
 elif a==0x14055b3d0:m.finish(actor if c.get('creator')=='self'else source if c.get('creator','other')=='other'else 0)
 elif a==0x1402da770:messages[x]=dict(objectIds=[z&0xffffffff]);m.finish()
 elif a==0x1402da730:messages[x].setdefault('integers',[0])[y]=((z+0x80000000)&0xffffffff)-0x80000000;m.finish()
 elif a==0x1402d5210:messages[y]=dict(messages[x]);m.finish()
 elif a==0x1403a2480:calls.append(['feedback',99 if x==actor else 98,y&65535,messages[z]]);m.finish()
 elif a==0x1403db1e0:calls.append(['encumbrance',y&0xffffffff]);m.finish()
 elif a==0x140490b80:calls.append(['clearActions']);m.finish()
 elif a==0x14039db40:calls.append(['ambient']);m.finish()
 elif a==0x140439ae0:calls.append(['floaty',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(pool+0x1000 if c.get('client')else 0)
 elif a==0x14055b810:m.finish(app)
 elif a==0x1404dc490:calls.append(['message',y&0xffffffff,z&255,w&255,m.q(rsp+0x28),m.si(rsp+0x30)]);m.finish(1)
 elif a==0x140498280:
  calls.append(['remove',f'{y:016x}']);live=[m.q(pool+i*8)for i in range(m.si(actor+0x158))if m.q(m.q(pool+i*8))!=y]
  m.wi(actor+0x158,len(live))
  for i,ptr in enumerate(live):m.wq(pool+i*8,ptr)
  m.finish()
 elif a in [0x14055ba10,0x14055b2c0]:m.finish(timer)
 elif a==0x140597180:calls.append(['time']);m.wi(y,c.get('now',dict(day=3,time=500))['day']);m.wi(z,c.get('now',dict(day=3,time=500))['time']);m.finish()
 elif a==0x140597a20:calls.append(['subtract',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff])
 elif a in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif a==0x1404233d0:
  ids+=int(y!=0);m.wq(x,100+ids if y else 0);m.wq(x+0x48,allocate(32));m.wi(x+0x40,8);m.wi(x+0x20,int(y!=0));m.wi(x+0x24,1);m.wi(x+0x1c,-1);m.wi(x+0x28,-1);m.wi(x+0x18,0x7f000000)
  for i in range(4):m.wi(x+0xc0+i*4,0x7f000000)
  m.finish(x)
 elif a==0x140425110:m.wi(x+0x18,y);m.finish()
 elif a==0x140286110:m.wi(y,c['amount']);m.finish(0 if c.get('popFail')=='int'else 1)
 elif a==0x1402860c0:m.wf(y,c['interval']);m.finish(0 if c.get('popFail')=='float'else 1)
 elif a==0x140286330:output=snapshot(z);m.finish(c.get('push',1))
 elif a==0x14048e350:calls.append(['apply',snapshot(y),((z+0x80000000)&0xffffffff)-0x80000000]);m.finish()
 elif a==0x140047300:u.mem_write(x,bytes(12));m.finish(x)
 elif a==0x140c42060:u.mem_write(x,bytes(z));m.finish(x)
 elif a in [0x140c10360,0x140c10370,0x140423770,0x140c11414,0x14037bd50]:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected regeneration dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,ids,output,messages,healed
 c=case;calls=[];allocation=ids=0;output=None;messages={};healed=[False];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(timer+0x30,c.get('length',1000000));m.wi(actor+8,99);m.wi(command+0xc,98)
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0x130,m.stop+0x20);m.wq(vt+0x138,m.stop+0x30);m.wq(vt+0x30,m.stop+0x40);m.wq(vt+0x98,m.stop+0x50);m.wi(actor+0xe0,c.get('current',5));m.wi(source+8,98);m.wi(actor+0xf4,c.get('raiseable',1));m.wi(pool+0x1048,77)
 m.wq(actor+0x150,pool);m.wi(actor+0x158,len(c.get('effects',[])))
 for i,record in enumerate(c.get('effects',[])):
  ptr=allocate(0x110);m.wq(ptr,record['id']);u.mem_write(ptr+8,struct.pack('<HH',record['type'],record.get('durationType',0)));m.wq(pool+i*8,ptr)
 m.wq(effect,77);u.mem_write(effect+8,struct.pack('<HH',7,8|(c.get('durationType',1)&7)));m.wq(effect+0x48,ints);m.wi(effect+0x40,8);m.wf(effect+12,3.25);m.wi(effect+0x18,98);m.wi(effect+0x1c,11);m.wi(effect+0x28,7);m.wi(effect+0x20,c.get('exposed',1));m.wi(effect+0x24,1);m.wi(effect+0x108,13)
 for i,value in enumerate(c.get('integers',[4,100,3,500,0,0,0,0])):m.wi(ints+i*4,value)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);now=c.get('now',dict(day=3,time=601))
 if c['mode']=='constructor':entry=0x1405180b0;args=[command,164,2]
 elif c['mode']=='resurrectionConstructor':entry=0x14051ad30;args=[command,82,0]
 elif c['mode']=='apply':entry=0x140430d80;args=[app,actor,effect,c.get('loading',0)]
 elif c['mode']=='heal':entry=0x14042df10;args=[app,actor,0 if c.get('nullEffect')else effect,c.get('loading',0)]
 elif c['mode']=='resurrect':entry=0x140430e60;args=[app,actor,effect,c.get('loading',0)]
 else:
  entry=0x14049dba3;args=[];rsp=m.stack+0x1fe00;u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rsp+0xa0)
  for reg,value in [(UC_X86_REG_R14,effect),(UC_X86_REG_R15,actor),(UC_X86_REG_RSI,timer),(UC_X86_REG_R13,now['day']),(UC_X86_REG_RDI,now['time'])]:u.reg_write(reg,value)
  m.wi(rsp+0x44,now['time']);m.wi(rsp+0x48,c.get('scratch',dict(day=0,time=0))['time']);m.wi(rsp+0x4c,c.get('scratch',dict(day=0,time=0))['day'])
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 try:u.emu_start(entry,m.stop,count=20000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 return dict(case=c,calls=calls,effect=snapshot(effect),output=output,result=(u.reg_read(UC_X86_REG_RAX)&0xffffffff)if c['mode']!='poll'else None,scratch=dict(day=m.si(rsp+0x4c)&0xffffffff,time=m.si(rsp+0x48)&0xffffffff)if c['mode']=='poll'else None,hp=m.si(actor+0xe0),state=dict(listening=m.si(actor+0x1ec),commandable=m.si(actor+0xec),flags=int.from_bytes(u.mem_read(actor+0x8d4,2),'little')),liveEffects=[dict(id=f'{m.q(m.q(pool+i*8)):016x}',type=int.from_bytes(u.mem_read(m.q(pool+i*8)+8,2),'little'),durationType=int.from_bytes(u.mem_read(m.q(pool+i*8)+10,2),'little')&7)for i in range(m.si(actor+0x158))])
rows=[]
for amount,interval in itertools.product([-2147483648,-1,0,1,4,2147483647],[-1,0,.0001,.999999,1,6,2147483.5,2147483.75,1e30]):rows.append(run(dict(mode='constructor',amount=amount,interval=interval)))
for fail in ['int','float']:rows.append(run(dict(mode='constructor',amount=4,interval=6,popFail=fail)))
rows.append(run(dict(mode='constructor',amount=4,interval=6,push=0)))
for creature,loading,dt in itertools.product([False,True],[0,1,2,-1],[0,1,2,3,4]):rows.append(run(dict(mode='apply',creature=creature,loading=loading,durationType=dt)))
for creature,dead,current,now,interval in itertools.product([False,True],[0,1],[5,20,25,-1,65535],[dict(day=3,time=599),dict(day=3,time=600),dict(day=3,time=601),dict(day=4,time=500),dict(day=3,time=499)],[0,100,-1]):rows.append(run(dict(mode='poll',creature=creature,dead=dead,current=current,now=now,integers=[4,interval,3,500,0,0,0,0])))
for scratch in [dict(day=0,time=0),dict(day=2,time=500)]:rows.append(run(dict(mode='poll',now=dict(day=2,time=600),scratch=scratch)))
heals=[]
for creature,slot,current,amount,creator,dead in itertools.product([False,True],['','30','98'],[-5,5,20,25,32767,65535],[-2147483648,-1,0,4,100,2147483647],['self','other','missing'],[0,1]):
 if creature and slot or not creature and creator!='other':continue
 heals.append(run(dict(mode='heal',creature=creature,slot=slot,current=current,integers=[amount,0,0,0,0,0,0,0],creator=creator,dead=dead)))
for before,after,loading in itertools.product([0,1,2],[0,1,2],[0,1,-1]):heals.append(run(dict(mode='heal',dying=before,dyingAfter=after,loading=loading)))
for records in [[dict(id=1,type=83),dict(id=2,type=84),dict(id=2,type=84),dict(id=3,type=84),dict(id=4,type=85)],[dict(id=1,type=85),dict(id=2,type=84)]]:heals.append(run(dict(mode='heal',effects=records)))
heals.append(run(dict(mode='heal',nullEffect=True)))
resurrections=[]
for creature,raiseable,current,temporary,exposed,client in itertools.product([False,True],[0,1,-1],[-10,0,1,5,65535],[0,15],[0,1,-1],[False,True]):resurrections.append(run(dict(mode='resurrect',creature=creature,raiseable=raiseable,current=current,temporaryHP=temporary,exposed=exposed,client=client)))
resurrections.append(run(dict(mode='resurrect',effects=[dict(id=1,type=56),dict(id=2,type=57,durationType=1),dict(id=3,type=57,durationType=2),dict(id=4,type=57,durationType=1),dict(id=5,type=58)])))
resurrections.append(run(dict(mode='resurrectionConstructor')))
clocks=[]
for length,day,time,otherday,othertime in itertools.product([0,1000,1000000],[0,1,0xffffffff],[0,1,999,1000000,0xffffffff],[0,1,0xffffffff],[0,1,999,1000000,0xffffffff]):
 calls=[];m.wi(timer+0x30,length);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wi(rsp+0x28,othertime);m.wq(rsp+0x30,ints+0x100);m.wq(rsp+0x38,ints+0x104);m.wi(ints+0x100,0xfeedface);m.wi(ints+0x104,0xdeadbeef)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,timer),(UC_X86_REG_RDX,day),(UC_X86_REG_R8,time),(UC_X86_REG_R9,otherday)]:u.reg_write(reg,value)
 u.emu_start(0x140597a20,m.stop,count=1000);status=u.reg_read(UC_X86_REG_RAX)&0xffffffff;status=status if status<0x80000000 else status-0x100000000
 clocks.append(dict(length=length,a=dict(day=day,time=time),b=dict(day=otherday,time=othertime),status=status,day=m.si(ints+0x100)&0xffffffff,time=m.si(ints+0x104)&0xffffffff))
out=m.root/'backups/animations/native-regeneration-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,clocks=clocks,heals=heals,resurrections=resurrections),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),clocks=len(clocks),heals=len(heals),resurrections=len(resurrections),output=str(out))))
