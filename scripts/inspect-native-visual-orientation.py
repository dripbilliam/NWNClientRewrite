"""Complete CAurBehaviorAttachNoOrientation::Update140054ed0..140054f3d.
Actual object quaternion getters/setters execute; base attachment update is a
captured provider, including failure, object replacement and quaternion changes.
This fixture does not prove the base behavior's handle/event/lifetime machinery.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
behavior,obj,replacement,vtable=[m.heap+n*0x1000 for n in range(4)]
ranges=[(0x140054ed0,0x140054f3d),(0x140048520,0x14004852e),(0x140094f80,0x140094f92)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x140054cb0:
  calls.append(['base',m.xmm(UC_X86_REG_XMM1)])
  ptr=replacement if c['replace']else obj;m.wq(behavior+0x18,ptr)
  for i,v in enumerate(c['after']):m.wf(ptr+0xb4+i*4,v)
  m.finish(c['result'])
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(behavior+0x18,obj)
 for ptr in [obj,replacement]:m.wq(ptr,vtable)
 m.wq(vtable+0xc8,0x140048520);m.wq(vtable+0xb8,0x140094f80)
 for i,v in enumerate(c['before']):m.wf(obj+0xb4+i*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,behavior);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',c['delta']),'little'))
 u.emu_start(0x140054ed0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,original=[m.rf(obj+0xb4+i*4)for i in range(4)],replacement=[m.rf(replacement+0xb4+i*4)for i in range(4)])
rows=[run(dict(before=before,after=after,delta=delta,result=result,replace=replace))for before,after,delta,result,replace in itertools.product([[1,0,0,0],[.5,-.5,.5,-.5],[0,0,0,0]],[[0,1,0,0],[2,3,4,5]],[0,.125],[0,1,0xffffffff],[0,1])]
out=m.root/'backups/animations/native-visual-orientation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
