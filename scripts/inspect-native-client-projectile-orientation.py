"""Original projectile model orientation9ddda0, vector yaw/pitch and
YawPitchRoll, original vector/quaternion and embedded SSE CRT math. Only the
model quaternion setter, sqrtf and CRT FP-status notification are captured.
SSE dispatch0/round-nearest;
full process CPU detection, FP status and renderer basis are separate.
"""
import importlib.util,json,struct,itertools,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
handle,model,vt,vector=[m.heap+n*0x1000 for n in range(1,5)];setter=m.stop+0x10
ranges=[(0x1402303d0,0x14023040d),(0x140230920,0x1402309f6),(0x14022ab00,0x14022ac34),(0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f),(0x140c79d30,0x140c7a2aa),(0x140c92d20,0x140c93360),(0x140c8f29c,0x140c8f6ad)]
for file in ['client-projectile-model-orientation','client-vector-pitch','client-vector-yaw-vector','client-yaw-pitch-roll']:
 r=json.loads((m.root/f'backups/animations/rea-{file}.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges += [(int(e['start'],16),int(e['end'],16)+1)for e in r['ranges']]
def hook(u,a,n,_):
 global quaternion
 if a==m.stop:u.emu_stop();return
 if a==setter:quaternion=list(struct.unpack('<4I',u.mem_read(u.reg_read(UC_X86_REG_R8),16)));m.finish()
 elif a==0x140c7d6d8:
  value=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM0)&0xffffffff))[0];u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(value)),'little'));m.finish()
 elif a==0x140cae8e0:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured orientation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(v):
 global quaternion
 quaternion=None;u.mem_write(m.heap,bytes(0x10000));m.wq(handle+0xc8,model);m.wq(model,vt);m.wq(vt+0xb8,setter);u.mem_write(vector,struct.pack('<3f',*v));m.wi(0x1415d8224,0);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,handle);u.reg_write(UC_X86_REG_RDX,vector);u.emu_start(0x1409ddda0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(vector=v,quaternion=quaternion,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
rows=[run(list(v))for v in itertools.product([-2,-1,0,1,2],repeat=3)]+[run(v)for v in [[.00001,0,0],[.0001,0,0],[.00010001,0,0],[.5,.25,.75],[0,-0.0,0]]]
out=m.root/'backups/animations/native-client-projectile-orientation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
