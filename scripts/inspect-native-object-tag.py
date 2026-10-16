"""Complete original AsTAG14016ac40, SetTag14045df80 and CRT classifier
140c89e6c with its original immutable static C-locale table. Locale-change
branch is not covered. Only allocation/free/memcpy/cookie are boundaries.
"""
import importlib.util,json,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);objectPtr,inputPtr,outputPtr=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr
def value(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8))).decode('ascii') if m.q(ptr) else ''
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if at==0x140c10368:m.finish(alloc(x));return
 if at in [0x140c10360,0x140c10370]:m.finish();return
 if at==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=at<hi for lo,hi in [(0x14016ac40,0x14016adf5),(0x14045df80,0x14045dfe8),(0x140c89e6c,0x140c89ea8)]):raise AssertionError(f'Uncaptured tag dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def decoded(raw):
 result=''
 for byte in raw:
  try:result+=bytes([byte]).decode('cp1252')
  except UnicodeDecodeError:result+=chr(byte)
 return result
def run(raw,mode):
 global cursor
 cursor=0x10000;u.mem_write(m.heap,bytes(0x100000));assert m.si(0x1415d7c18)==0;assert m.q(0x1412a2090)==0x140ed68b0
 if raw is not None:
  source=alloc(len(raw)+1);u.mem_write(source,raw+b'\0');m.wq(inputPtr,source);m.wi(inputPtr+8,len(raw));m.wi(inputPtr+12,len(raw)+1)
 # Input descriptor may have a null data pointer, or own an empty buffer.
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 u.reg_write(UC_X86_REG_RCX,inputPtr if mode=='asTag' else objectPtr);u.reg_write(UC_X86_REG_RDX,outputPtr if mode=='asTag' else inputPtr)
 u.emu_start(0x14016ac40 if mode=='asTag' else 0x14045df80,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(mode=mode,input=None if raw is None else decoded(raw),result=value(outputPtr if mode=='asTag' else objectPtr+0x20))
inputs=[None,b'',b'--a b_C.d!2--',b'\0tail',b'a\0tail',b'a'*62+b' !'+b'B'*100,b'!'*300+b'z',bytes(range(256))]+[bytes([byte])for byte in range(256)]
rng=random.Random(20261016)
inputs.extend(bytes(rng.randrange(256)for _ in range(rng.randrange(260)))for _ in range(180))
rows=[run(raw,mode)for raw in inputs for mode in ['asTag','setTag']]
out=m.root/'backups/animations/native-object-tag-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
