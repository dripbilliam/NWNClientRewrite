"""Execute original8d0c90 profile validation,16c4f0 byte sanitization and
16bcb0 Left with unchanged executable instructions. Allocation/string copying,
edit publication, notice construction and final acceptance are captured at
their external ownership boundaries. No original process or network is used.
This does not execute profile config persistence or certify visible controls.
"""
import hashlib,importlib.util,json,struct
from pathlib import Path
source=Path(__file__).with_name('inspect-native-intratile-coordinator.py')
spec=importlib.util.spec_from_file_location('profile_coordinator',source)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel=m.heap+0x1000;gob=m.heap+0x3000;vtable=m.heap+0x4000
ranges=[(0x1408d0c90,0x1408d0ffb),(0x14016c4f0,0x14016c70d),(0x14016bcb0,0x14016bd6c),(0x140c43180,0x140c43209),(0x140c10410,0x140c10431)]
def allocate(raw=b''):
 global cursor
 p=cursor;cursor+=(len(raw)+32+15)&~15;assert cursor<m.heap+0x100000
 u.mem_write(p,raw+b'\0');return p
def string(p,raw):
 m.wq(p,allocate(raw));m.wi(p+8,len(raw));m.wi(p+12,len(raw)+1)
def bytestring(p):
 return bytes(u.mem_read(m.q(p),m.si(p+8))) if m.q(p) else b''
def cstring(p):
 raw=b''
 while p and len(raw)<4096:
  b=bytes(u.mem_read(p+len(raw),1))
  if b==b'\0':break
  raw+=b
 return raw
def hook(u,a,n,_):
 global published,notice,accepted
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop:u.emu_stop();return
 if a==0x1401e93b0:string(y,case);m.finish(y);return
 if a==0x14003d8c0:string(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x1401881e0:string(x,bytestring(y));m.finish(x);return
 if a==0x140c10370:m.finish();return
 if a==0x140c10324:m.finish(allocate(bytes(x)));return
 if a==m.stop+0x100:published=cstring(y);m.finish();return
 if a==0x1402023d0:published=bytestring(y);m.finish();return
 if a==0x1401ff7d0:notice=y&0xffffffff;m.finish(x);return
 if a==0x1401fbe40:m.finish();return
 if a==0x1408cdb20:accepted=y==0x17;m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured original profile dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(raw):
 global case,published,notice,accepted,cursor
 case=raw;published=None;notice=0;accepted=False;cursor=m.heap+0x10000
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(panel+0x198,gob);m.wq(gob,vtable);m.wq(vtable+0xd0,m.stop+0x100)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop)
 u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,panel)
 u.emu_start(0x1408d0c90,m.stop,count=300000)
 assert u.reg_read(UC_X86_REG_RIP)==m.stop and published is not None
 return dict(input=raw.decode('cp1252',errors='replace'),inputBytes=list(raw),name=published.decode('cp1252'),nameBytes=list(published),notice=notice,accepted=accepted)
values=[b'',b'Scary Bill',b' . .Name',b'!!!',b'Name!',b'User@server',b'A'*31,b'A'*32,b'A'*33,b'A'*64,b'!'+b'A'*40,b'  '+b'A'*40,b'A\tB',b'A\nB',b'A B ',b"O'Brien, Jr."]
values += [bytes([b]) for b in range(1,256)]
values += [b'A'+bytes([b])+b'Z' for b in range(1,256)]
values += [bytes([b])+b'A' for b in range(1,256)]
rows=[run(raw) for raw in values]
out=m.root/'backups/animations/native-player-profile-observations-v1.json'
assert not out.exists(),'Retain original evidence'
out.write_text(json.dumps(dict(binarySha256=m.digest,harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),limits=__doc__,rows=rows),indent=2)+'\n')
print(json.dumps(dict(rows=len(rows),output=str(out))))
