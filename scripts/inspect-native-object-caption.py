"""Execute original item/placeable hover captions and door/trigger no-op slots.
RTTI/vtable identity, color bytes and override composition come from the pinned
nwmain image. Heap/string services, item display name and final popup publication
are captured providers. This is not GUI pixels, font shaping, hover admission,
inventory tooltip policy or authoritative server disclosure. No live process,
GPU, credentials or network connection is used.
"""
import importlib.util,itertools,json,re,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor=m.heap+0x1000
entries={'item':(6,0x14083f230,0x14083f4a7),'placeable':(9,0x140871b60,0x140871e11),'door':(10,0x140766a60,0x140766a63),'trigger':(7,0x140766a60,0x140766a63)}

def allocate(size):
 global cursor
 assert 0<size<65536
 p=m.heap+cursor;cursor+=(size+31)&~15;assert cursor<0xff000
 u.mem_write(p,bytes(size));return p

def cstring(p):
 if not p:return b''
 raw=bytearray()
 while len(raw)<65536:
  value=bytes(u.mem_read(p+len(raw),1))
  if value==b'\0':return bytes(raw)
  raw.extend(value)
 raise AssertionError('Unbounded fixture string')

def string(p):
 size=m.si(p+8)&0xffffffff;assert size<65536
 return bytes(u.mem_read(m.q(p),size)) if size and m.q(p) else b''

def put(p,value):
 raw=value.encode('cp1252') if isinstance(value,str) else value
 q=allocate(len(raw)+1);u.mem_write(q,raw+b'\0');m.wq(p,q);m.wi(p+8,len(raw));m.wi(p+12,len(raw)+1);return p

def hook(u,a,n,_):
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop:u.emu_stop();return
 if a in [0x140c10324,0x140c10368]:m.finish(allocate(x));return
 if a in [0x140c10370,0x140c10410]:m.finish();return
 if a==0x14003d8c0:put(x,cstring(y));m.finish(x);return
 if a==0x14016ab00:put(y,string(x)+string(z));m.finish(y);return
 if a==0x14083d8a0:
  assert x==actor-0x48 and z==1
  put(y,case['name']);m.finish(y);return
 if a==0x140766450:
  assert x==actor
  outputs.append(dict(raw=string(y).decode('cp1252'),bytes=list(string(y)),force=z&0xffffffff));m.finish();return
 if not start<=a<end:raise AssertionError(f'Uncaptured original object-caption dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(kind,flag,mode,name,custom):
 global cursor,outputs,start,end,case
 cursor=0x10000;outputs=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 object_type,start,end=entries[kind];case=dict(kind=kind,objectType=object_type,redFlag=flag,mode=mode,name=name,custom=custom)
 m.wi(actor+0x1a0,flag);m.wi(actor+0x124,mode);put(actor+0x128,custom);put(actor+0x170,name)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,actor)
 try:u.emu_start(start,m.stop,count=20000)
 except Exception as error:raise RuntimeError(dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)))) from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop and len(outputs)==(1 if kind in ['item','placeable'] else 0)
 return dict(**case,output=outputs[0] if outputs else None)

def identity(kind,vtable,offset):
 col=m.q(vtable-8);sig=m.si(col);td=m.si(col+12)&0xffffffff
 assert sig==1 and m.si(col+4)==offset
 name=cstring(m.base+td+16).decode('ascii');assert name=='.?AVCNWC'+kind+'@@'
 entry=m.q(vtable+0x220)
 return dict(className=name,vtable=hex(vtable),subobjectOffset=offset,slot='0x220',entry=hex(entry))

identities=[identity('Item',0x140e4cec0,0x48),identity('Placeable',0x140e53950,0),identity('Door',0x140e52f68,0),identity('Trigger',0x140e533f8,0)]
assert [row['entry'] for row in identities]==[hex(entries[kind][1]) for kind in entries]
names=['Native Object','[b]Literal[/b]\nSecond'];customs=['<c\x01\xff\x01>Override</c>','','[b]Custom[/b]\nLine']
rows=[run(kind,flag,mode,name,custom) for kind in ['item','placeable'] for flag in ([0] if kind=='item' else [0,1]) for mode,name,custom in itertools.product(range(5),names,customs)]
rows.extend(run(kind,0,1,'Native Object','Override') for kind in ['door','trigger'])
name=next((arg.split('=',1)[1] for arg in sys.argv[1:] if arg.startswith('--report=')),'native-object-caption-v1.json')
assert re.fullmatch(r'native-object-caption-[a-z0-9-]+\.json',name)
out=m.root/'backups/animations'/name;assert not out.exists(),'Preserve prior evidence'
out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,identities=identities,rows=rows),indent=2)+'\n')
print(json.dumps(dict(output=str(out),cases=len(rows),identities=identities,sample=rows[0])))
