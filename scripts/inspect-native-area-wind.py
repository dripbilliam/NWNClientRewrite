"""Original area SetWind normalization/defaults. Six-decimal renderer command
formatting is a captured boundary; scene degrees-to-radians follows observed
SetGlobalWind. This is synthetic arithmetic, not a live server capture.
"""
import importlib,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
area=m.heap
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1402991e0,0x1402992d9),(0x140230920,0x1402309f6)]):raise RuntimeError(f'Unexpected area wind dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def f(v):return struct.unpack('<f',struct.pack('<f',v))[0]
rows=[]
for power in range(5):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 initial=[.2,-.4,.6,3.4567,17.123456,2.345678]
 for n,v in enumerate(initial):m.wf(area+0xe8+4*n,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,area);u.reg_write(UC_X86_REG_RDX,power)
 u.emu_start(0x1402991e0,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 values=[m.rf(area+0xe8+4*n)for n in range(6)]
 expected=dict(wind=[f(float('%.6f'%f(v*values[3])))for v in values[:3]],deviation=f(f(float('%.6f'%values[4]))*f(.017453292)),pitch=f(f(float('%.6f'%values[5]))*f(.017453292)))
 rows.append(dict(power=power,input=initial,values=values,accepted=u.reg_read(UC_X86_REG_RAX)&0xffffffff,expected=expected))
output=m.root/'backups/animations/native-area-wind-observations-v1.json';assert not output.exists();output.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(output),rows=len(rows))))
