"""Execute unchanged838950 hit-die arithmetic block838aa8..838b21 and
unchanged CRT randc7ed00. Current die, total-level getter, active rules lookup,
application flag and private TLS seed are explicit input boundaries. Stop
before debug/HP/summary writes. This is not a full finalizer/server oracle.
"""
from pathlib import Path
import importlib.util,json,hashlib
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('level_die_image',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE,UcError,UC_ERR_EXCEPTION,Uc,UC_ARCH_X86,UC_MODE_64
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
needs_reset=False
actor,rules,manager,app,tls=[m.heap+n for n in [0x1000,0x10000,0x20000,0x21000,0x22000]]
def hook(u,address,size,unused):
    global random_calls
    if address==0x140838b21:u.emu_stop();return
    if address==0x1402ae870:
        key=bytes(u.mem_read(u.reg_read(UC_X86_REG_RCX),30)).split(b'\0')[0]
        assert key==b'IN_LEVEL_FOR_MAX_HP' and u.reg_read(UC_X86_REG_R8)==0xaf64004c860229b8
        m.finish(1)
    elif address==0x1402a4130:m.finish(case['threshold'])
    elif address==0x1407f5d70:assert u.reg_read(UC_X86_REG_RCX)==actor;m.finish(case['total'])
    elif address==0x140ca98a0:random_calls+=1;m.finish(tls)
    elif not(0x140838aa8<=address<0x140838b21 or 0x140c7ed00<=address<0x140c7ed40):raise AssertionError('Uncaptured original hit-die dependency '+hex(address))
u.hook_add(UC_HOOK_CODE,hook)
def reset_cpu():
    # A divide exception poisons Unicorn's pending CPU exception state.
    # Each subsequent case must start on a clean emulated CPU, not treat a
    # silent repeat at IDIV as an original return. Original bytes unchanged.
    global u
    u=Uc(UC_ARCH_X86,UC_MODE_64);u.mem_map(m.base,(m.pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(m.base,m.pe.get_memory_mapped_image())
    u.mem_map(m.heap,0x100000);u.mem_map(m.stack,0x20000);u.mem_map(m.stop,0x1000);m.u=u;u.hook_add(UC_HOOK_CODE,hook)
def run(value):
    global case,random_calls,needs_reset
    if needs_reset:reset_cpu();needs_reset=False
    case=value;random_calls=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8f8,rules);m.wq(0x1412df970,manager);m.wq(manager,app);m.wi(app+0x24,case['forceMaximum']);m.wi(tls+0x28,case['seed'])
    u.reg_write(UC_X86_REG_RSP,m.stack+0x1fe00);u.reg_write(UC_X86_REG_RBP,m.stack+0x1f800);u.reg_write(UC_X86_REG_R15,actor);u.reg_write(UC_X86_REG_RDI,case['die'])
    undefined=False
    try:u.emu_start(0x140838aa8,0x140838b21,count=10000)
    except UcError as error:
        if error.errno!=UC_ERR_EXCEPTION or u.reg_read(UC_X86_REG_RIP)!=0x140838b05:raise
        undefined=True
        needs_reset=True
    if not undefined and u.reg_read(UC_X86_REG_RIP)!=0x140838b21:
        diagnostic=dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)),randomCalls=random_calls,seedAfter=m.si(tls+0x28)&0xffffffff)
        out=root/'godot-client/.cache/level-up-hit-die/oracle-failed-v1/diagnostic-after-reset.json';assert not out.exists();out.write_text(json.dumps(diagnostic,indent=2)+'\n');raise AssertionError(diagnostic)
    return dict(case=case,undefinedDivision=undefined,value=None if undefined else u.reg_read(UC_X86_REG_RBX)&255,seedAfter=m.si(tls+0x28)&0xffffffff,randomCalls=random_calls)
if __name__=='__main__':
    out=root/'godot-client/reports/native-level-up-hit-die-original-v1.json';assert not out.exists(),'Preserve original evidence'
    rows=[]
    for at,die in enumerate([0,1,3,4,6,8,10,12,20,126,127,128,129,252,253,254]):
        for step,(total,threshold)in enumerate([(1,3),(3,3),(4,3),(21,20),(255,-1),(4,1000)]):
            for force in [0,1]:rows.append(run(dict(die=die,total=total,threshold=threshold,forceMaximum=force,seed=[0,1,0xffffffff][(at+step+force)%3])))
    out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,rows=rows,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()),indent=2)+'\n');print(json.dumps(dict(output=str(out),cases=len(rows),undefined=sum(row['undefinedDivision']for row in rows))))
