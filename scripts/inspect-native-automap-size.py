"""Original area LoadArea map-size block14035f72b..14035f750 including
the actual CRT rounding helper. This bounded block is not the whole loader.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
def hook(u,a,n,_):
 if a==0x14035f750:u.emu_stop();return
 if not(0x14035f72b<=a<0x14035f750 or 0x140c7fef0<=a<=0x140c7ff80):raise RuntimeError(f'Unmapped map-size dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for width,height in itertools.product(range(33),range(33)):
 m.wi(m.heap+12,width);m.wi(m.heap+16,height);u.reg_write(UC_X86_REG_RBP,m.heap);u.reg_write(UC_X86_REG_RSP,m.stack+0x1fe08)
 u.emu_start(0x14035f72b,0x14035f750,count=1000);assert u.reg_read(UC_X86_REG_RIP)==0x14035f750
 rows.append(dict(width=width,height=height,bytes=u.mem_read(m.heap+0x348,1)[0]))
out=m.root/'backups/animations/native-automap-size-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
