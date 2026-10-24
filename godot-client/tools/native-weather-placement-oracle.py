"""Original six-model weather placement1407e7f05..81f2, normalize/cross/Yaw/
YawPitchRoll bodies. Camera/player/model virtual objects are synthetic; CRT
sqrt/atan2/sin/cos use explicit correctly rounded Python-math float32 stubs.
Does not establish native CRT, camera getter semantics or precipitation pixels.
"""
from pathlib import Path
import sys,struct,json,importlib,itertools,math
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
area,player,camera,cv,gv,quat=[m.heap+n*0x1000 for n in range(6)]
models=[m.heap+0x6000+i*0x100 for i in range(6)];poses={}
def bits(p,n):return bytes(u.mem_read(p,4*n)).hex()
def hook(u,a,n,data):
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1407e81f2:u.emu_stop();return
 if a==m.stop+0x10:m.finish(quat);return
 if a in [m.stop+0x20,m.stop+0x30]:
  poses.setdefault(models.index(x),{})['positionBits' if a==m.stop+0x20 else 'quaternionBits']=bits(z,3 if a==m.stop+0x20 else 4);m.finish(y);return
 if a in [0x140c7d6d8,0x140c8f29c,0x140c7a2b0,0x140c7ac70]:
  value=m.xmm(UC_X86_REG_XMM0);other=m.xmm(UC_X86_REG_XMM1)
  value=math.sqrt(value) if a==0x140c7d6d8 else math.atan2(value,other) if a==0x140c8f29c else math.sin(value) if a==0x140c7a2b0 else math.cos(value)
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish();return
 if 0x1407e7f05<=a<0x1407e81f2 or 0x14022a000<=a<0x140231000:return
 raise RuntimeError('Unexpected native weather placement dependency '+hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
inputs=[[1,0,0,0],[0,0,0,1],[0,1,0,0],[.5,.5,.5,.5],[.8,.1,.3,.4]]
for yaw,pitch in itertools.product([-170,-45,0,45,135,180],[10,35,60,90]):
 # Native quaternion components w,x,y,z. Independent source inputs; the
 # actual application's camera-to-native frame adapter has a separate test.
 a,b=math.radians(yaw)/2,math.radians(pitch)/2
 inputs.append([math.cos(a)*math.cos(b),math.cos(a)*math.sin(b),math.sin(a)*math.sin(b),math.sin(a)*math.cos(b)])
for position,q in itertools.product([[0,0,0],[15.22,49.38,.31],[-100.25,25.75,8]],inputs):
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));poses={}
 for i,v in enumerate(position):m.wf(player+0x38+i*4,v)
 for i,v in enumerate(q):m.wf(quat+i*4,v)
 m.wq(camera,cv);m.wq(cv+0x48,m.stop+0x10)
 for i,obj in enumerate(models):m.wq(area+0x258+i*8,obj);m.wq(obj,gv)
 m.wq(gv+0xb0,m.stop+0x20);m.wq(gv+0xb8,m.stop+0x30)
 for r,v in [(UC_X86_REG_RSP,m.stack+0x8000),(UC_X86_REG_RBP,m.stack+0x10000),(UC_X86_REG_RDI,area),(UC_X86_REG_RBX,player),(UC_X86_REG_RCX,camera),(UC_X86_REG_R14,0),(UC_X86_REG_XMM6,0),(UC_X86_REG_XMM10,0x40a00000)]:u.reg_write(r,v)
 u.emu_start(0x1407e7f05,0x1407e81f2,count=20000);assert u.reg_read(UC_X86_REG_RIP)==0x1407e81f2
 rows.append(dict(position=[struct.unpack('<f',struct.pack('<f',v))[0]for v in position],quaternion=[struct.unpack('<f',struct.pack('<f',v))[0]for v in q],poses=[poses[i]for i in range(6)]))
out=Path(sys.argv[1]);assert not out.exists();out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),models=len(rows)*6,output=str(out))))
