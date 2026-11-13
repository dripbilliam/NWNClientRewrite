"""Execute unchanged original BAB getter7f0900/class leaf2997b0.
The active compiled60-BYTE class arrays are authored inputs, not a C2DA
loader oracle. Retained loader29a3c0 source separately proves successful
INT-to-BYTE/failed-read-zero loading. No process/server/GPU/build is used.
"""
from pathlib import Path
import importlib.util,json,random,struct,hashlib
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('level_bab_image',root/'scripts/inspect-native-intratile-coordinator.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
ranges=[(0x1407f0900,0x1407f0ad5),(0x1402997b0,0x1402997d0)]
def hook(u,address,size,unused):
    if address==m.stop:u.emu_stop();return
    if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError('Uncaptured original BAB dependency '+hex(address))
u.hook_add(UC_HOOK_CODE,hook)
actor,rules,classes=[m.heap+n for n in [0x1000,0x10000,0x20000]]
def run(case):
    u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8f8,rules);m.wq(rules+0x110,classes)
    u.mem_write(rules+0x105,bytes([len(case['bonus'])]));u.mem_write(actor+0x69,bytes([len(case['classes'])]));u.mem_write(actor+0x9b,bytes([case['cache']]))
    for at,values in enumerate(case['bonus']):assert len(values)==60;u.mem_write(classes+at*0x530+0x38,bytes(values))
    for at,cls in enumerate(case['classes']):u.mem_write(actor+at*0x150+0x295,bytes([cls['id'],cls['level']]))
    rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor)
    u.emu_start(0x1407f0900,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
    return dict(case=case,result=u.reg_read(UC_X86_REG_RAX)&255,cacheAfter=int(u.mem_read(actor+0x9b,1)[0]))
if __name__=='__main__':
    out=root/'godot-client/reports/native-level-up-attack-cache-original-v1.json';assert not out.exists(),'Preserve original evidence'
    rng=random.Random(1635);rows=[]
    for at in range(48):
        arrays=[[rng.randrange(256)for n in range(60)]for slot in range(8)]
        selected=[dict(id=slot,level=[0,1,20,21,40,59,60,61,254,255][(at+slot)%10])for slot in range(1+at%8)]
        rows.append(run(dict(classes=selected,bonus=arrays,cache=255)))
    for cache in [0,1,127,254]:rows.append(run(dict(classes=[dict(id=0,level=21)],bonus=[[239]*60],cache=cache)))
    report=dict(binarySha256=m.digest,scope=__doc__,rows=rows,procedures=[hex(lo)for lo,hi in ranges],scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(output=str(out),cases=len(rows))))
