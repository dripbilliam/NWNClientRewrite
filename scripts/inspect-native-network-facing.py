"""Complete original client facing807690 with original normalize/cross and
SSE CRT sinf/cosf. Only model lookup, animation request/restore and final
orientation setter are captured; no game process or assets are changed.
"""
import sys,importlib,json,struct,itertools,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
obj,vt,model,target=[m.heap+n*0x1000 for n in range(40,44)]
setter,animation=m.stop+0x120,m.stop+0x150
ranges=[(0x140807690,0x140807943),(0x140230920,0x1402309f6),(0x14022fba0,0x14022fbfa),
 (0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f),(0x140c79d30,0x140c7a2aa),(0x140c92d20,0x140c93360),(0x140c7d6d8,0x140c7d783)]
def vec(p):return list(struct.unpack('<3f',u.mem_read(p,12)))
def put(p,v):u.mem_write(p,struct.pack('<3f',*v))
def hook(u,a,n,data):
 x,y=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==setter:put(obj+0x44,vec(y));m.finish();return
 if a==animation:requests.append(y&65535);m.finish();return
 if a==0x1407630a0:m.finish(model if c['model'] else 0);return
 if a==0x140761d80:u.mem_write(obj+0x5c,struct.pack('<H',c['restored']));m.finish();return
 if a==0x140cae8e0:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,requests
 c=case;requests=[];t.reset(dict(format=1));m.wq(obj,vt);m.wq(vt+0x120,setter);m.wq(vt+0x150,animation)
 m.wi(obj+0x58,c['dt']);u.mem_write(obj+0x5c,struct.pack('<H',c['animation']));put(obj+0x44,c['orientation']);put(target,c['target']);u.mem_write(model+0xde,bytes([c['modelType']]))
 m.wi(0x1415d8224,0);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 w.call(0x140807690,[obj,target]);return dict(case=c,orientation=vec(obj+0x44),target=vec(target),requests=requests)
base=dict(animation=4,dt=16,orientation=[1.,0.,0.],target=[0.,1.,0.],model=True,modelType=1,restored=0)
cases=[base|dict(animation=a,dt=dt,target=v,modelType=body)for a,dt,v,body in itertools.product([0,1,2,3,4,53,54,78,80,81,82,83],[0,1,8,16,33,100,512],[[1.,0.,0.],[1.,.01,0.],[1.,.1,0.],[0.,1.,0.],[0.,-1.,0.],[-1.,0.,0.],[.1,-.9,5.]], [0,1])]
stalls='--stalls' in sys.argv
if stalls:cases=[base|dict(animation=a,dt=dt,target=v)for a,dt,v in itertools.product([0,1,4],[1000,5162,6000,16384,30000,60000,600000,80000000],[[0.,1.,0.],[0.,-1.,0.],[-1.,0.,0.],[.1,-.9,5.]])]
rows=[]
for c in cases:
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
out=m.root/('backups/animations/native-network-facing-stalls-observations.json' if stalls else 'backups/animations/native-network-facing-observations.json');out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
