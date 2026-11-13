"""Execute unchanged creature hover-caption80b240 instructions. Heap, string
copy/concatenation, disclosed full name, active damage table/TLK and final popup
publication are captured providers. This records source colors and text-bubble
override order, not native text shaping, fonts, GUI pixels or server disclosure.
No game process, private profile, GPU or network connection is used.
"""
import importlib.util,itertools,json,re,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,app,rules,arrays,table=[m.heap+n*0x1000 for n in range(1,7)]
def allocate(size):
 global cursor
 assert 0<size<65536
 p=m.heap+cursor;cursor+=(size+31)&~15;assert cursor<0xff000
 u.mem_write(p,bytes(size));return p
def cstring(p):
 if not p:return b''
 raw=bytearray()
 while len(raw)<65536:
  b=bytes(u.mem_read(p+len(raw),1))
  if b==b'\0':return bytes(raw)
  raw.extend(b)
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
 if a==0x1407f3f00:put(y,'Native Creature');m.finish(y);return
 if a==0x1406ac1a0:m.finish(0);return
 if a==0x1401a7010:
  assert string(z)==b'STRING_REF'
  m.wi(w,6409+(y&255));m.finish(1);return
 if a==0x1401994d0:put(y,'D'+str(z&0xffffffff));m.finish(y);return
 if a==0x140766450:
  outputs.append(dict(raw=string(y).decode('cp1252'),bytes=list(string(y)),force=z&0xffffffff));m.finish();return
 if not 0x14080b240<=a<=0x14080bb06:raise AssertionError(f'Uncaptured original caption dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(reaction,damage,override):
 global cursor,outputs
 cursor=0x10000;outputs=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(actor+0x3b0,stats);u.mem_write(actor+0x388,bytes([reaction]));u.mem_write(stats+0x8e,bytes([damage]));m.wi(actor+0x124,override);put(actor+0x128,'<c\xff\x01\x01>Override</c>')
 m.wq(0x1412df970,app);m.wq(app,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,arrays);m.wq(arrays+0x238,table)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,actor)
 try:u.emu_start(0x14080b240,m.stop,count=100000)
 except Exception as error:raise RuntimeError(dict(reaction=reaction,damage=damage,override=override,rip=hex(u.reg_read(UC_X86_REG_RIP)))) from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop and len(outputs)==1
 return dict(reaction=reaction,damage=damage,override=override,output=outputs[0])
rows=[run(*case) for case in itertools.product([0,1,2,3,255],list(range(7))+[255],range(5))]
name=next((arg.split('=',1)[1] for arg in sys.argv[1:] if arg.startswith('--report=')),'native-nameplate-caption-v1.json')
assert re.fullmatch(r'native-nameplate-caption-[a-z0-9-]+\.json',name)
out=m.root/'backups/animations'/name;assert not out.exists(),'Preserve prior evidence'
out.write_text(json.dumps(dict(target=m.digest,entry='0x14080b240',scope=__doc__,rows=rows),indent=2)+'\n')
print(json.dumps(dict(output=str(out),cases=len(rows),sample=rows[0])))
