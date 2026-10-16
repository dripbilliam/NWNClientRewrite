"""Complete unchanged FountainEmitter::Update140064b30 and full
chkParticleLife140065f10. Allocation/memcpy/list Add, source-factor virtual,
particle constructors/virtual initialization, randomization and movement are
captured lower boundaries with explicit synthetic responses. This proves
frame/birth/recycle/placement ordering, not actual particle initialization,
movement, randomness, outer transform/time owner or GPU rendering.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,node,gob,vt,particlevt=[m.heap+n*0x1000 for n in range(5)]
def ids(ptr,count):return[names[m.q(ptr+i*8)]for i in range(count)]
def allocate_array(old,size):
 global allocation
 p=m.heap+0x90000+allocation*0x1000;allocation+=1
 if old:u.mem_write(p,bytes(u.mem_read(old,min(size,0x1000))))
 return p
def initialize(p,id,age=0):
 names[p]=id;m.wq(p,particlevt);m.wf(p+0x74,age);m.wi(p+0x48,100+id);m.wf(p+0x1c,7 if id%2==0 else -7)
 for i,v in enumerate([.5,1,1.5]):m.wf(p+0x10+i*4,v+id)
 for i,v in enumerate([-1,-2,-3]):m.wf(p+0x64+i*4,v)
 chunk=m.heap+0x60000+id*0x100;names[chunk]=id;m.wq(p+0x78,chunk if id%2==0 else 0);m.wq(chunk,vt)
def hook(u,a,n,_):
 global allocation,newcount
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10324:
  p=m.heap+0x30000+newcount*0x100;names[p]=nextid+newcount;newcount+=1;m.finish(p)
 elif a==0x140c4f038:
  label='reserveFree'if m.q(rsp)==0x140066025 else'reserveActive';calls.append([label,y//8]);m.finish(allocate_array(x,y))
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a in [0x140060680,0x1400602b0]:
  id=names[x];initialize(x,id);calls.append(['construct',id,int(a==0x1400602b0),m.xmm(UC_X86_REG_XMM2)]);m.finish(x)
 elif a==0x140061010:
  count,capacity=m.si(x+8),m.si(x+12)
  if count==capacity:
   capacity=16 if capacity==0 else capacity*2;calls.append(['reserveActive',capacity]);m.wi(x+12,capacity);m.wq(x,allocate_array(m.q(x),capacity*8))
  m.wq(m.q(x)+count*8,y);m.wi(x+8,count+1);m.finish()
 elif a==0x1400660c0:
  calls.append(['randomize',names[y]])
  if c.get('mutateAccumulator')is not None:m.wf(emitter+0x198,c['mutateAccumulator'])
  m.finish()
 elif a==m.stop+0x10:calls.append(['detach',names[x],y&0xffffffff]);m.finish()
 elif a==m.stop+0x20:
  calls.append(['move',m.xmm(UC_X86_REG_XMM1),ids(m.q(emitter+0x188),m.si(emitter+0x190))]);m.finish()
 elif a==m.stop+0x30:
  calls.append(['source',c['factor']]);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c['factor']),'little'));m.finish()
 elif a==m.stop+0x40:
  factor=m.xmm(UC_X86_REG_XMM2);calls.append(['initialize',names[x],m.xmm(UC_X86_REG_XMM1),factor]);m.wf(x+0x74,0);m.wf(x+0x1c,0)
  for i in range(3):m.wf(x+0x10+i*4,(i+1)*factor)
  m.finish()
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not(0x140064b30<=a<0x140065281 or 0x140065f10<=a<0x1400660bf):raise RuntimeError(f'Unexpected native dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,newcount,names,nextid
 c=case;calls=[];allocation=newcount=0;names={};nextid=len(c['ages'])+c['freeCount'];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(emitter+8,node);m.wf(emitter+0x74,c['rate']);m.wf(emitter+0xac,1);m.wf(emitter+0xbc,2.25);m.wf(emitter+0xe8,.3);m.wf(emitter+0x198,.05)
 m.wi(node+0xb4,c['spawnType']);m.wi(emitter+0x1a8,c['renderMode']);u.mem_write(node+0x158,b'x'if c['chunk']else b'\0')
 m.wq(emitter+0x170,m.stop+0x20);m.wq(emitter+0x50,gob if c['source']else 0);m.wq(gob,vt);m.wq(vt+0x2d0,m.stop+0x30);m.wq(vt+0x90,m.stop+0x10);m.wq(particlevt+0x10,m.stop+0x40)
 for off,values in [(0x1e0,c['position']),(0x19c,[0,0,0]),(0x164,[.1,.2,.3])]:
  for axis,v in enumerate(values):m.wf(emitter+off+axis*4,v)
 m.wq(emitter+0x188,m.heap+0x8000 if c['ages']else 0);m.wi(emitter+0x190,len(c['ages']));m.wi(emitter+0x194,16 if c['ages']else 0)
 m.wq(emitter+0x130,m.heap+0x9000 if c['freeCount']else 0);m.wi(emitter+0x138,c['freeCount']);m.wi(emitter+0x13c,16 if c['freeCount']else 0)
 for i,age in enumerate(c['ages']):p=m.heap+0x10000+i*0x100;initialize(p,i,age);m.wq(m.q(emitter+0x188)+i*8,p)
 for i in range(c['freeCount']):id=len(c['ages'])+i;p=m.heap+0x10000+id*0x100;initialize(p,id);m.wq(m.q(emitter+0x130)+i*8,p)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,emitter);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['delta']),'little'))
 try:u.emu_start(0x140064b30,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 activeids=ids(m.q(emitter+0x188),m.si(emitter+0x190));freeids=ids(m.q(emitter+0x130),m.si(emitter+0x138));pointers={id:p for p,id in names.items()if p< m.heap+0x60000}
 return dict(case=c,calls=calls,active=activeids,free=freeids,activeCapacity=m.si(emitter+0x194),freeCapacity=m.si(emitter+0x13c),enabled=u.mem_read(emitter+0x23c,1)[0],accumulator=m.rf(emitter+0x198),remaining=[m.rf(emitter+0x164+i*4)for i in range(3)],particles=[dict(id=id,age=m.rf(p+0x74),field48=m.si(p+0x48),rotation=m.rf(p+0x1c),position=[m.rf(p+0x10+i*4)for i in range(3)],trail=[m.rf(p+0x64+i*4)for i in range(3)])for id,p in sorted(pointers.items())])
rows=[run(dict(rate=rate,delta=delta,spawnType=spawn,renderMode=mode,ages=ages,freeCount=free,chunk=chunk,source=1,factor=.75,position=[1.25,-.5,.75]))for rate,delta,spawn,mode,(ages,free,chunk)in itertools.product([0,.5,1,3.5,8],[0,.1,.5,1.25],[0,1],[0,6],[([],0,0),([.25,1.25],1,1)])]
rows.extend([run(dict(rate=8,delta=.5,spawnType=spawn,renderMode=0,ages=[],freeCount=0,chunk=0,source=0,factor=1,position=pos))for spawn,pos in itertools.product([0,1],[[0,0,0],[.00001,-.00002,.00003]])])
rows.append(run(dict(rate=8,delta=.5,spawnType=0,renderMode=0,ages=[],freeCount=0,chunk=0,source=0,factor=1,position=[0,0,0],mutateAccumulator=.1)))
out=m.root/'backups/animations/native-fountain-update-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
