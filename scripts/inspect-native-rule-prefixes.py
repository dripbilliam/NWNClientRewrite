"""Full native FNV continuation2ae870..2ae898. Inputs are the exact
suffix/length/seed observed at verified feat, price and associate call sites.
No hash or rule lookup boundary stub: the hash leaf executes unchanged.
"""
import importlib.util,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 if not 0x1402ae870<=at<0x1402ae899:raise AssertionError(f'Uncaptured hash dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for label,suffix,seed,site in [('EPIC_GREAT_STAT_BONUS','PIC_GREAT_STAT_BONUS',0xaf63f84c86021c20,0x140409823),('MAX_CHARGES_FOR_ITEM_COST','AX_CHARGES_FOR_ITEM_COST',0xaf64004c860229b8,0x14046518e),('ALL_ASSOCIATES_CAN_INTERACT','LL_ASSOCIATES_CAN_INTERACT',0xaf63fc4c860222ec,0x1403d14dd)]:
 u.mem_write(m.heap,suffix.encode('ascii')+b'\0');rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[m.heap,len(suffix),seed]):u.reg_write(reg,value)
 u.emu_start(0x1402ae870,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 rows.append(dict(label=label,suffix=suffix,seed=f'{seed:016x}',callSite=f'{site:x}',hash=f'{u.reg_read(UC_X86_REG_RAX):016x}'))
out=m.root/'backups/animations/native-rule-prefix-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
