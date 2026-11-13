"""Execute unchanged WindManager noise, global/point sampling and timer math.
Original quaternion/vector and CRT SSE sin/cos bodies execute too. CRT rand is
a captured deterministic recurrence, sqrt an IEEE-f32 leaf, instrumentation
and allocation captured boundaries. This proves synthetic arithmetic/state;
actual scene startup RNG seed, renderer ordering and grass remain separate.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
manager,records,point,out,field0,field1=[m.heap+n*0x10000 for n in range(6)]
scopes=[m.q(0x140d91bb0+n)for n in [0x10,0x20]]
ranges=[(0x1400f1560,0x1400f1827),(0x1400f1e00,0x1400f2070),(0x1400f2070,0x1400f224f),(0x1400f2250,0x1400f2574),(0x140230920,0x1402309f6),(0x14022b240,0x14022b27d),(0x14022b180,0x14022b1b1),(0x14022ab00,0x14022ac34),(0x14022ae90,0x14022b0bb),(0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f)]
seed=1;draws=0
def vector(ptr,values):
 for i,v in enumerate(values):m.wf(ptr+4*i,v)
def read(ptr,n=3):return[m.rf(ptr+i*4)for i in range(n)]
def hook(u,a,n,_):
 global seed,draws
 if a==m.stop:u.emu_stop();return
 if a==0x140c7ed00:
  seed=(seed*0x343fd+0x269ec3)&0xffffffff;draws+=1;m.finish((seed>>16)&0x7fff)
 elif a==0x140c7d6d8:
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif a in [0x14030f3c0,0x140c10410]+scopes:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected global wind dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args=(),floats=()):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 for reg,value in floats:u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
 try:u.emu_start(address,m.stop,count=500000)
 except Exception:print(json.dumps(dict(address=hex(address),rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
def setup():
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(0x1415d8224,0)
 m.wq(manager+0x10,records);m.wq(manager+0x838,field0);m.wq(manager+0x840,field1);m.wf(manager+0x858,.5)
noise=[]
for initial in [1,321,0x80000001,0xffffffff]:
 setup();seed=initial;draws=0
 call(0x1400f1e00,[manager,field0]);call(0x1400f1e00,[manager,field1])
 assert draws==682
 noise.append(dict(seed=initial,resultSeed=seed,draws=draws,first=read(field0,256),second=read(field1,256)))
queries=[]
for ni,wind,deviation,fraction,position,points,factor in itertools.product(range(2),[[0,0,0],[.25,-2,.75]],[[0,0],[1.3,0],[2.25,.4]],[0,.25,1],[[0,0,0],[.99,-1.01,.5],[3.99,17.01,-2],[-17.99,-3.01,1],[536870912.0,-1e10,3]],[[],[[0,0,0,8,2,2,1],[1,0,0,4,2,2,-.25]]],[0,.016,1.2]):
 setup();vector(field0,noise[ni]['first']);vector(field1,noise[ni]['second']);vector(manager+0x20,wind);m.wf(manager+0x848,deviation[0]);m.wf(manager+0x84c,deviation[1]);m.wf(manager+0x850,fraction);m.wi(manager+0x18,len(points))
 for i,p in enumerate(points):vector(records+i*28,p)
 vector(point,position);call(0x1400f1560,[manager,out,point],[(UC_X86_REG_XMM3,factor)])
 queries.append(dict(noise=ni,wind=wind,deviation=deviation,fraction=fraction,position=position,points=points,factor=factor,result=read(out)))
timers=[]
for elapsed,delta,timeout in itertools.product([0,.4,.5],[0,.1,.5,1.6,-.1],[.25,.5,2]):
 setup();seed=321;draws=0;vector(field0,noise[1]['first']);vector(field1,noise[1]['second']);vector(manager+0x20,[.25,-2,.75]);m.wf(manager+0x854,elapsed);m.wf(manager+0x858,timeout)
 call(0x1400f2250,[manager],[(UC_X86_REG_XMM1,delta)])
 timers.append(dict(elapsed=elapsed,delta=delta,timeout=timeout,seed=321,resultSeed=seed,draws=draws,result=dict(elapsed=m.rf(manager+0x854),fraction=m.rf(manager+0x850),step=read(manager+0x2c),swapped=m.q(manager+0x838)==field1,first=read(m.q(manager+0x838),256),second=read(m.q(manager+0x840),256))))
output=m.root/'backups/animations/native-global-wind-observations-v1.json'
assert not output.exists(),'Original wind evidence already exists; preserve it'
output.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,noise=noise,queries=queries,timers=timers),indent=2))
print(json.dumps(dict(output=str(output),noise=len(noise),queries=len(queries),timers=len(timers))))
