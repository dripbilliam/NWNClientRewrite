"""Original location receiver77a7f0, target setter7cfa00, transition7d11f0,
yaw7ccd90/distance7ccb00 helpers and SSE logf execute against synthetic state.
Base camera-command harness boundaries persist; pause query and finite pow are
captured. Frame observations stop before Follow integration. No live process
changes or copied installed assets. SSE CPU profile is explicit, not FMA proof.
"""
import sys,importlib,json,struct,itertools,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
c=importlib.import_module('inspect-native-camera-commands');w=c.w;m=c.m;u=c.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(c.hook_handle)
ranges=[(0x1407cfa00,0x1407cfa84),(0x1407d11f0,0x1407d1685),(0x1407ccd90,0x1407ccf54),(0x1407ccb00,0x1407ccc67),(0x140c946b0,0x140c94aa6)]
paused=0
def hook(u,a,n,data):
 if a==0x1406ac030:m.finish(paused);return
 if a==0x140c7b170:
  base=struct.unpack('<d',u.reg_read(UC_X86_REG_XMM0).to_bytes(16,'little')[:8])[0];power=struct.unpack('<d',u.reg_read(UC_X86_REG_XMM1).to_bytes(16,'little')[:8])[0];u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<d',math.pow(base,power)),'little'));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 c.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def setup(case):
 global paused
 c.setup(case);m.wi(0x1415d8224,0);paused=case.get('paused',0)
def observation():return dict(yaw=m.rf(c.behavior+0x54),pitch=m.rf(c.behavior+0x5c),distance=m.rf(c.behavior+0x48),turn=m.rf(c.behavior+0x58),tilt=m.rf(c.behavior+0x60),speed=m.rf(c.behavior+0x4c),target=c.vec(c.module+0x28c,4))
packets=[]
for mask,speed in itertools.product(range(16),[-1,0,1,45,180,181]):
 case=dict(yaw=35.125,pitch=42.5,distance=12.75);setup(case);ops=[['byte',mask]]
 for bit,value in [(1,1.25),(2,17.5),(4,65)]:
  if mask&bit:ops.append(['float',value])
 if mask&8:ops.append(['int',speed])
 row=c.receive(1,ops);row.update(case=case,observation=observation());packets.append(row)
for distance,pitch in [(0,0),(100,100)]:
 for mask in [0,1,8,15]:
  case=dict(yaw=35.125,pitch=pitch,distance=distance);setup(case);ops=[['byte',mask]]
  for bit,value in [(1,1.25),(2,17.5),(4,65)]:
   if mask&bit:ops.append(['float',value])
  if mask&8:ops.append(['int',45])
  row=c.receive(1,ops);row.update(case=case,observation=observation());packets.append(row)
frames=[]
for mode,dt,speed,target in itertools.product(range(3),[0,.001,.016,.1,1],[0,.0001,1,45,180],[[5,-170,20],[25,179,89],[12.75,35.125,42.5],[1,35.125,42.5],[12.75,35.125,89]]):
 case=dict(mode=mode,dt=dt,yaw=35.125,pitch=42.5,distance=12.75,target=target,transition=speed);setup(case);c.put(c.module+0x28c,target+[speed]);result=w.call(0x1407d11f0,[c.module],[dt]);frames.append(dict(case=case,result=result,observation=observation()))
for mode in range(3):
 case=dict(mode=mode,dt=.016,yaw=35.125,pitch=42.5,distance=12.75,target=[5,-170,20],transition=45,paused=1);setup(case);c.put(c.module+0x28c,case['target']+[45]);result=w.call(0x1407d11f0,[c.module],[case['dt']]);frames.append(dict(case=case,result=result,observation=observation()))
out=m.root/'backups/animations/native-camera-location-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,packets=packets,frames=frames),indent=2)+'\n');print(json.dumps(dict(packets=len(packets),frames=len(frames),output=str(out))))
