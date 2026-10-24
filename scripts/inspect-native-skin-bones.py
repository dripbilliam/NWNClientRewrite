"""Original ExecuteSkinGPU bone loop with original quaternion/vector math.
Captures prepare/SetBoneMatrix and stops before GL render-state submission.
Synthetic poses test inverse binds, invalid slots, duplicate/root stopping.
"""
import sys,importlib,json,struct,math,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
skin,positions,rotations,positionData,rotationData,invPositions,invRotations,primitive,vtable=[m.heap+n*0x1000 for n in range(1,10)]
def hook(u,a,n,data):
 if a==0x1400dee57:u.emu_stop();return
 if a==m.stop+0x10:m.finish();return
 if a==0x1400bf000:
  matrices.append(dict(slot=u.reg_read(UC_X86_REG_RCX),matrix=list(struct.unpack('<16f',bytes(u.mem_read(u.reg_read(UC_X86_REG_RDX),64))))));m.finish();return
 if not(0x1400deb90<=a<0x1400dee57 or 0x14022a000<=a<=0x140230000):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for angle,bind,slots in itertools.product([0,.3,1.2],[[0,0,0],[.25,-.5,1.5]],[[0],[1,0],[1,1,0],[0,0,1],[-1,2,99,0]]):
 u.mem_write(m.heap,bytes(0x100000));matrices=[]
 p=[[1,2,3],[-.25,.5,1.75],[0,0,0]];q=[[math.cos(angle/2),0,0,math.sin(angle/2)],[math.cos(angle/2),math.sin(angle/2),0,0],[1,0,0,0]]
 iq=[[math.cos(-angle/3),0,0,math.sin(-angle/3)]]*3;ip=[bind]*3
 for address,values in [(positionData,p),(rotationData,q),(invPositions,ip),(invRotations,iq)]:u.mem_write(address,struct.pack('<'+'f'*sum(map(len,values)),*(v for row in values for v in row)))
 m.wq(positions,positionData);m.wi(positions+8,3);m.wq(rotations,rotationData);m.wi(rotations+8,3);m.wq(skin+0x300,invPositions);m.wq(skin+0x2f0,invRotations)
 u.mem_write(skin+0x320,struct.pack('<64h',*(slots+[-1]*(64-len(slots)))));m.wq(primitive,vtable);m.wq(vtable+0x30,m.stop+0x10)
 sp=m.stack+0x1fe08;u.mem_write(sp-0x800,bytes(0x900));m.wq(sp,m.stop)
 for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RCX,skin),(UC_X86_REG_RDX,positions),(UC_X86_REG_R8,rotations),(UC_X86_REG_R9,primitive)]:u.reg_write(reg,value)
 u.emu_start(0x1400deb90,m.stop,count=20000)
 rows.append(dict(positions=p,quaternions=q,inversePositions=ip,inverseQuaternions=iq,slots=slots,matrices=matrices))
out=m.root/'backups/animations/native-skin-bones-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows))))
