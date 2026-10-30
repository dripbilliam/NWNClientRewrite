"""Execute original modern Internet row admission8c6c20 through its filter
branches, GetGameFilters113e80, Find16aea0 and substring routinec422bc unchanged.
Allocation/free, byte copying/string ownership and app-manager lookup are captured
helper boundaries. Stop before constructing GUI rows. No original process,
configuration write, network, rendering or legacy enumeration path is exercised.
"""
import hashlib, importlib.util, itertools, json, struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('filter_coordinator',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
app,vtable,connection,owner=[m.heap+x for x in [0x1000,0x2000,0x3000,0x4000]]
ranges=[(0x1408c6c20,0x1408c6e00),(0x140113e80,0x140113ed0),(0x14016aea0,0x14016af06),(0x140c422bc,0x140c424bc)]

def allocate(raw=b''):
 global cursor
 p=cursor;cursor+=(len(raw)+64+15)&~15;assert cursor<m.heap+0x100000
 u.mem_write(p,raw+b'\0'+bytes(32));return p

def hook(u,a,n,_):
 global admitted
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a in [0x1408c6df7,0x1408c6e00]:admitted=a==0x1408c6e00;u.emu_stop();return
 if a==m.stop+0x100:m.finish(connection);return
 if a==0x14003d8c0:
  m.wq(x,allocate(bytes(u.mem_read(y,z))));m.wi(x+8,z);m.wi(x+12,z+1);m.finish(x);return
 if a==0x140c10370:m.finish();return
 if a==0x140c10368:m.finish(allocate(bytes(x)));return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured filter dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(flags,module,needle,players,maximum,password,local_vault):
 global cursor,admitted
 cursor=m.heap+0x10000;admitted=None
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,app);m.wq(app,app+0x100);m.wq(app+0x100,vtable);m.wq(vtable+0x60,m.stop+0x100)
 m.wi(connection+0x28,flags);m.wq(connection+0x30,allocate(needle));m.wi(connection+0x38,len(needle))
 sp=m.stack+0x1fe08;m.wq(sp,m.stop)
 for offset,value in [(0x28,players),(0x30,maximum),(0x50,0),(0x58,password),(0xa8,local_vault)]:m.wi(sp+offset,value)
 for reg,value in [(UC_X86_REG_RSP,sp),(UC_X86_REG_RCX,owner),(UC_X86_REG_RDX,0),(UC_X86_REG_R8,0),(UC_X86_REG_R9,allocate(module))]:u.reg_write(reg,value)
 u.emu_start(0x1408c6c20,m.stop,count=10000);assert admitted is not None
 return dict(flags=flags,module=module.decode('cp1252'),needle=needle.decode('cp1252'),players=players,maximum=maximum,password=bool(password),localVault=bool(local_vault),admitted=admitted)

rows=[]
modules=[(b'Prelude',b''),(b'Prelude',b'Pre'),(b'Prelude',b'pre'),(b'Prelude',b'lud'),(b'Prelude',b'Prelude '),(b'Prelude',b'.*'),('Cit\u00e9'.encode('cp1252'),'Cit\u00e9'.encode('cp1252'))]
for low,advanced,pair,counts,password,vault in itertools.product(range(8),range(4),modules,[(0,0),(0,6),(2,6),(6,6),(7,6)],[0,1],[0,1]):
 module,needle=pair;flags=low|((advanced&1)<<3)|((advanced&2)<<3)|(1024 if needle else 0)
 rows.append(run(flags,module,needle,*counts,password,vault))
out=m.root/'backups/animations/native-server-filter-observations-v1.json'
assert not out.exists(),'Retain prior original evidence'
out.write_text(json.dumps(dict(binarySha256=m.digest,harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),limits=__doc__,rows=rows),indent=2)+'\n')
print(json.dumps(dict(rows=len(rows),output=str(out))))
