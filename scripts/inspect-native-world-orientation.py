"""Complete original common49b910 and placeable4b7680 orientation setters.
Area/static-mesh lookup, collision ReplaceStaticObject and action-point rebuild
are captured boundaries. Verifies raw vector writes, FLOAT dot/order/threshold
and all rebuild guards; not lower PWK transforms or array replacement.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,vectorPtr,areaPtr,appPtr,meshPtr,verticesPtr,facesPtr=[m.heap+n*0x1000 for n in range(1,8)]
thresholdPtr=0x1404b76ed+0x93c087;threshold=m.rf(thresholdPtr)
def value(v):return math.nan if v=='nan'else v
def vector(ptr):return[struct.unpack('<I',u.mem_read(ptr+i*4,4))[0]for i in range(3)]
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x140494e80:assert x==objectPtr;calls.append(['area']);m.finish(areaPtr if c['area']else 0);return
 if at==0x14055b880:assert x==appPtr;calls.append(['tileSetManager']);m.finish(appPtr);return
 if at==0x1402cd9b0:assert x==appPtr;calls.append(['mesh',y&65535]);m.finish(meshPtr if c['mesh']else 0);return
 if at==0x140298d50:
  assert x==areaPtr and m.q(rsp+0x38)==verticesPtr and m.q(rsp+0x48)==facesPtr;calls.append(['replace',y&0xffffffff,z&0xffffffff,vector(w),vector(m.q(rsp+0x28)),m.si(rsp+0x30),m.si(rsp+0x40)]);m.finish();return
 if at==0x1404b1bf0:calls.append(['points']);m.finish();return
 if not(0x14049b910<=at<0x14049b926 or 0x1404b7680<=at<0x1404b7787):raise AssertionError(f'Uncaptured orientation dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wi(objectPtr+8,42);m.wi(objectPtr+0x50c,3);u.mem_write(objectPtr+0x32c,(17).to_bytes(2,'little'))
 for i,v in enumerate(c['old']):m.wf(objectPtr+0xb0+i*4,value(v))
 for i,v in enumerate(c['new']):m.wf(vectorPtr+i*4,value(v))
 for i,v in enumerate([1,2,3]):m.wf(objectPtr+0xa4+i*4,v)
 m.wq(meshPtr+0x28,verticesPtr);m.wq(meshPtr+0x30,facesPtr);m.wi(meshPtr+0x38,4);m.wi(meshPtr+0x3c,5)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,objectPtr);u.reg_write(UC_X86_REG_RDX,vectorPtr)
 try:u.emu_start(0x14049b910 if c['common']else 0x1404b7680,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,orientation=vector(objectPtr+0xb0))
vectors=[[1,0,0],[0,1,0],[-1,0,0],[0,0,0],[2,0,0],[.5,.5,.5],['nan',0,0],[threshold,0,0],[threshold-.0000001,0,0]]
rows=[run(dict(common=common,area=area,mesh=mesh,old=old,new=new))for common,area,mesh,old,new in itertools.product([False,True],[False,True],[False,True],vectors[:4],vectors)]
out=m.root/'backups/animations/native-world-orientation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,threshold=threshold,thresholdAddress=f'{thresholdPtr:x}',rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),threshold=threshold,output=str(out))))
