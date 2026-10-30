"""Execute unchanged original sort-header8d1eb0 and priority-promotion8d7a60
instructions. The final GUI reorder is an observed boundary, not executed here.
Input priority/direction arrays are supplied fixtures, not emulated constructors.
No process, network, configuration write or rendering is used.
"""
import hashlib,importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('sort_coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,vtable=m.heap+0x1000,m.heap+0x5000
ranges=[(0x1408d1eb0,0x1408d1f09),(0x1408d7a60,0x1408d7ab0)]
def hook(u,a,n,_):
 global sorted_gui
 if a==m.stop:u.emu_stop();return
 if a==m.stop+0x100:sorted_gui+=1;m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured original sort dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(order,directions,column,pending):
 global sorted_gui
 sorted_gui=0;u.mem_write(panel,bytes(0x3000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(panel,vtable);m.wq(vtable+0x180,0x1408d7a60);m.wq(vtable+0x148,m.stop+0x100)
 for i,n in enumerate(order):m.wi(panel+0x4dc+i*4,n)
 for i,n in enumerate(directions):m.wi(panel+0x4a8+i*4,n)
 m.wi(panel+0x23e0,pending);sp=m.stack+0x1fe08;m.wq(sp,m.stop)
 for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RCX,panel),(UC_X86_REG_RDX,column)]:u.reg_write(reg,value)
 u.emu_start(0x1408d1eb0,m.stop,count=2000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(order=order,ascending=directions,column=column,pending=bool(pending),resultOrder=[m.si(panel+0x4dc+i*4) for i in range(6)],resultAscending=[bool(m.si(panel+0x4a8+i*4)) for i in range(6)],guiSortCalls=sorted_gui)
rows=[]
for rotation,bits,column,pending in itertools.product(range(6),range(64),range(6),[0,1]):
 order=list(range(rotation,6))+list(range(rotation));directions=[bool(bits&(1<<i)) for i in range(6)];rows.append(run(order,directions,column,pending))
out=m.root/'backups/animations/native-browser-sort-observations-v1.json';assert not out.exists(),'Retain prior original evidence'
out.write_text(json.dumps(dict(binarySha256=m.digest,harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
