"""Multi-frame original Fountain Update + lifetime + actual Particle ctor,
initialize, random position/direction/frame selection, inheritance and standard
movement. Original source GetAdjustedScale and its constant LerpFloat fast path
execute too. CRT rand/IEEE sqrt, backing array/heap and HitInfo.ClearOutput are
captured boundaries. No wind/scene-hit flags in this coupled fixture. Outer
animation/transform clock, chunks, GPU render and scene integration are separate.
"""
import importlib,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,node,gob,vt,hit,camera=[m.heap+n*0x1000 for n in range(6)]
ranges=[(0x140064b30,0x140065281),(0x140065f10,0x1400660bf),(0x140060680,0x1400606df),(0x140066450,0x140066685),(0x1400660c0,0x14006613a),(0x140068d80,0x140068ed2),(0x140068800,0x140068d73),(0x140066140,0x1400663c4),(0x140068010,0x1400687f9),
 (0x140230920,0x1402309f5),(0x14022db30,0x14022dbf2),(0x14022ab00,0x14022ac34),(0x14022fba0,0x14022fbfa),(0x14022b150,0x14022b1b0),(0x14022ae90,0x14022b0e6),(0x14022e1c0,0x14022e2ed),
 (0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f),(0x140c79d30,0x140c7a2aa),(0x140c92d20,0x140c93360),(0x14008e390,0x14008e3b3),(0x1402e9a80,0x1402e9a9a)]
def vector(a,values):
 for i,v in enumerate(values):m.wf(a+i*4,v)
def read(a,n=3):return[m.rf(a+i*4)for i in range(n)]
def array(old,size):
 global arrays
 p=m.heap+0x90000+arrays*0x1000;arrays+=1
 if old:u.mem_write(p,bytes(u.mem_read(old,min(size,0x1000))))
 return p
def hook(u,a,n,_):
 global rng,allocations,initializations,constructors,clearHits
 if a==m.stop:u.emu_stop();return
 if a==0x140060680:constructors+=1
 if a==0x140066450:initializations+=1
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c7ed00:rng=(rng*214013+2531011)&0xffffffff;draws.append((rng>>16)&0x7fff);m.finish(draws[-1])
 elif a==0x140c10324:p=m.heap+0x10000+allocations*0x100;names[p]=allocations;allocations+=1;m.finish(p)
 elif a==0x140c4f038:m.finish(array(x,y))
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x140061010:
  count,capacity=m.si(x+8),m.si(x+12)
  if count==capacity:capacity=16 if capacity==0 else capacity*2;m.wi(x+12,capacity);m.wq(x,array(m.q(x),capacity*8))
  m.wq(m.q(x)+count*8,y);m.wi(x+8,count+1);m.finish()
 elif a==0x1400c5a90:clearHits+=1;m.finish()
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped coupled dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(seed):
 global rng,allocations,arrays,names,draws,initializations,constructors,clearHits
 rng=seed;allocations=arrays=initializations=constructors=clearHits=0;names={};draws=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(emitter+8,node);m.wi(node+0x174,32);m.wq(emitter+0x50,gob);m.wq(gob,vt);m.wq(vt+0x2d0,0x14008e390);m.wf(gob+0x1c4,1);m.wf(gob+0x49c,.75);m.wq(emitter+0x170,0x140068010);m.wq(emitter+0x1f0,hit)
 m.wq(0x1412e0318,camera);vector(camera+0xb0,[10,20,30]);m.wi(0x1415d8224,0)
 for off,values in [(0x1e0,[4,-3,2]),(0x19c,[4,-3,2]),(0x1d0,[1,0,0,0]),(0x178,[1,0,0,0]),(0x140,[1,0,0,0,1,0,0,0,1])]:vector(emitter+off,values)
 for off,v in [(0xac,.2),(0xbc,1),(0xc0,.5),(0xdc,2),(0xe0,30),(0xe4,25),(0xd4,.872665),(0xa0,3),(0xa4,0),(0xb0,.2),(0xe8,1)]:m.wf(emitter+off,v)
 frames=[]
 for rate in [20,20,20,20,20,0,0,0,0]:
  m.wf(emitter+0x74,rate);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,emitter);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',.1),'little'))
  try:u.emu_start(0x140064b30,m.stop,count=200000)
  except Exception:print(json.dumps(dict(seed=seed,rate=rate,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
  assert u.reg_read(UC_X86_REG_RIP)==m.stop
  active=[names[m.q(m.q(emitter+0x188)+i*8)]for i in range(m.si(emitter+0x190))];free=[names[m.q(m.q(emitter+0x130)+i*8)]for i in range(m.si(emitter+0x138))]
  frames.append(dict(rate=rate,active=active,free=free,activeCapacity=m.si(emitter+0x194),freeCapacity=m.si(emitter+0x13c),rng=rng,drawCount=len(draws),constructors=constructors,initializations=initializations,clearHits=clearHits,particles=[dict(id=id,position=read(p+0x10),velocity=read(p+0x58),quaternion=read(p+0x34,4),direction=read(p+0x4c),trail=read(p+0x64),age=m.rf(p+0x74),frame=m.si(p+0x44),field48=m.si(p+0x48),rotation=m.rf(p+0x1c),stopped=u.mem_read(p+0x70,1)[0])for p,id in sorted(names.items(),key=lambda x:x[1])]))
 return dict(seed=seed,draws=draws,frames=frames)
rows=[run(seed)for seed in [1,77,0x80000001]]
out=m.root/'backups/animations/native-fountain-physics-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),frames=sum(len(row['frames'])for row in rows))))
