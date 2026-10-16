"""Full original creature template397dd0..398162. Resource/root/stat read,
feat bonuses, script/item/spell/variable reads, AsTAG, string assignment,
postprocess and spell-use updates are captured lower boundaries. Validates
complete wrapper order, flags, retained/overridden tag and return/resource
cleanup; not the lower data owners, OOM or C++ exception unwinding.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,resourcePtr,referencePtr,tagPtr,statsPtr,vtablePtr=[m.heap+n*0x2000 for n in range(1,7)]
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr
def ctext(ptr):
 raw=bytearray()
 while ptr and len(raw)<4096:
  b=u.mem_read(ptr+len(raw),1)[0]
  if not b:break
  raw.append(b)
 return raw.decode('cp1252')
def owning(ptr,text):
 raw=text.encode('cp1252');data=alloc(len(raw)+1);u.mem_write(data,raw+b'\0');m.wq(ptr,data if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)
def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x140c10324:assert x==0x118;m.finish(resourcePtr);return
 if at==0x14019e660:
  calls.append(['resource',y&0xffffffff,ctext(z),ctext(w)]);m.wq(x,vtablePtr);m.wq(vtablePtr,m.stop+0x10);m.wi(x+0x100,c['loaded']);m.finish(x);return
 if at==m.stop+0x10:assert x==resourcePtr;calls.append(['release',y&0xffffffff]);m.finish();return
 if at==0x1401a0560:calls.append(['root']);m.wi(y,123);m.finish(0);return
 if at==0x14040f7f0:
  assert x==statsPtr and y==resourcePtr and m.si(z)==123 and w==objectPtr+0xa60;calls.append(['readStats',m.si(rsp+0x28),m.si(rsp+0x30),m.si(rsp+0x38),m.si(rsp+0x40)]);owning(objectPtr+0x20,'authored');m.finish(c['statsResult']);return
 if at==0x1403f2110:assert x==statsPtr and y==statsPtr;calls.append(['featBonuses',z&0xffffffff]);m.finish();return
 if at in [0x14039cb00,0x14039c170,0x14040f3e0,0x140497ba0]:
  assert x==(statsPtr if at==0x14040f3e0 else objectPtr) and y==resourcePtr and m.si(z)==123
  calls.append(['scripts'] if at==0x14039cb00 else ['items',w&0xffffffff,m.si(rsp+0x28)] if at==0x14039c170 else ['spells',w&0xffffffff] if at==0x14040f3e0 else ['variables']);m.finish(c.get('lowerResult',0));return
 if at==0x14016ac40:calls.append(['asTag',stored(x)]);owning(y,'SANITIZED:'+stored(x));m.finish(y);return
 if at==0x14039810f:calls.append(['assignTag',stored(objectPtr+0x20)])
 if at==0x14039b3e0:calls.append(['postProcess',stored(objectPtr+0x20),stored(objectPtr+0x30)]);m.finish();return
 if at==0x1404123b0:assert x==statsPtr;calls.append(['updateSpellUses',y&255]);m.finish();return
 if at==0x14003d8c0:
  value=bytes(u.mem_read(y,z&0xffffffff)).decode('cp1252');owning(x,value)
  if x==objectPtr+0x30:calls.append(['setTemplate',value])
  m.finish(x);return
 if at==0x14016afb0:owning(x,ctext(y).replace('%s',ctext(z)));m.finish(x);return
 if at==0x140115890:calls.append(['warning',ctext(m.q(rsp+0x38))]);m.finish();return
 if at==0x140c10368:m.finish(alloc(x));return
 if at==0x140c10370:m.finish();return
 if at==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if not 0x140397dd0<=at<0x140398163:raise AssertionError(f'Uncaptured creature template dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor
 c=case;calls=[];cursor=0x20000;u.mem_write(m.heap,bytes(0x100000));m.wq(objectPtr+0xad0,statsPtr);owning(objectPtr+0x30,'previous');u.mem_write(referencePtr,c['reference'].encode('cp1252')+b'\0')
 if c['tag'] is not None:owning(tagPtr,c['tag'])
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[objectPtr,referencePtr,tagPtr if c['tag'] is not None else 0]):u.reg_write(reg,value)
 try:u.emu_start(0x140397dd0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls)
rows=[run(dict(loaded=loaded,statsResult=stats,reference=ref,tag=tag,lowerResult=-7))for loaded,stats,ref,tag in itertools.product([0,1,2],[0,1,-1],['','MiXeD','a\0tail'],[None,'','Override','a\0tail','\0tail'])]
out=m.root/'backups/animations/native-creature-template-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
