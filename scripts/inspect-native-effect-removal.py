"""Original RemoveEffectById and RemoveEffectTarget with original CopyEffect
assignment and operator==. Captured lower allocation/string/base construction,
object lookup, onRemove callbacks and creature pointer/attribute update providers.
Scripted reentrant mutations exercise the coordinator, not real polymorph.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,source,vt,svt,pool,targets,app=[m.heap+n*0x1000 for n in range(7)]
ranges=[(0x140498280,0x1404984aa),(0x1404986c0,0x140498852),(0x140423ce0,0x140423f86),(0x140423ac0,0x140423cb5),(0x14049dae0,0x14049e829),(0x140423fa0,0x140423fb3),(0x140596e50,0x140596e83)]

def allocate(size):
 global allocation
 ptr=m.heap+0x30000+allocation;allocation+=(size+15)&~15;assert allocation<0x60000;return ptr

def string_at(ptr):
 value=m.q(ptr);return bytes(u.mem_read(value,m.si(ptr+8))).decode('cp1252')if value else''

def store_string(ptr,value):
 value=value.encode('cp1252');target=allocate(len(value)+1);u.mem_write(target,value+b'\0');m.wq(ptr,target if value else 0);m.wi(ptr+8,len(value))

def snapshot(ptr):
 flags=int.from_bytes(u.mem_read(ptr+10,2),'little')
 result=dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(ptr+12),creatorId=m.si(ptr+24)&0xffffffff,spellId=m.si(ptr+28),casterLevel=m.si(ptr+40),showIcon=m.si(ptr+36),exposed=m.si(ptr+32),bypassImmunity=m.si(ptr+0x108),propertyId=f'{m.q(ptr+0xf0):016x}',customTag=string_at(ptr+0xf8),integers=[m.si(m.q(ptr+0x48)+i*4)for i in range(m.si(ptr+0x40))],strings=[string_at(ptr+0x60+i*16)for i in range(6)],floats=[m.rf(ptr+0x50+i*4)for i in range(4)],objectIds=[m.si(ptr+0xc0+i*4)&0xffffffff for i in range(4)],vectors=[[m.rf(ptr+0xd0+j*12+i*4)for i in range(3)]for j in range(2)])
 if c.get('mode')=='update':result.update(expiryDay=m.si(ptr+16)&0xffffffff,expiryTime=m.si(ptr+20)&0xffffffff)
 return result

def pointers():return[m.q(pool+i*8)for i in range(m.si(actor+0x158))]
def set_pointers(values):
 m.wi(actor+0x158,len(values))
 for i,value in enumerate(values):m.wq(pool+i*8,value)

def new_effect(value):
 ptr=allocate(0x110);m.wq(ptr,value.get('id',77));u.mem_write(ptr+8,struct.pack('<HH',value.get('type',62),value.get('subtype',8)|(value.get('durationType',2)&7)));m.wf(ptr+12,3.25);m.wi(ptr+24,value.get('creatorId',98));m.wi(ptr+28,11);m.wi(ptr+40,7);m.wi(ptr+32,1);m.wi(ptr+36,1);m.wq(ptr+0xf0,123);m.wi(ptr+0x40,8);m.wq(ptr+0x48,allocate(32));m.wi(m.q(ptr+0x48),value.get('integer',1))
 for i in range(4):m.wi(ptr+0xc0+i*4,0x7f000000)
 m.wi(ptr+16,value.get('expiryDay',0));m.wi(ptr+20,value.get('expiryTime',0))
 store_string(ptr+0x60,'fixture');return ptr

def mutate(ptr,kind):
 live=pointers()
 if kind=='remove':set_pointers([p for p in live if p!=ptr])
 elif kind=='clear':set_pointers([])
 elif kind=='integer':m.wi(m.q(ptr+0x48),2)
 elif kind=='creator':m.wi(ptr+24,97)
 elif kind=='flags':u.mem_write(ptr+10,struct.pack('<H',9))
 elif kind=='ignored':m.wf(ptr+12,0.5);m.wi(ptr+16,100);m.wi(ptr+32,0);m.wi(ptr+36,0)
 elif kind=='replace':
  replacement=allocate(0x110);u.mem_write(replacement,bytes(u.mem_read(ptr,0x110)));data=allocate(32);u.mem_write(data,bytes(u.mem_read(m.q(ptr+0x48),32)));m.wq(replacement+0x48,data);set_pointers([replacement if p==ptr else p for p in live])
 elif kind=='reverse':set_pointers(live[::-1])
 elif kind=='append':set_pointers(live+[new_effect({})])
 elif kind=='prepend':set_pointers([new_effect({})]+live)
 elif kind=='sourceGone':c['sourceExists']=False
 elif kind=='targetGone':c['targetExists']=False
 elif kind=='targetNotWorld':c['targetWorld']=False
 elif kind=='defer':
  m.wi(m.q(ptr+0x48)+4,1);u.mem_write(ptr+10,struct.pack('<H',9));m.wf(ptr+12,0.5);m.wi(ptr+16,c.get('day',0));m.wi(ptr+20,c.get('time',101)+500)

def hook(u,a,n,_):
 global callback_count
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14055b960:m.finish(app)
 elif a==0x14055b2c0:m.finish(app)
 elif a==0x14055b4c0:m.finish(source if y==98 and c.get('sourceExists',True)else actor if y==99 and c.get('targetExists',True)else 0)
 elif a==m.stop+0x10:m.finish(actor if c.get('targetWorld',True)else 0)
 elif a==m.stop+0x20:m.finish(source if c.get('sourceWorld',True)else 0)
 elif a==m.stop+0x30:calls.append(['pointers']);m.finish()
 elif a==m.stop+0x40:calls.append(['attributes',snapshot(y),z]);m.finish()
 elif a==m.stop+0x50:m.finish(actor if c.get('objectType',5)==5 else 0)
 elif a==0x14049db92:calls.append(['poll',snapshot(u.reg_read(UC_X86_REG_R14))])
 elif a==0x140559480:
  calls.append(['callback',snapshot(z)]);callback_count+=1
  if callback_count==1:mutate(z,c.get('mutation','none'))
  status=c.get('statuses',[1]);m.finish(status[min(callback_count-1,len(status)-1)])
 elif a==0x1404986c0:calls.append(['target',y&0xffffffff])
 elif a in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif a==0x1404233d0:
  m.wq(x+0x48,allocate(32));m.wi(x+0x40,8);m.wi(x+0x24,1);m.wi(x+0x18,0x7f000000);m.wi(x+28,-1);m.wi(x+40,-1)
  for i in range(4):m.wi(x+0xc0+i*4,0x7f000000)
  m.finish(x)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a in [0x140423770,0x140c10360,0x140c10370,0x140c11414]:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x140047300:u.mem_write(x,bytes(12));m.finish(x)
 elif a==0x140c42060:u.mem_write(x,bytes(z));m.finish(x)
 elif a==0x14003d8c0:store_string(x,bytes(u.mem_read(y,z)).decode('cp1252'));m.finish(x)
 elif a==0x140169e90:m.finish(int(string_at(x)!=string_at(y)))
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected effect removal dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,allocation,callback_count
 c=dict(case);calls=[];allocation=callback_count=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app)
 m.wq(actor,vt);m.wq(source,svt);m.wq(vt+0x20,m.stop+0x10);m.wq(svt+0x20,m.stop+0x20);m.wq(vt+0x1d0,m.stop+0x30);m.wq(vt+0x1d8,m.stop+0x40);m.wi(actor+8,99);u.mem_write(actor+12,bytes([c.get('objectType',5)]));m.wi(source+8,98);m.wq(actor+0x150,pool);m.wq(source+0x170,targets)
 m.wq(vt+0x60,m.stop+0x50);m.wi(app+0x30,1000000)
 initial=[new_effect(v)for v in c.get('effects',[])];set_pointers(initial)
 owned=c.get('targets',[1,99,2]);m.wi(source+0x178,len(owned));m.wi(source+0x17c,max(len(owned),16))
 for i,value in enumerate(owned):m.wi(targets+i*4,value)
 before=[snapshot(p)for p in initial];rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,c.get('id',77))
 entry=0x140498280
 if c.get('mode')=='update':entry=0x14049dae0;u.reg_write(UC_X86_REG_RDX,c.get('day',0));u.reg_write(UC_X86_REG_R8,c.get('time',101))
 try:u.emu_start(entry,m.stop,count=200000)
 except Exception:print(json.dumps(dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=case,before=before,result=None if c.get('mode')=='update'else u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,effects=[snapshot(p)for p in pointers()],targets=[m.si(targets+i*4)&0xffffffff for i in range(m.si(source+0x178))])

layouts=[[],[{}],[{},{}],[{'id':78},{},{'id':78},{}],[{'creatorId':97},{}],[{'id':78,'creatorId':98},{}]]
rows=[]
for effects,statuses,mutation,objectType in itertools.product(layouts,[[1],[0],[2],[0,1],[1,0]],['none','remove','clear','integer','creator','flags','ignored','replace','reverse','append','prepend','sourceGone','targetGone','targetNotWorld'],[5,6]):
 rows.append(run(dict(effects=effects,statuses=statuses,mutation=mutation,objectType=objectType)))
for ownedTargets,sourceWorld,targetWorld,sourceExists,targetExists in itertools.product([[],[99],[1,2],list(range(20)),list(range(18))+[99],list(range(18))+[99,99]],[False,True],[False,True],[False,True],[False,True]):
 rows.append(run(dict(effects=[{}],targets=ownedTargets,sourceWorld=sourceWorld,targetWorld=targetWorld,sourceExists=sourceExists,targetExists=targetExists)))
updates=[]
for count,time,mutation,objectType in itertools.product([1,2,4],[99,100,101,600,601,602],['none','defer','remove','clear','replace','append','prepend','sourceGone','targetGone'],[5,6]):
 updates.append(run(dict(mode='update',effects=[dict(type=55+i,durationType=1,expiryTime=100)for i in range(count)],time=time,mutation=mutation,statuses=[0,1]if mutation=='defer'else[1],objectType=objectType)))
out=m.root/'backups/animations/native-effect-removal-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,updates=updates),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),updates=len(updates),output=str(out))))
