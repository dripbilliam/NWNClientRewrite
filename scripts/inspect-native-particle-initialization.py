"""Complete original Particle constructor, initialize, randomPosition,
randomDirection, inheritVelocity and chkRandom, with original vector/quaternion
helpers and embedded SSE CRT sinf/cosf/double cosine. CRT rand draw stream and
IEEE float32 sqrt are captured boundaries. No asset copies. Original startup
seeding/CPU dispatch and GPU presentation remain separate acceptance owners.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,node,particle,camera=[m.heap+n*0x1000 for n in range(4)]
correctionCounts=[]
ranges=[(0x140060680,0x1400606df),(0x140066450,0x140066685),(0x1400660c0,0x14006613a),(0x140068d80,0x140068ed2),(0x140068800,0x140068d73),(0x140066140,0x1400663c4),
 (0x140230920,0x1402309f5),(0x14022db30,0x14022dbf2),(0x14022ab00,0x14022ac34),(0x14022fba0,0x14022fbfa),(0x14022b150,0x14022b180),
 (0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f),(0x140c79d30,0x140c7a2aa),(0x140c92d20,0x140c93360)]
def hook(u,a,n,_):
 global rng,correctionCounter
 if a==m.stop:u.emu_stop();return
 if a==0x140068b20:correctionCounter+=1
 if a==0x140c7ed00:
  rng=(rng*214013+2531011)&0xffffffff;value=(rng>>16)&0x7fff;draws.append(value);m.finish(value)
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected native dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def vector(a,values):
 for i,v in enumerate(values):m.wf(a+i*4,v)
def invoke(address,delta,factor=1):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,particle)
 if address==0x140060680:u.reg_write(UC_X86_REG_RDX,emitter);u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',delta),'little'))
 elif address==0x1400660c0:u.reg_write(UC_X86_REG_RCX,emitter);u.reg_write(UC_X86_REG_RDX,particle)
 else:
  for reg,v in [(UC_X86_REG_XMM1,delta),(UC_X86_REG_XMM2,factor)]:u.reg_write(reg,int.from_bytes(struct.pack('<f',v),'little'))
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def run(case):
 global c,rng,draws,correctionCounter
 c=case;rng=c['seed'];draws=[];correctionCounter=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(particle,bytes([0xa5])*0x78)
 m.wq(emitter+8,node);m.wi(node+0x174,c['flags']);m.wf(node+0xa0,c['deadspace']);m.wq(particle+8,emitter);m.wq(0x1412e0318,camera);m.wi(0x1415d8224,0)
 vector(camera+0xb0,[10,20,30]);vector(emitter+0x1e0,[4,-3,2]);vector(emitter+0x19c,[3,-2,1]);vector(emitter+0x178,[1,0,0,0]);vector(emitter+0x1d0,c['quaternion']);vector(emitter+0x140,c['basis'])
 for off,v in [(0xa0,3.75),(0xa4,.5),(0xc0,c['randomVelocity']),(0xdc,2),(0xe0,c['size'][0]),(0xe4,c['size'][1]),(0xd4,c['spread'])]:m.wf(emitter+off,v)
 try:
  if c['mode'] in ['constructor','both']:invoke(0x140060680,c['delta'])
  if c['mode']in ['initialize','both']:invoke(0x140066450,c['delta'],c['factor'])
  invoke(0x1400660c0,0)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),draws=draws)));raise
 correctionCounts.append(correctionCounter)
 def read(off,n):return[m.rf(particle+off+i*4)for i in range(n)]
 return dict(case=c,draws=draws,rng=rng,position=read(0x10,3),rotation=m.rf(particle+0x1c),inheritedSpeed=m.rf(particle+0x20),inheritedDirection=read(0x24,3),quaternion=read(0x34,4),frame=m.si(particle+0x44),field48=m.si(particle+0x48),direction=read(0x4c,3),velocity=read(0x58,3),trail=read(0x64,3),stopped=u.mem_read(particle+0x70,1)[0],age=m.rf(particle+0x74))
identity=[1,0,0,0];basis=[1,0,0,0,1,0,0,0,1]
rotated=[math.cos(.3),0,math.sin(.3),0];rotbasis=[math.cos(.6),0,-math.sin(.6),0,1,0,math.sin(.6),0,math.cos(.6)]
rows=[run(dict(mode=mode,seed=seed,randomVelocity=rv,size=size,spread=spread,flags=flags,delta=.1,factor=.75,quaternion=q,basis=b,deadspace=0))for mode,seed,rv,size,spread,flags,(q,b)in itertools.product(['constructor','initialize','both'],[1,0x80000001],[0,.01,.0101,.5],[[0,0],[.02,-.02],[30,25]],[0,.872665,6.28319],[32,160],[(identity,basis),(rotated,rotbasis)])]
rows.extend([run(dict(mode='both',seed=seed,randomVelocity=.5,size=[30,25],spread=.872665,flags=160,delta=delta,factor=1,quaternion=rotated,basis=rotbasis,deadspace=.2))for seed,delta in itertools.product([1,4,13,77],[0,-.5,.5])])
coverage=dict(correctionCases=sum(n>0 for n in correctionCounts),correctionIterations=sum(correctionCounts))
out=m.root/'backups/animations/native-particle-initialization-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,coverage=coverage,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),coverage=coverage)))
