"""Read-only NWN:EE89.8193.37-17 creation rule observations.
Original GetIsAlignmentAllowed and client ability-increment bodies execute
unchanged. FNV/ruleset lookup is a captured boundary for the client helper;
this does not execute the complete original creation wizard or validator.
"""
from pathlib import Path
import importlib.util,json,itertools
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('mapped',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
current={};rules=m.heap+0x9000

def hook(u,address,size,_):
    if address==m.stop:u.emu_stop();return
    if address==0x1402ae870:
        current['lookups']+=1;m.finish(current['lookups']);return
    if address==0x1402a4130:
        m.finish(current['thresholds'][current['lookups']-1]);return
    if not (0x140299900<=address<0x140299a10 or 0x1408e05e0<=address<0x1408e06b0):raise RuntimeError(f'Uncaptured creation dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(address,args):
    rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
    for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
    u.emu_start(address,m.stop,count=1000)
    assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return u.reg_read(UC_X86_REG_RAX)&255

if __name__=='__main__':
    alignment=[];increments=[]
    for mask,axes,invert,ge,lc in itertools.product(range(32),range(4),range(2),[1,4,5],[1,2,3]):
        u.mem_write(m.heap+0x4a1,bytes([mask,axes]));m.wi(m.heap+0x4a4,invert)
        alignment.append(dict(mask=mask,axes=axes,invert=invert,goodEvil={1:50,4:85,5:15}[ge],lawChaos={1:50,2:85,3:15}[lc],result=run(0x140299900,[m.heap,ge,lc,0])))
    m.wq(0x1412df8f8,rules)
    for thresholds in [[14,16,255],[10,12,16],[8,10,12]]:
        for score in range(8,20):
            current=dict(thresholds=thresholds,lookups=0)
            increments.append(dict(thresholds=thresholds,score=score,result=run(0x1408e05e0,[m.heap,score,0,0])))
    out=root/'backups/animations/native-character-creation-observations.json'
    out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,alignment=alignment,increments=increments),indent=2))
    print(json.dumps(dict(output=str(out),alignment=len(alignment),increments=len(increments))))
