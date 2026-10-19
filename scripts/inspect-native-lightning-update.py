"""Complete original LightningEmitter::Update065290 and RecursiveFractal062460
with actual native vector/quaternion/normalization helpers and seeded CRT draws.
Source scale/target position, allocation/memmove and Particle::initialize are
captured lower boundaries. New particle initialization has explicit synthetic
responses; native constructor scalar writes still execute. No asset copies,
original runtime mutation, hardware render or client RNG startup proof.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
emitter,node,source,svt,target,tvt=[m.heap+n*0x1000 for n in range(6)]
ranges=[(0x140065290,0x140065ccb),(0x140062460,0x14006280b),(0x14022ae90,0x14022b0bb),(0x14022e1c0,0x14022e2ed),(0x14022db30,0x14022dbf2),(0x14022fba0,0x14022fbfa),(0x140230920,0x1402309f5),(0x140068d80,0x140068ed2)]
def vector(p,v):
 for i,x in enumerate(v):m.wf(p+i*4,x)
def read(p,n=3):return[m.rf(p+i*4)for i in range(n)]
def allocate(old,size):
 global allocation
 ptr=m.heap+0x80000+allocation*0x2000;allocation+=1
 if old:u.mem_write(ptr,bytes(u.mem_read(old,min(size,0x1000))))
 return ptr
def hook(u,a,n,_):
 global allocation,newcount,rng
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10324:
  assert x==0x78;ptr=m.heap+0x30000+newcount*0x100;names[ptr]=nextid+newcount;newcount+=1;calls.append(['allocate',names[ptr]]);m.finish(ptr)
 elif a==0x140066450:
  calls.append(['initialize',names[x],m.xmm(UC_X86_REG_XMM1),m.xmm(UC_X86_REG_XMM2)]);vector(x+0x10,[1+names[x],2+names[x],3+names[x]]);vector(x+0x64,[-1,-2,-3]);m.wf(x+0x74,0);m.wi(x+0x48,0);m.wi(x+0x44,int(c['frameStart']));m.finish()
 elif a==0x140c4f038:
  label='reserveActive'if m.q(rsp)==0x140065522 else'reserveFree';calls.append([label,y//8]);m.finish(allocate(x,y))
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==m.stop+0x10:calls.append(['source']);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c['factor']),'little'));m.finish()
 elif a==m.stop+0x20:calls.append(['target']);vector(y,c['targetPosition']);m.finish(y)
 elif a==0x140c7ed00:rng=(rng*214013+2531011)&0xffffffff;value=(rng>>16)&0x7fff;draws.append(value);m.finish(value)
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif a==0x140230920:normalizes.append(read(y))
 elif a==0x140068d80:calls.append(['randomPosition',names[x],y&0xffffffff,z&0xffffffff])
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured Lightning dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,newcount,names,nextid,rng,draws,normalizes
 c=case;calls=[];allocation=newcount=0;names={};nextid=c['activeCount']+c['freeCount'];rng=c['seed'];draws=[];normalizes=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(emitter+8,node);m.wi(node+0x174,c['flags']);m.wq(emitter+0x50,source if c['source']else 0);m.wq(source,svt);m.wq(svt+0x2d0,m.stop+0x10);m.wq(emitter+0x1c0,target if c['target']else 0);m.wq(target,tvt);m.wq(tvt+0xc0,m.stop+0x20)
 for off,v in[(0x2c,c['partScale']),(0x74,c['rate']),(0xa4,c['frameStart']),(0xa0,c['frameEnd']),(0xe0,c['xSize']),(0xe4,c['ySize']),(0xe8,.3),(0xec,c['delay']),(0xf0,c['radius']),(0xf4,c['scale']),(0x1c8,c['elapsed'])]:m.wf(emitter+off,v)
 m.wi(emitter+0x1a8,c['mode']);vector(emitter+0x1e0,c['position']);vector(emitter+0x248,c['oldDirection']);vector(emitter+0x254,c['oldPosition']);vector(emitter+0x140,[1,0,0,0,1,0,0,0,1])
 for off,count in[(0x188,c['activeCount']),(0x130,c['freeCount'])]:
  ptr=m.heap+(0x8000 if off==0x188 else 0x9000);m.wq(emitter+off,ptr if count else 0);m.wi(emitter+off+8,count);m.wi(emitter+off+12,count)
  for i in range(count):
   ident=i if off==0x188 else c['activeCount']+i;p=m.heap+0x10000+ident*0x100;names[p]=ident;m.wq(ptr+i*8,p);m.wq(p+8,emitter);m.wf(p+0x74,.25 if i%2 else 0);m.wf(p+0x48,.25 if i%2 else 1);m.wi(p+0x44,2);vector(p+0x10,[1+ident,2+ident,3+ident]);vector(p+0x64,[-1,-2,-3])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,emitter);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['delta']),'little'));u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 try:u.emu_start(0x140065290,m.stop,count=300000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 ids=lambda off:[names[m.q(m.q(emitter+off)+i*8)]for i in range(m.si(emitter+off+8))]
 return dict(case=c,calls=calls,draws=draws,rng=rng,normalizes=normalizes,active=ids(0x188),free=ids(0x130),activeCapacity=m.si(emitter+0x194),freeCapacity=m.si(emitter+0x13c),elapsed=m.rf(emitter+0x1c8),oldDirection=read(emitter+0x248),oldPosition=read(emitter+0x254),particles=[dict(id=ident,position=read(ptr+0x10),trail=read(ptr+0x64),age=m.rf(ptr+0x74),field48=m.rf(ptr+0x48),frame=m.si(ptr+0x44))for ptr,ident in sorted(names.items(),key=lambda kv:kv[1])])
def profile(**kw):
 c=dict(rate=5,activeCount=0,freeCount=0,source=1,target=1,factor=.75,partScale=1,flags=32,frameStart=.5,frameEnd=3.75,xSize=0,ySize=0,delta=.05,mode=3,delay=0,elapsed=.05,radius=.1,scale=.5,seed=1,position=[1.25,-2,3.5],targetPosition=[8,5,4],oldDirection=[1,0,0],oldPosition=[1,2,3]);c.update(kw);return c
rows=[run(profile(rate=rate,delta=delta,target=target,activeCount=active,freeCount=free,delay=delay,flags=flags,mode=mode))for rate,delta,target,active,free,delay,flags,mode in itertools.product([0,.5,1,3,5,9,17,33],[0,.05,.2],[0,1],[0,3,9],[0,3],[0,.1],[0,32],[3,6])]
for radius,scale,hasSource,factor,seed,position,targetpos in itertools.product([0,.005,.01,.25],[-1,0,2],[0,1],[.5,2],[1,12345],[[-.5,.25,1.5],[0,0,0]],[[8,5,4],[0,0,0]]):rows.append(run(profile(radius=radius,scale=scale,source=hasSource,factor=factor,seed=seed,position=position,targetPosition=targetpos)))
rows.extend(run(profile(rate=3,delta=.05,delay=1,elapsed=0,oldDirection=old,position=pos))for old,pos in itertools.product([[1,0,0],[0,0,0],[1,2,3]],[[1,2,3],[0,0,0]]))
rows.extend(run(profile(xSize=x,ySize=y))for x,y in[(.01,0),(0,.01),(2,3)])
out=m.root/'backups/animations/native-lightning-update-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
