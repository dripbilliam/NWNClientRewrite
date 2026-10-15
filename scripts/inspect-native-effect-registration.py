"""Original InitializeEffects140425c30 writes99 apply/removal pairs.
Only two array allocations are captured. Metadata only; no binary/assets.
Use this table to verify application owners against actual constructor types.
"""
import importlib.util,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);handler=m.heap;allocation=0
def hook(u,a,n,_):
    global allocation
    if a==m.stop:u.emu_stop();return
    if a==0x140c10368:assert u.reg_read(UC_X86_REG_RCX)==0x318;allocation+=1;m.finish(m.heap+allocation*0x1000)
    elif not 0x140425c30<=a<0x14042685a:raise AssertionError(f'Uncaptured effect registration dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,handler)
u.emu_start(0x140425c30,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
rows=[dict(type=id,apply=f'{m.q(m.q(handler+8)+id*8):x}',remove=f'{m.q(m.q(handler+16)+id*8):x}') for id in range(99)]
out=m.root/'backups/animations/native-effect-registration-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
