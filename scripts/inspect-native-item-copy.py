"""Complete CopyItem and two complete per-part palette owners. Original field
selection, sequence, repository rejection/construction, conditional property
assignment, effect append growth and palette loops execute. Capture localized/
string assignment, module tags, allocation/repository/variables/property-list,
base effect constructor/CopyEffect, array realloc and visual update boundaries.
Those lower owners and arbitrary script-variable/locale semantics are separate.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);dst,src,app,module,repo,list_,dstlist=[m.heap+i*0x1000 for i in range(7)]
scalars=[0x3c8,0x394,0x388,0x35c,0x444,0x454,0x45c,0x360,0x144,0x458,0x468,0x40,0x448,0x450,0x38c,0x390]
strings=[0x430,0x400,0x410,0x68,0x78];locs=[0x3e0,0x3f0,0x420];ranges=[(0x140466910,0x140466e61),(0x14029dd60,0x14029dd84),(0x1402a0ff0,0x1402a1066)]
def offset(p):return p-dst if dst<=p<dst+0x500 else p-src
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode()if m.q(p)else''
def snapshot(p):
 colors=[]
 for channel in range(6):colors.append(list(u.mem_read(m.q(p+16+channel*8),19))if m.q(p+16+channel*8)else None)
 effects=[m.q(m.q(p+0x198)+i*8)for i in range(m.si(p+0x1a0))];effects=[m.q(e)if m.heap<=e<m.heap+0x100000 else e for e in effects]
 return dict(id=m.si(p+0x50)&0xffffffff,scalars={str(o):m.si(p+o)for o in scalars},bytes=list(u.mem_read(p+0x350,9)),armorParts=list(struct.unpack('<19H',u.mem_read(p+0x3a2,38))),modelParts=list(struct.unpack('<3H',u.mem_read(p+0x39c,6))),colors=list(u.mem_read(p+8,6)),partColors=colors,localized={str(o):m.si(p+o)for o in locs},strings={str(o):text(p+o)for o in strings},properties=[m.si(p+0x370),m.si(p+0x380)],effects=effects)
def allocate(size):
 global cursor
 p=m.heap+0x30000+cursor;cursor+=(size+0xff)&~0xff;return p
def hook(u,a,n,_):
 global ids
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140169600:trace.append(['localized',offset(x),offset(y)]);u.mem_write(x,bytes(u.mem_read(y,16)));m.finish(x)
 elif a==0x14003d8c0:
  value=bytes(u.mem_read(y,z)).decode()if y else'';u.mem_write(x,struct.pack('<QII',y,z,z+1));m.finish(x)
 elif a==0x14055b6e0:m.finish(module)
 elif a in[0x140484bd0,0x14047a930]:trace.append(['removeTag'if a==0x140484bd0 else'addTag',z&0xffffffff,text(y)]);m.finish()
 elif a in[0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif a==0x140462d40:
  trace.append(['repository',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30)]);u.mem_write(x,bytes(24));u.mem_write(x,bytes([z&255,w&255]));m.wi(x+4,m.si(rsp+0x28));m.wq(x+16,list_);m.finish(x)
 elif a==0x140491310:trace.append(['variables']);m.finish()
 elif a==0x140463400:trace.append(['properties',offset(x),m.si(y+8)]);u.mem_write(x,bytes(u.mem_read(y,16)));m.finish(x)
 elif a==0x1404233d0:ids+=1;m.wq(x,100+ids);m.finish(x)
 elif a==0x140423ce0:trace.append(['effect',m.q(x),m.q(y),z]);m.finish()
 elif a==0x140c4f038:
  p=allocate(y)
  if x:u.mem_write(p,bytes(u.mem_read(x,min(y,0x80))))
  m.finish(p)
 elif a==0x14046d140:trace.append(['visual']);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unmapped item copy dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,cursor,ids
 c=case;trace=[];cursor=ids=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app)
 for p,seed in[(dst,1),(src,c.get('seed',2))]:
  m.wi(p+0x50,99 if p==dst else 98)
  for i,o in enumerate(scalars):m.wi(p+o,seed*100+i)
  u.mem_write(p+0x350,bytes((seed+i)&255 for i in range(9)));u.mem_write(p+0x3a2,struct.pack('<19H',*(seed*100+i for i in range(19))));u.mem_write(p+0x39c,struct.pack('<3H',*(seed*10+i for i in range(3))));u.mem_write(p+8,bytes((seed+i)&255 for i in range(6)))
  for i,o in enumerate(locs):m.wi(p+o,seed*1000+i)
  for o in strings:
   value=(''if o==0x68 and c.get('emptyOldTag'if p==dst else'emptyTag')else f'{seed}-{o}').encode();b=allocate(len(value)+1);u.mem_write(b,value+b'\0');m.wq(p+o,b);m.wi(p+o+8,len(value))
  for i in range(6):
   if(c.get('channels',5)if p==src else c.get('destinationChannels',16))>>i&1:
    ptr=allocate(19);u.mem_write(ptr,bytes((seed*10+i+j)&255 for j in range(19)));m.wq(p+16+i*8,ptr)
 for o,n in[(0x370,c.get('active',2)),(0x380,c.get('passive',1))]:m.wi(src+o,n);m.wi(dst+o,3)
 m.wq(src+0x198,list_+0x100);m.wi(src+0x1a0,c.get('effects',2));m.wq(dst+0x198,dstlist);m.wi(dst+0x1a0,1);m.wi(dst+0x1a4,c.get('capacity',1));m.wq(dstlist,77)
 for i in range(c.get('effects',2)):
  ptr=allocate(0x110);m.wq(ptr,200+i);m.wq(list_+0x100+i*8,ptr)
 if c.get('repo',True):m.wq(src+0x3d0,repo);u.mem_write(repo,bytes([7,5]));m.wi(repo+4,35);m.wq(repo+16,list_);m.wi(list_+16,c.get('count',0))
 before=snapshot(dst);source=snapshot(src);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[dst,0 if c.get('nullSource')else src,c.get('copyVars',1)&0xffffffff]):u.reg_write(r,v)
 if c.get('palette'):
  def invoke(entry):
   u.reg_write(UC_X86_REG_RSP,rsp)
   for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[src,c['channel']&255,c['part']&255,c['value']&255]):u.reg_write(r,v)
   u.emu_start(entry,m.stop,count=1000);return u.reg_read(UC_X86_REG_RAX)&255
  prior=invoke(0x14029dd60);invoke(0x1402a0ff0);after=invoke(0x14029dd60)
  return dict(case=c,before=source,after=snapshot(src),prior=prior,value=after)
 try:u.emu_start(0x140466910,m.stop,count=50000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,before=before,source=source,after=snapshot(dst),trace=trace,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
cases=[dict(repo=r,count=n,copyVars=v,active=a,passive=p,effects=e,channels=ch)for r,n,v,a,p,e,ch in itertools.product([False,True],[0,1,-1],[0,1,-1],[0,2],[0,1],[0,2],[0,5,63])]
cases +=[dict(nullSource=True),dict(emptyOldTag=True),dict(emptyTag=True),dict(capacity=16,effects=3)]
rows=[run(c)for c in cases];palettes=[run(dict(palette=True,channel=ch,part=p,value=v,channels=mask))for ch,p,v,mask in itertools.product([0,5,6,255,256,-1],[0,18,19,255,256],[0,37,255,256,-1],[0,63])];out=m.root/'backups/animations/native-item-copy-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,palettes=palettes),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),palettes=len(palettes))))
