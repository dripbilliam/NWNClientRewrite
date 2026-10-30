"""Read-only original SetScrollRange1401e7950/SetScrollRangeVisible1401e7990.
Range clamping, float ratio, rounding and thumb-size animation time execute in
the original instructions. Only GUI animation publication/position are captured.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);slider=m.heap+0x1000
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x1401fb350:animations.append(xmm(UC_X86_REG_XMM2));m.finish()
 elif a==0x1401e7720:m.wi(slider+0xa0,u.reg_read(UC_X86_REG_RDX));m.finish()
 elif a==0x140115890:raise AssertionError('Original scrollbar range emitted a warning')
 elif not 0x1401e7950<=a<=0x1401e7af0:raise AssertionError(f'Uncaptured scrollbar dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(r,v,length):
 global animations
 animations=[];u.mem_write(slider,bytes(0x1000));u.mem_write(m.stack,bytes(0x20000));m.wq(slider+0x10,m.heap+0x3000);m.wi(slider+0xa8,v);m.wf(slider+0xac,length)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,slider);u.reg_write(UC_X86_REG_RDX,r&0xffffffff)
 u.emu_start(0x1401e7950,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop and len(animations)==1
 return dict(range=r,visible=v,length=length,clampedRange=m.si(slider+0xa4),thumbModelUnits=m.rf(slider+0xb0),animationTime=animations[0])
if __name__=='__main__':
 rows=[run(r,v,length)for r,v,length in itertools.product([-5,0,1,2,25,255],[0,1,20,200],[3.01,50,312])]
 out=m.root/'backups/animations/native-scroll-thumb-observations-v1.json';assert not out.exists(),'Preserve prior evidence';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
