"""Execute original party health mode selection140854740 and status animation
clamp/time1401eb7c0 unchanged. Only model animation publication and scene refresh
are captured; no live process, server or game state is modified.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);portrait=m.heap+0x1000
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def cstring(ptr):
 out=bytearray()
 while ptr and len(out)<64:
  b=bytes(u.mem_read(ptr,1));ptr+=1
  if b==b'\0':return out.decode('ascii')
  out.extend(b)
 raise AssertionError('Unterminated original status clip')
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x1401fb350:
  publications.append(dict(clip=cstring(u.reg_read(UC_X86_REG_RDX)),time=xmm(UC_X86_REG_XMM2),timeBits=u.reg_read(UC_X86_REG_XMM2)&0xffffffff));m.finish()
 elif a==0x14008c080:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x140854740,0x1408547a4),(0x1401eb7c0,0x1401eb7ff)]):raise AssertionError(f'Uncaptured original health dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for poison,disease,percent in itertools.product([-1,0,1,2],[-1,0,1,2],[-25.0,0.0,1.0,25.0,33.33333206176758,50.0,75.0,100.0,150.0]):
 publications=[];u.mem_write(portrait,bytes(0x1000));u.mem_write(m.stack,bytes(0x20000));m.wi(portrait+0x158,poison);m.wi(portrait+0x15c,disease);m.wf(portrait+0x150,percent);m.wq(portrait+0xe0,m.heap+0x4000)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,portrait)
 u.emu_start(0x140854740,m.stop,count=10000)
 assert u.reg_read(UC_X86_REG_RIP)==m.stop and len(publications)==1
 rows.append(dict(poison=poison,disease=disease,percent=percent,clamped=m.rf(portrait+0x150),clampedBits=int.from_bytes(u.mem_read(portrait+0x150,4),'little'),publication=publications[0]))
out=m.root/'backups/animations/native-party-health-observations-v1.json';assert not out.exists(),'Preserve prior evidence';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),target=m.digest)))
