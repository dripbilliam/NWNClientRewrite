"""Unchanged complete Explosion1400647c0 and Single140065cd0 Updates with
full native lifetime. Particle construction/init/randomization/movement, source
scale, backing arrays, destruction and WindManager point source are captured
lower boundaries with explicit synthetic responses. This checks the complete
owner control/state/list/call ordering, not coupled particle physics or drawing.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,node,gob,vt,particlevt,scene=[m.heap+n*0x1000 for n in range(6)]
def vector(ptr,values):
 for i,v in enumerate(values):m.wf(ptr+i*4,v)
def read(ptr):return[m.rf(ptr+i*4)for i in range(3)]
def ids(ptr,count):return[names[m.q(ptr+i*8)]for i in range(count)]
def allocate_array(old,size):
 global allocation
 ptr=m.heap+0x90000+allocation*0x1000;allocation+=1
 if old:u.mem_write(ptr,bytes(u.mem_read(old,min(size,0x1000))))
 return ptr
def initialize(ptr,id,age=0):
 names[ptr]=id;m.wq(ptr,particlevt);m.wf(ptr+0x74,age);m.wi(ptr+0x48,100+id);m.wf(ptr+0x1c,7 if id%2==0 else -7)
 vector(ptr+0x10,[.5+id,1+id,1.5+id]);vector(ptr+0x64,[-1,-2,-3])
 chunk=m.heap+0x60000+id*0x100;names[chunk]=id;m.wq(ptr+0x78,chunk if id%2==0 else 0);m.wq(chunk,vt)
def hook(u,a,n,_):
 global allocation,newcount
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10324:
  ptr=m.heap+0x30000+newcount*0x100;names[ptr]=nextid+newcount;newcount+=1;m.finish(ptr)
 elif a==0x140c4f038:calls.append(['reserveFree',y//8]);m.finish(allocate_array(x,y))
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a in [0x140060680,0x1400602b0]:
  id=names[x];initialize(x,id);calls.append(['construct',id,int(a==0x1400602b0),m.xmm(UC_X86_REG_XMM2)]);m.finish(x)
 elif a==0x140061010:
  count,capacity=m.si(x+8),m.si(x+12)
  if count==capacity:
   capacity=16 if capacity==0 else capacity*2;calls.append(['reserveActive',capacity]);m.wi(x+12,capacity);m.wq(x,allocate_array(m.q(x),capacity*8))
  m.wq(m.q(x)+count*8,y);m.wi(x+8,count+1);m.finish()
 elif a==0x1400660c0:calls.append(['randomize',names[y]]);m.finish()
 elif a==m.stop+0x10:calls.append(['detach',names[x],y&0xffffffff]);m.finish()
 elif a==m.stop+0x20:
  calls.append(['move',m.xmm(UC_X86_REG_XMM1),ids(m.q(emitter+0x188),m.si(emitter+0x190))])
  if c.get('moveDetonate')is not None:u.mem_write(emitter+0x108,bytes([c['moveDetonate']]))
  m.finish()
 elif a==m.stop+0x30:
  calls.append(['source',c['factor']]);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c['factor']),'little'));m.finish()
 elif a==m.stop+0x40:
  factor=m.xmm(UC_X86_REG_XMM2);calls.append(['initialize',names[x],m.xmm(UC_X86_REG_XMM1),factor]);m.wf(x+0x74,0);m.wf(x+0x1c,0);vector(x+0x10,[(i+1)*factor for i in range(3)]);m.finish()
 elif a==m.stop+0x50:calls.append(['destroy',names[x],y&0xffffffff]);m.finish()
 elif a==0x1400f1250:calls.append(['wind',read(y),m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28)]);m.finish()
 elif not(0x1400647c0<=a<0x140064b29 or 0x140065cd0<=a<0x140065f05 or 0x140065f10<=a<0x1400660bf):raise RuntimeError(f'Unexpected native dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,newcount,names,nextid
 c=case;calls=[];allocation=newcount=0;names={};nextid=len(c['ages'])+c['freeCount'];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(emitter+8,node);m.wf(emitter+0x74,c['rate']);m.wf(emitter+0xac,c['life']);m.wf(emitter+0xbc,2.25);m.wf(emitter+0xe8,.3);m.wf(emitter+0x1c8,c['latch']);u.mem_write(emitter+0x108,bytes([c['detonate']]))
 m.wi(node+0x16c,c['loop']);m.wi(emitter+0x1a8,c['renderMode']);u.mem_write(node+0x158,b'x'if c['chunk']else b'\0');m.wf(node+0xa4,c['blastRadius']);m.wf(node+0xa8,.5);vector(emitter+0x1e0,[1.25,-.5,.75])
 m.wq(emitter+0x170,m.stop+0x20);m.wq(emitter+0x50,gob if c['source']else 0);m.wq(gob,vt);m.wq(vt+0x2d0,m.stop+0x30);m.wq(vt+0x90,m.stop+0x10);m.wq(particlevt+0x10,m.stop+0x40);m.wq(particlevt,m.stop+0x50)
 m.wq(0x14140ac50,scene);m.wq(scene+0x160,m.heap+0x70000)
 m.wq(emitter+0x188,m.heap+0x8000 if c['ages']else 0);m.wi(emitter+0x190,len(c['ages']));m.wi(emitter+0x194,16 if c['ages']else 0)
 m.wq(emitter+0x130,m.heap+0x9000 if c['freeCount']else 0);m.wi(emitter+0x138,c['freeCount']);m.wi(emitter+0x13c,16 if c['freeCount']else 0)
 for i,age in enumerate(c['ages']):ptr=m.heap+0x10000+i*0x100;initialize(ptr,i,age);m.wq(m.q(emitter+0x188)+i*8,ptr)
 for i in range(c['freeCount']):id=len(c['ages'])+i;ptr=m.heap+0x10000+id*0x100;initialize(ptr,id);m.wq(m.q(emitter+0x130)+i*8,ptr)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,emitter);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['delta']),'little'))
 try:u.emu_start(0x1400647c0 if c['kind']=='Explosion'else 0x140065cd0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 activeids=ids(m.q(emitter+0x188),m.si(emitter+0x190));freeids=ids(m.q(emitter+0x130),m.si(emitter+0x138));pointers={id:ptr for ptr,id in names.items()if ptr<m.heap+0x60000}
 return dict(case=c,calls=calls,active=activeids,free=freeids,activeCapacity=m.si(emitter+0x194),freeCapacity=m.si(emitter+0x13c),latch=m.rf(emitter+0x1c8),detonate=u.mem_read(emitter+0x108,1)[0],particles=[dict(id=id,age=m.rf(ptr+0x74),field48=m.si(ptr+0x48),rotation=m.rf(ptr+0x1c),position=read(ptr+0x10),trail=read(ptr+0x64))for id,ptr in sorted(pointers.items())])
def case(kind,**kw):return dict(kind=kind,rate=3.5,delta=.25,life=1,ages=[],freeCount=0,chunk=0,source=1,factor=.75,renderMode=0,latch=0,detonate=1,blastRadius=2,loop=0,**kw)
# Explicit construction avoids duplicate keyword defaults in helper calls.
def profile(kind,**kw):c=case(kind);c.update(kw);return c
rows=[run(profile('Explosion',rate=rate,delta=delta,detonate=detonate,latch=latch,renderMode=mode,ages=ages,freeCount=free,chunk=chunk))for rate,delta,detonate,latch,(mode,ages,free,chunk)in itertools.product([-2,0,.5,3.5],[-.2,0,.1,.6],[0,1],[0,.75,1,2],[(0,[],0,0),(6,[.25,1.25],1,1)])]
rows.extend(run(profile('Single',rate=rate,delta=delta,life=life,loop=loop,ages=ages,renderMode=mode))for rate,delta,life,loop,(ages,mode)in itertools.product([-2,0,.5,1.9],[-.5,0,.25,1.25],[-1,0,1],[0,1],[([],0),([.25],6),([1.25],0),([.25,.5],6)]))
rows.extend(run(profile(kind,**kw))for kind,kw in [('Explosion',dict(source=0,blastRadius=0)),('Explosion',dict(moveDetonate=0)),('Explosion',dict(detonate=0,moveDetonate=1)),('Explosion',dict(rate=20,source=0,blastRadius=0)),('Single',dict(chunk=1)),('Single',dict(rate=0,ages=[.25,.5],chunk=1)),('Single',dict(rate=1,ages=[.75],delta=.25,loop=1))])
out=m.root/'backups/animations/native-burst-single-update-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
