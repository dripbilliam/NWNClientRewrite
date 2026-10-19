"""Execute original packet-encryption predicate across byte and size boundaries."""
import importlib,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    if not 0x140176360<=a<0x1401763b0:raise RuntimeError(f'Unexpected policy dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
source=m.heap+0x1000;rows=[]
inputs=[b'BN'+bytes([c])+b'X' for c in range(256)]
inputs += [b'BNCSxx'[:n] for n in range(7)] + [b'ANES',b'BXES',b'M\0\0\0',b'BNVS']
for packet in inputs:
    u.mem_write(source,packet or b'\0');rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
    for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,0),(UC_X86_REG_RDX,source),(UC_X86_REG_R8,len(packet))]:u.reg_write(reg,value)
    u.emu_start(0x140176360,m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    rows.append(dict(packet=packet.hex(),requiresEncryption=bool(u.reg_read(UC_X86_REG_RAX)&0xffffffff)))
output=m.root/'backups/animations/native-network-encryption-policy-observations.json'
output.write_text(json.dumps(dict(target=m.digest,cases=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),output=str(output))))
