"""Original Math ordinal74 and original double CRT SSE log. VM FLOAT
pop/push are captured; positivity guard, conversion, CRT instructions and
FLOAT return execute. This validates SSE, not original FMA CPU dispatch.
NaN/nonpositive inputs bypass CRT in the native wrapper.
"""
import importlib.util,json,struct,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
def hook(u,a,n,_):
    global output
    if a==m.stop:u.emu_stop();return
    if a==0x1402860c0:m.wi(u.reg_read(UC_X86_REG_RDX),inputBits);m.finish(1)
    elif a==0x1402863b0:output=u.reg_read(UC_X86_REG_XMM1)&0xffffffff;m.finish(1)
    elif not(0x140314240<=a<0x140314490 or 0x140c927f0<=a<0x140c92d1b):raise AssertionError(f'Uncaptured script log dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);m.wq(m.heap+0x10,m.heap+0x100);m.wi(m.heap+0x18,1);m.wi(0x1415d8224,0)
inputs=[struct.unpack('<I',struct.pack('<f',v))[0] for v in [0.,-0.,-1.,1.,2.,10.,.9375,1.0625,.99999994,1.0000001,1e-30,1e30]]+[1,2,0x7fffff,0x800000,0x7f7fffff,0x7fc00000]
rng=random.Random(20261014);inputs+=[rng.randrange(1,0x7f800000) for _ in range(6000)]
rows=[]
for inputBits in inputs:
    output=None;rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,m.heap);u.reg_write(UC_X86_REG_RDX,74)
    u.emu_start(0x140314240,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    rows.append(dict(inputBits=inputBits,bits=output))
out=m.root/'backups/animations/native-script-log-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
