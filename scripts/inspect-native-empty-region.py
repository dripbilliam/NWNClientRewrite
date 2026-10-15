"""Original surface/tile region query for empty native path-node graphs.
Graph lookup is captured. Wrapper rotation executes on indeterminate local
scratch after surface failure. Only the status is compared; no XY output
is claimed deterministic or safe to consume when GetRegionCoords returns0.
"""
import importlib.util,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);q,wi,wq,finish=[getattr(m,n) for n in ['q','wi','wq','finish']]
tile,info,mesh,node,output,app=[m.heap+n*0x1000 for n in range(1,7)]
ranges=[(0x1404fdb90,0x1404fdc22),(0x1402bec00,0x1402beccf),(0x1402c5630,0x1402c569a)]
def hook(u,a,n,_):
    if a==m.stop:u.emu_stop();return
    if a==0x1402ca830:finish(node)
    elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured region query dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
graphs=json.loads((m.root/'backups/animations/native-tile-path-node-observations.json').read_text())['graphs'];rows=[]
for key,orientations in graphs.items():
    if orientations[0]['centres']:continue
    for rotation in range(4):
        for index in [0,1,2147483647]:
            u.mem_write(m.heap,bytes(0x100000));wq(0x1412df970,app);wq(app+16,app);wq(tile+0x30,info);wq(info+8,mesh);wi(tile+0x24,rotation);wi(node,0)
            rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
            for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[tile,index,output,output+4]):u.reg_write(reg,v)
            u.emu_start(0x1404fdb90,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
            rows.append(dict(kind=int(key),orientation=rotation,index=index,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
out=m.root/'backups/animations/native-empty-region-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
