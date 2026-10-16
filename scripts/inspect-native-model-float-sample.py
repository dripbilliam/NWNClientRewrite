"""Complete original NewController::GetFloatValue1400512c0..140051466
with actual InterpolateBezier14022ce00..14022ceb4. Synthetic runtime remapped
controller/value pools, not disk parsing, hierarchy or blended presentation.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
controller,node,output,values=[m.heap+n for n in [0x1000,0x2000,0x3000,0x10000]]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a==0x140047300:
  ptr=u.reg_read(UC_X86_REG_RCX);u.mem_write(ptr,bytes(12));m.finish(ptr);return
 if not(0x1400512c0<=a<0x140051466 or 0x14022ce00<=a<0x14022ceb4 or 0x140051530<=a<0x140051749 or 0x140051750<=a<0x140051b0e or 0x14022cba0<=a<0x14022cdfe or 0x140231cd0<=a<0x140231f37 or 0x140c79a38<=a<0x140c79c87 or 0x140c7a2b0<=a<0x140c7a9a6 or 0x140cae8e0<=a<0x140cae8ff or 0x140cc0140<=a<0x140cc015a):raise RuntimeError(f'Unexpected sample dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
pool=[((i*13)%37-18)*.125 for i in range(65600)]
def run(c):
 u.reg_write(UC_X86_REG_MXCSR,0x1f80);u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(values,struct.pack('<65600f',*pool));m.wq(node+0x88,values)
 u.mem_write(controller+4,struct.pack('<HHHB',c['rows'],0,c['valueBase'],c['flags']));m.wi(controller,c.get('displacement',0));m.wf(0x14128e218,c.get('scale',1))
 for i,v in enumerate([77.5,88.5,99.5,111.5]):m.wf(output+i*4,v)
 for i,v in enumerate(c['times']):m.wf(values+i*4,v)
 for i,q in enumerate(c.get('quaternions',[])):
  for j,v in enumerate(q):m.wf(values+(c['valueBase']+i*4+j)*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,controller);u.reg_write(UC_X86_REG_R8,node);u.reg_write(UC_X86_REG_R9,output);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['time']),'little'))
 try:u.emu_start(0x140051530 if c.get('quaternion')else 0x140051750 if c.get('vector')else 0x1400512c0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,value=[m.rf(output+i*4)for i in range(4 if c.get('quaternion')else 3)]if c.get('vector')or c.get('quaternion')else m.rf(output))
rows=[run(dict(rows=rows,flags=flags,time=time,valueBase=valueBase,times=times))for rows,flags,time,valueBase,times in itertools.product([0,1,2,3],[1,17,33,3,4],[-2,0,.25,.5,.75,1,1.25,2,5],[16,65534],[[0,.5,1],[0,.5,.5]])]
out=m.root/'backups/animations/native-model-float-sample-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
rows=[run(dict(vector=1,rows=rows,flags=flags,time=time,valueBase=valueBase,times=[0,.5,1],displacement=displacement,scale=scale))for rows,flags,time,valueBase,displacement,scale in itertools.product([0,1,3],[3,19,35,1],[-2,0,.25,.5,1,2],[16,65534],[16,44],[0,.3,1,2])]
out=m.root/'backups/animations/native-model-vector-sample-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits='Complete GetVectorValue140051750..140051b0e and actual vector InterpolateBezier14022cba0..14022cdfe. Vector constructors and security cookie are captured. Runtime remapped storage; disk/hierarchy/blending not tested.',rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
rows=[run(dict(quaternion=1,rows=rows,flags=flags,time=time,valueBase=valueBase,times=[0,.5,1],quaternions=quaternions))for rows,flags,time,valueBase,quaternions in itertools.product([0,1,3],[4,20,3],[-2,0,.125,.25,.5,.75,1,2],[16,65534],[[[0,0,0,1],[.5,.5,.5,.5],[0,0,1,0]],[[0,0,0,-1],[0,.6,0,.8],[.6,0,0,.8]],[[1,2,3,4],[4,3,2,1],[0,0,0,0]]])]
out=m.root/'backups/animations/native-model-quaternion-sample-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits='Complete GetQuaternionValue140051530..140051749 with actual slerp140231cd0, original acosf/sinf140c79a38/140c7a2b0 and FP status helpers140cae8e0/140cc0140/140cc0150 for these finite inputs. MXCSR starts0x1f80 per case. Runtime remapped storage; disk/hierarchy/blending and arbitrary JS-versus-CRT math parity not tested.',rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
