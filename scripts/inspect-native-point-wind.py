"""Original AddPointSourceWind and pointSourceWindVector + real vector/math
leaves. Full updateTimer executes; only its point-list output is compared.
Profiler/instrumentation and noise refill are captured boundaries (not a port
of ambient noise, scene registration or renderer ordering). Synthetic fixtures.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
manager,records,point,out=[m.heap+n*0x10000 for n in range(4)]
scope=[m.q(0x140d91bb0+n)for n in [0x10,0x20]]
ranges=[(0x1400f1250,0x1400f12da),(0x1400f2070,0x1400f224e),(0x1400f2250,0x1400f2573),(0x140230920,0x1402309f5),(0x14022b240,0x14022b27c),(0x14022b180,0x14022b1ae)]

def vector(ptr,values):
 for i,v in enumerate(values):m.wf(ptr+i*4,v)

def read(ptr,n=3):return[m.rf(ptr+i*4)for i in range(n)]

def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1400f12e0:m.wq(x,records);m.wi(x+12,y);m.finish()
 elif a==0x140c7d6d8:
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif a in [0x1400f1e00,0x14030f3c0,0x140c10410]+scope:m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected wind dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def setup(winds,capacity=None):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wi(0x1415d8224,0);m.wq(manager+0x10,records);m.wi(manager+0x18,len(winds));m.wi(manager+0x1c,len(winds)if capacity is None else capacity)
 m.wf(manager+0x858,.5);m.wq(manager+0x838,m.heap+0x50000);m.wq(manager+0x840,m.heap+0x60000)
 for i,w in enumerate(winds):vector(records+i*28,w)

def call(address,args=(),floats=(),stack5=None):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 for reg,value in floats:u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
 if stack5 is not None:m.wf(rsp+0x28,stack5)
 try:u.emu_start(address,m.stop,count=100000)
 except Exception:print(json.dumps(dict(address=hex(address),rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop

def state():return dict(capacity=m.si(manager+0x1c),records=[read(records+i*28,7)for i in range(m.si(manager+0x18))])

queries=[]
for count,radius,strength,position in itertools.product([0,1,3],[0,1,8],[-2,0,1],[[0,0,0],[.25,.5,0],[1,0,0],[8,0,0],[.000001,0,0],[-2,1,-.5],[100,100,100]]):
 winds=[[i*.25,-i*.5,i*.125,radius,2,2,strength]for i in range(count)];setup(winds);vector(point,position);call(0x1400f2070,[manager,out,point]);queries.append(dict(winds=winds,position=position,result=read(out)))
adds=[]
for count,capacity,radius,duration,strength in itertools.product([0,1,16],[0,16,32],[-1,0,8],[-.5,0,1.2],[-1,1]):
 if count>capacity:continue
 winds=[[i,0,0,2,3,3,1]for i in range(count)];setup(winds,capacity);vector(point,[1.25,-2,3.5]);call(0x1400f1250,[manager,point],[(UC_X86_REG_XMM2,radius),(UC_X86_REG_XMM3,duration)],strength)
 adds.append(dict(winds=winds,capacity=capacity,position=[1.25,-2,3.5],radius=radius,duration=duration,strength=strength,result=state()))
advances=[]
for count,remaining,delta in itertools.product([0,1,4],[-1,0,.25,1],[0,.25,.5,2,-.25]):
 winds=[[i,0,0,8,2,remaining+i*.125,1]for i in range(count)];setup(winds,16);call(0x1400f2250,[manager],[(UC_X86_REG_XMM1,delta)]);advances.append(dict(winds=winds,delta=delta,result=state()))
output=m.root/'backups/animations/native-point-wind-observations.json';output.write_text(json.dumps(dict(binarySha256=m.digest,queries=queries,adds=adds,advances=advances),indent=2));print(json.dumps(dict(output=str(output),queries=len(queries),adds=len(adds),advances=len(advances))))
