"""Original Gob adjusted position/orientation/scale on synthetic model state.

Original quaternion/vector operations and YawPitchRoll execute. Only host
sinf/cosf are captured; no original CRT bit-identity or full rendering claim.
Native pose/scale results are recorded as derived numeric metadata only.
"""
import sys,importlib,json,itertools,math,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);obj,out=m.heap+0x1000,m.heap+0x2000
def hook(u,a,n,data):
 if a==m.stop:u.emu_stop();return
 if a in [0x140c7a2b0,0x140c7ac70]:
  value=(math.sin if a==0x140c7a2b0 else math.cos)(m.xmm(UC_X86_REG_XMM0));u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish();return
 if not (0x14008e200<=a<=0x14008e3b2 or 0x1402e9a80<=a<=0x1402e9ccf or 0x14022a000<=a<=0x140230000):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def call(entry):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x800,bytes(0x900));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,obj);u.reg_write(UC_X86_REG_RDX,out)
 u.emu_start(entry,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
rows=[]
for rotation,translation,yaw,scale,baseScale in itertools.product([[0,0,0],[90,0,0],[0,90,0],[0,0,90],[15,25,35]],[[0,0,0],[1,2,3]],[0,1.2],[.25,1,2],[1,1.5]):
 u.mem_write(obj,bytes(0x600));position=[10,20,30];q=[math.cos(yaw/2),0,0,math.sin(yaw/2)]
 for i,v in enumerate(position):m.wf(obj+0xa8+i*4,v)
 for i,v in enumerate(q):m.wf(obj+0xb4+i*4,v)
 for i,v in enumerate([scale,1,1]+rotation+translation+[1]):m.wf(obj+0x1c0+i*64+4,v)
 m.wf(obj+0x49c,baseScale);call(0x14008e200);adjustedQ=[m.rf(out+i*4)for i in range(4)];call(0x14008e2c0);adjustedP=[m.rf(out+i*4)for i in range(3)];call(0x14008e390);adjustedScale=m.xmm(UC_X86_REG_XMM0)
 rows.append(dict(rotation=rotation,translation=translation,position=position,quaternion=q,scale=scale,baseScale=baseScale,adjustedQuaternion=adjustedQ,adjustedPosition=adjustedP,adjustedScale=adjustedScale))
outFile=m.root/'backups/animations/native-gob-adjusted-pose-v1.json';outFile.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows))))
