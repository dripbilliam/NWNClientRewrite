"""Original GetCompressedRaster0f56c0 selection, with synthetic Exists results.

Resource catalog queries and string copies are captured. Original format/table
precedence executes unchanged; stop before allocation/decompression. No assets
are copied and no rendering or decompression parity is claimed.
"""
import sys, importlib, itertools, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
def hook(u,a,n,data):
 if a==m.stop:u.emu_stop();return
 if a==0x14018ded0:m.finish(u.reg_read(UC_X86_REG_RCX));return
 if a==0x14018f590:
  kind=u.reg_read(UC_X86_REG_R8)&0xffff;location=locations[kind]
  m.wi(u.reg_read(UC_X86_REG_R9),location);m.finish(int(location!=0));return
 if a==0x1400f584f:
  global selected
  selected=u.reg_read(UC_X86_REG_RDI)&0xffff;u.emu_stop();return
 if not 0x1400f56c0<=a<=0x1400f599f:raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for values in itertools.product([0,1,2,3,5],repeat=4):
 locations=dict(zip([2073,2033,2059,3],values));selected=None
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop)
 u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[m.heap,m.heap+0x1000,m.heap+0x1010,m.heap+0x1020]):u.reg_write(reg,value)
 u.emu_start(0x1400f56c0,m.stop,count=10000)
 assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x1400f584f]
 rows.append(dict(locations=locations,selected=selected))
out=m.root/'backups/animations/native-texture-format-selection-v1.json'
out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows))))
