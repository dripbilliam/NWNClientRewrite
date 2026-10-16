"""Complete generic MdlNodeControl140051c50..140051e59 composed with actual
native scalar/vector/quaternion samplers, slerp and original CRT math/status.
Runtime remapped synthetic controllers/Part fields. Motion140052e20 is captured;
disk remapping, specialized nodes, hierarchy and final scene are not exercised.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
node,part,controllers,values,run=[m.heap+n*0x1000 for n in range(1,6)]
ranges=[(0x140051c50,0x140051e59),(0x1400512c0,0x140051466),(0x140051530,0x140051749),(0x140051750,0x140051b0e),(0x140231cd0,0x140231f37),(0x140c79a38,0x140c79c87),(0x140c7a2b0,0x140c7a9a6),(0x140cae8e0,0x140cae8ff),(0x140cc0140,0x140cc015a)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x140052e20:
  ptr=u.reg_read(UC_X86_REG_RCX);rsp=u.reg_read(UC_X86_REG_RSP);calls.append(['motion',(ptr-controllers)//12,m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28)])
  if c['truncate']:m.wi(node+0x80,1)
  m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected controller apply dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
pool=[0.0]*64;pool[0:2]=[0,1];pool[16:18]=[2,4];pool[32:38]=[1,2,3,4,5,6];pool[48:56]=[0,0,0,1,.5,.5,.5,.5]
def run_case(case):
 global c,calls
 c=case;calls=[];u.reg_write(UC_X86_REG_MXCSR,0x1f80);u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(node+0x78,controllers);m.wi(node+0x80,c['count']);m.wq(node+0x88,values);u.mem_write(values,struct.pack('<64f',*pool));m.wq(0x1412e00a0,run if c['motion']else 0);m.wf(0x14128e218,c['scale'])
 for i,(offset,kind,valuebase)in enumerate([(44,1,16),(16,3,32),(28,4,48),(44,1,16),(60,2,16)]):
  u.mem_write(controllers+i*12,struct.pack('<iHHHBB',offset,2,0,valuebase,kind,0))
 for offset,data in [(16,[2,-1,3]),(28,c['quaternion']),(44,[7])]:
  for i,v in enumerate(data):m.wf(part+offset+i*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wf(rsp+0x28,c['weight']);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,node);u.reg_write(UC_X86_REG_RDX,part)
 for reg,value in [(UC_X86_REG_XMM2,c['previous']),(UC_X86_REG_XMM3,c['time'])]:u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
 try:u.emu_start(0x140051c50,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,count=m.si(node+0x80),position=[m.rf(part+16+i*4)for i in range(3)],quaternion=[m.rf(part+28+i*4)for i in range(4)],scalar=m.rf(part+44))
rows=[run_case(dict(count=count,weight=weight,scale=scale,time=time,previous=-.25,motion=motion,truncate=truncate,quaternion=quaternion))for count,weight,scale,time,motion,truncate,quaternion in itertools.product([0,5],[-1,0,.5,1,1.5],[.3,1],[0,.25,1], [0,1],[0,1],[[1,0,0,0],[-1,0,0,0]])]
out=m.root/'backups/animations/native-model-controller-apply-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
