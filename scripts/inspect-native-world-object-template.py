"""Read-only execution of all three original world LoadFromTemplate owners.
Resource ctor/destructor, GFF root, lower data/variable loading, logging and
string allocation/copy are captured boundaries. Proves wrapper ordering and
return semantics, not lower loaders, C++ OOM/unwinding or asset parsing.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,resourcePtr,vtablePtr,referencePtr,tagPtr,rootPtr=[m.heap+n*0x1000 for n in range(1,7)]
owners={'placeable':(0x1404b4650,0x1404b48f1,0x1404b4900),'store':(0x1404fb960,0x1404fbbe8,0x1404fbbf0),'waypoint':(0x140509cf0,0x140509f73,0x140509f80)}

def ctext(ptr):
 raw=bytearray()
 if ptr:
  while len(raw)<4096:
   byte=u.mem_read(ptr+len(raw),1)[0]
   if byte==0:break
   raw.append(byte)
 return raw.decode('cp1252')

def allocate(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr

def owning(ptr,text):
 raw=text.encode('cp1252');data=allocate(len(raw)+1);u.mem_write(data,raw+b'\0');m.wq(ptr,data if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)

def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''

def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x140c10324:assert x==0x118;m.finish(resourcePtr);return
 if at==0x14019e660:
  calls.append(['resource',y,ctext(z),ctext(w)]);m.wq(x,vtablePtr);m.wq(vtablePtr,m.stop+0x10);m.wi(x+0x100,c['loaded']);m.finish(x);return
 if at==m.stop+0x10:assert x==resourcePtr;calls.append(['release',y&0xffffffff]);m.finish();return
 if at==0x1401a0560:calls.append(['root']);m.wi(y,123);m.finish(1);return
 if at in [v[2]for v in owners.values()]:
  assert x==objectPtr and y==resourcePtr and m.si(z)==123
  tag=w if c['kind']=='waypoint' else m.q(rsp+0x28)
  calls.append(['load',c['kind'],stored(objectPtr+0x30),None if tag==0 else stored(tag),None if c['kind']=='waypoint' else w&0xffffffff]);owning(objectPtr+0x30,'authored_template');m.finish(c['lower']);return
 if at==0x14003d8c0:
  text=bytes(u.mem_read(y,z&0xffffffff)).decode('cp1252');owning(x,text)
  if x==objectPtr+0x30:calls.append(['setTemplate',text])
  m.finish(x);return
 if at==0x140497ba0:assert x==objectPtr and y==resourcePtr and m.si(z)==123;calls.append(['variables',stored(objectPtr+0x30)]);m.finish(c.get('variables',0));return
 if at==0x14016afb0:owning(x,ctext(y).replace('%s',ctext(z)));m.finish(x);return
 if at==0x140115890:calls.append(['warning',ctext(m.q(rsp+0x38))]);m.finish();return
 if at==0x140c10368:m.finish(allocate(x));return
 if at in [0x140c10360,0x140c10370]:m.finish();return
 if at==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if not any(lo<=at<hi for lo,hi,_ in owners.values()):raise AssertionError(f'Uncaptured world template dependency {at:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,cursor,calls
 c=case;cursor=0x10000;calls=[];u.mem_write(m.heap,bytes(0x100000));owning(objectPtr+0x30,'previous_template');u.mem_write(referencePtr,c['reference'].encode('cp1252')+b'\0')
 if c['tag'] is not None:owning(tagPtr,c['tag'])
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[objectPtr,referencePtr,tagPtr if c['tag'] is not None else 0]):u.reg_write(reg,value)
 try:u.emu_start(owners[c['kind']][0],m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,template=stored(objectPtr+0x30),calls=calls)

rows=[]
for kind,loaded,lower,reference,tag in itertools.product(owners,[0,1,2,-1],[0,1,-7],['','MiXeD','abcdefghijklmnopq','AbC\0tail','é€Case'],[None,'','Override','a\0tail']):rows.append(run(dict(kind=kind,loaded=loaded,lower=lower,reference=reference,tag=tag)))
out=m.root/'backups/animations/native-world-object-template-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
