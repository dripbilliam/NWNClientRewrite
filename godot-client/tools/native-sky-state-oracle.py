"""Execute original area phase1407e90b0, sky update1407e9cb0 and
Scene::SetSkyAlpha1400d3d40 in isolated Unicorn. Color/tile/weather/render
setters and module/settings lookup are explicit stubs. Sky alpha, threshold,
physical phase selection and scene state execute original instructions. No
GPU/sky art/weather parity, game process mutation or online connection claim.
"""
import sys,importlib,struct,json,itertools
from pathlib import Path
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
area,module,vt,settings,app,scene,svt=[m.heap+n*0x1000 for n in range(7)]
def hook(u,a,n,data):
 if a==m.stop:u.emu_stop();return
 if a==0x1406abea0:m.finish(module);return
 if a==0x1406ab9b0:m.finish(settings);return
 if a in [m.stop+0x28,m.stop+0x40,m.stop+0x48,0x1407e5d10,0x1400a5050,0x14007dd10,0x1407e9bc0,0x1408783d0,0x140c10410]:m.finish();return
 if any(lo<=a<hi for lo,hi in [(0x1407e90b0,0x1407e9bc0),(0x1407e9cb0,0x1407e9d20),(0x1407e57f0,0x1407e5830),(0x1400d3d40,0x1400d3d70),(0x14022b150,0x14022b1b0)]):return
 raise RuntimeError('Unexpected original sky dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for mode,duration,steps in itertools.product(['dawn','dusk'],[1,60,300],[[-.01,0,.125,.395,.396,.4,.5,.6,.60001,.7,.99,1.0],[0,.7,1.0],[.5,.61,.8,1.0]]):
 u.mem_write(m.heap,bytes(0x10000));m.wq(area,vt);m.wq(scene,svt);m.wq(svt+0x158,0x1400d3d40);m.wq(area+0x248,scene);m.wq(0x1412df970,app);m.wq(app,app)
 for offset in [0x28,0x40,0x48]:m.wq(vt+offset,m.stop+offset)
 initial=3 if mode=='dawn' else 1;m.wi(scene+0x44,initial);m.wi(scene+0x48,initial);m.wi(area+0xd8,1);m.wi(area+0xdc,mode=='dawn');u.mem_write(area+0xe0,b'\1');u.mem_write(area+0x3c0,bytes([initial,initial]));m.wi(area+(0x2ac if mode=='dawn' else 0x2b0),1)
 for i in range(4):m.wq(area+0x398+i*8,m.heap+0x8000+i*0x100)
 for index,step in enumerate(steps):
  elapsed=step*duration;m.wf(module+0x174,elapsed);m.wf(module+0x178,duration)
  u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,area);u.emu_start(0x1407e90b0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
  rows.append(dict(mode=mode,duration=duration,elapsed=elapsed,reset=index==0,initial=initial,current=m.si(scene+0x44),target=m.si(scene+0x48),alpha=struct.unpack('<f',u.mem_read(scene+0x40,4))[0],alphaBits=bytes(u.mem_read(scene+0x40,4)).hex(),completed=u.mem_read(area+0x3c1,1)[0],requested=u.mem_read(area+0x3c0,1)[0]))
out=Path(sys.argv[1]);assert not out.exists();out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
