"""Original negative-level constructor/apply/remove, class counters and total
level queries. Actual copy constructors, class-level getters/setter and FNV hash
execute. Captured allocation/base construction, VM, rule lookup, SetCreator,
immunity/feedback, nested effects, slot refresh and event delivery are lower
boundaries. Synthetic valid canonical class ownership, not campaign/render proof.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,source,effect,ints,vt,app,stats,sstats,command=[m.heap+n*0x2000 for n in range(9)]
ranges=[(0x14051aa10,0x14051ab8d),(0x14042f500,0x14042fb52),(0x140437bc0,0x140437c52),(0x140415490,0x140415526),(0x1403fa5b0,0x1403fa5d2),(0x14040a960,0x14040a9e6),(0x1403fa4f0,0x1403fa5a4),(0x1404035c0,0x1404036a9),(0x1402ae870,0x1402ae899),(0x140423570,0x140423768),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c)]
def fnv(text):
 value=0xcbf29ce484222325
 for byte in text.encode():value=((value^byte)*0x100000001b3)&0xffffffffffffffff
 return value
rule_names={fnv(name):name for name in ['MAX_NEGATIVE_LEVELS','BONUS_HP_PER_LEVEL_DRAINED']}
signed=lambda value:((value+0x80000000)&0xffffffff)-0x80000000
def allocate(size):
 global allocation
 ptr=m.heap+0x30000+allocation;allocation+=(size+15)&~15;assert allocation<0xc0000;return ptr
def snapshot(ptr):
 flags=int.from_bytes(u.mem_read(ptr+10,2),'little')
 return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(ptr+12),creatorId=m.si(ptr+24)&0xffffffff,spellId=m.si(ptr+28),casterLevel=m.si(ptr+40),showIcon=m.si(ptr+36),exposed=m.si(ptr+32),bypassImmunity=m.si(ptr+0x108),integers=[m.si(m.q(ptr+0x48)+i*4)for i in range(m.si(ptr+0x40))])
def class_records(ptr):return[dict(type=u.mem_read(ptr+0x25c+i*0x188,1)[0],level=u.mem_read(ptr+0x25d+i*0x188,1)[0],penalty=u.mem_read(ptr+0x25e+i*0x188,1)[0])for i in range(u.mem_read(ptr+0xd8,1)[0])]
def hook(u,a,n,_):
 global ids,output,pops
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(actor if c.get('creature',True)else 0)
 elif a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(actor if c.get('source')=='self'else 0 if c.get('source')=='missing'else source)
 elif a==0x140400ab0:calls.append(['immunity',y&255,99 if z==actor else 98 if z==source else None,signed(w)]);m.finish(c.get('immunity',0))
 elif a in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif a==0x1404233d0:
  ids+=int(y!=0);m.wq(x,100+ids if y else 0);m.wq(x+0x48,allocate(32));m.wi(x+0x40,8);m.wi(x+0x20,int(y!=0));m.wi(x+0x24,1);m.wi(x+0x1c,-1);m.wi(x+0x28,-1);m.wi(x+0x18,0x7f000000)
  for i in range(4):m.wi(x+0xc0+i*4,0x7f000000)
  m.finish(x)
 elif a==0x140425110:m.wi(x+0x18,y);m.finish()
 elif a==0x140286110:
  pops+=1;m.wi(y,c.get('amount',1)if pops==1 else c.get('bonus',0));m.finish(0 if c.get('popFail')==pops else 1)
 elif a==0x140286330:output=snapshot(z);m.finish(c.get('push',1))
 elif a==0x1402a4130:
  name=rule_names[y];value=c.get('maximum',100)if name=='MAX_NEGATIVE_LEVELS'else c.get('bonusRule',5);calls.append(['rule',name,signed(z),value]);m.finish(value)
 elif a==0x14048e350:calls.append(['apply',99 if x==actor else 98,snapshot(y),signed(z)]);m.finish()
 elif a==0x140418a60:calls.append(['updateSlots',99 if x==stats else 98,class_records(x)]);m.finish()
 elif a==0x1403fa4f0:calls.append(['classLevel',y&255,signed(z),signed(w)])
 elif a==0x1403fa5b0:calls.append(['classNegative',y&255])
 elif a==0x140415490:calls.append(['setNegative',y&255,z&255])
 elif a==0x1404035c0:calls.append(['level',99 if x==stats else 98,signed(y)])
 elif a==0x1402da770:messages[x]=dict(objectIds=[z&0xffffffff]);m.finish()
 elif a==0x1402d5210:messages[y]=dict(messages[x]);m.finish()
 elif a==0x1403a2480:calls.append(['feedback',99 if x==actor else 98,y&65535,messages[z]]);m.finish()
 elif a==0x1405570b0:calls.append(['event',m.si(rsp+0x30),w&0xffffffff,m.si(rsp+0x28)&0xffffffff,snapshot(m.q(rsp+0x38))]);m.finish(1)
 elif a==0x14055b960:m.finish(app)
 elif a==0x140115890:
  line=m.si(rsp+0x28);calls.append(['warning','nMultiClass < m_nNumMultiClasses'if line==0x25d4 else'Your character has no class! What are you doing?']);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a in [0x140c10360,0x140c10370,0x140423770,0x140c11414]:m.finish()
 elif a==0x140047300:u.mem_write(x,bytes(12));m.finish(x)
 elif a==0x140c42060:u.mem_write(x,bytes(z));m.finish(x)
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected negative-level dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def raw(address,args):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x1000,bytes(0x1100));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;return u.reg_read(UC_X86_REG_RAX)&0xffffffff
def run(case):
 global c,calls,ids,allocation,output,messages,pops
 c=case;calls=[];ids=allocation=pops=0;output=None;messages={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app)
 m.wq(actor,vt);m.wq(source,vt);m.wq(vt+0x60,m.stop+0x10);m.wi(actor+8,99);m.wi(source+8,98);m.wq(actor+0xad0,stats);m.wq(source+0xad0,sstats);m.wq(stats+0x30,actor);m.wq(sstats+0x30,source);m.wi(command+12,99)
 for ptr,records in [(stats,c.get('classes',[dict(type=4,level=3,penalty=0)])),(sstats,c.get('sourceClasses',[dict(type=10,level=9,penalty=0)]))]:
  u.mem_write(ptr+0xd8,bytes([len(records)]))
  for i,r in enumerate(records):u.mem_write(ptr+0x25c+i*0x188,bytes([r.get('type',4)&255,r.get('level',3)&255,r.get('penalty',0)&255]))
 m.wq(effect,77);u.mem_write(effect+8,struct.pack('<HH',82,c.get('subtype',8)|(c.get('durationType',1)&7)));m.wq(effect+0x48,ints);m.wi(effect+0x40,8);m.wf(effect+12,3.25);m.wi(effect+24,99 if c.get('source')=='self'else 98);m.wi(effect+28,11);m.wi(effect+40,7);m.wi(effect+32,1);m.wi(effect+36,1);m.wi(effect+0x108,c.get('bypass',0));m.wi(ints,c.get('amount',1));m.wi(ints+4,c.get('bonus',0))
 entry={'apply':0x14042f500,'remove':0x140437bc0,'constructor':0x14051aa10,'set':0x140415490,'get':0x1403fa5b0,'total':0x14040a960,'level':0x1404035c0}[c['mode']]
 args=[app,actor,effect,c.get('loading',0)]
 if c['mode']=='constructor':args=[command,462,c.get('argc',2)]
 elif c['mode']=='set':args=[stats,c.get('index',0),c.get('value',0)]
 elif c['mode']=='get':args=[stats,c.get('index',0)]
 elif c['mode']=='total':args=[stats]
 elif c['mode']=='level':args=[stats,c.get('penalty',0)]
 try:result=raw(entry,args)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 return dict(case=c,result=result if c['mode']!='set'else None,calls=calls,effect=snapshot(effect),output=output,classes=class_records(stats))
rows=[]
for amount,bonus,argc,maximum in itertools.product([-2147483648,-1,0,1,3,100,101,2147483647],[0,1,-1],[1,2],[0,100,-1]):rows.append(run(dict(mode='constructor',amount=amount,bonus=bonus,argc=argc,maximum=maximum)))
for fields in [dict(popFail=1),dict(popFail=2),dict(push=0)]:rows.append(run(dict(mode='constructor',**fields)))
for loading,dead,duration,creature,bypass,immunity,amount in itertools.product([0,1,2,-1],[0,1],[0,1,2,3,4],[False,True],[0,1],[0,1],[0,1,101]):rows.append(run(dict(mode='apply',loading=loading,dead=dead,durationType=duration,creature=creature,bypass=bypass,immunity=immunity,amount=amount)))
profiles=[[],[dict(level=1)],[dict(level=4,penalty=1)],[dict(level=3),dict(level=3)],[dict(level=4,penalty=3),dict(level=3)],[dict(level=1,penalty=1),dict(level=0)],[dict(level=255,penalty=254),dict(level=255,penalty=0)], [dict(level=3,penalty=1)for _ in range(8)]]
for records,sourcekind,amount,bonus,bonusRule in itertools.product(profiles,['self','other','missing'],[-2147483648,-1,0,1,3,100],[0,1,-1],[5,0,-3]):rows.append(run(dict(mode='apply',classes=records,source=sourcekind,amount=amount,bonus=bonus,bonusRule=bonusRule)))
for records,index,amount in itertools.product(profiles,[-1,0,1,2,255,256],[-2147483648,-1,0,1,256,65535]):rows.append(run(dict(mode='remove',classes=records,bonus=index,amount=amount)))
supports=[]
for records,index,value in itertools.product(profiles,[-1,0,1,7,8,255,256],[-1,0,1,255,256,257]):supports.append(run(dict(mode='set',classes=records,index=index,value=value)))
for records,index in itertools.product(profiles,[-1,0,1,7,8,255,256]):supports.append(run(dict(mode='get',classes=records,index=index)))
for records in profiles:
 supports.append(run(dict(mode='total',classes=records)))
 for penalty in [0,1,-1]:supports.append(run(dict(mode='level',classes=records,penalty=penalty)))
out=m.root/'backups/animations/native-negative-level-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,supports=supports),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),supports=len(supports),output=str(out))))
