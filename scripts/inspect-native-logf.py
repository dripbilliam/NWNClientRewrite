"""Verified original logf SSE body and independent CRT observations.
CRT exception/errno helper is a captured boundary returning its original
requested result. Only the original SSE branch is trusted here. Original AVX
attempts produced invalid emulator outputs and unsupported FMA failures;
those captures are retained separately, excluded from parity expectations.
Independent installed ucrtbase.logf outputs are supplementary observations,
not a substitute for original FMA instruction validation or CPU-state parity.
"""
import importlib.util,json,struct,random,ctypes
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
m.u.hook_del(m.hook_handle);u=Uc(UC_ARCH_X86,UC_MODE_64);u.ctl_set_cpu_model(UC_CPU_X86_HASWELL)
u.mem_map(m.base,(m.pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(m.base,m.pe.get_memory_mapped_image())
u.mem_map(m.heap,0x100000);u.mem_map(m.stack,0x20000);u.mem_map(m.stop,0x1000);m.u=u;exceptions=[]
crt=ctypes.CDLL('ucrtbase.dll')
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    if a==0x140cb5b64:
        exceptions.append(u.reg_read(UC_X86_REG_R8)&0xffffffff);u.reg_write(UC_X86_REG_XMM0,u.reg_read(UC_X86_REG_XMM1));m.finish()
    elif not 0x140c946b0<=a<0x140c94aa6:raise AssertionError(f'Uncaptured logf dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def bits(v):return struct.unpack('<I',struct.pack('<f',v))[0]
inputs=[bits(v) for v in [0.,-0.,1.,.9375,1.0625,.99999994,1.0000001,.5,2.,10.,1e-30,1e30]]
inputs+=[1,2,3,0x7fffff,0x800000,0x7f7fffff]
rng=random.Random(20261014);inputs+=[rng.randrange(1,0x7f800000) for _ in range(6000)]
rows=[]
for inputBits in inputs:
    outputs=[]
    for branch in [0]:
        exceptions.clear();m.wi(0x1415d8224,branch);rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_XMM0,inputBits)
        try:u.emu_start(0x140c946b0,m.stop,count=5000)
        except Exception:print(json.dumps(dict(inputBits=inputBits,branch=branch,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
        assert u.reg_read(UC_X86_REG_RIP)==m.stop;outputs.append(dict(bits=u.reg_read(UC_X86_REG_XMM0)&0xffffffff,exceptions=list(exceptions)))
    rows.append(dict(inputBits=inputBits,outputs=outputs))
crtLog=crt.logf;crtLog.argtypes=[ctypes.c_float];crtLog.restype=ctypes.c_float
for row in rows:row['independentCrtBits']=bits(crtLog(struct.unpack('<f',struct.pack('<I',row['inputBits']))[0]))
out=m.root/'backups/animations/native-logf-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
