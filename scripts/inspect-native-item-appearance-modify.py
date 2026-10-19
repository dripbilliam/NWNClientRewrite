"""Complete CopyItemAndModify wrapper, both complete base-item resource-reference
owners and original per-part palette setter. Capture VM pop/push, allocation/
item-copy, base rows, warning/2DA/resource catalogs, armor/weight, acquisition/
area/possession, CResRef assignment and CRT formatting/security-cookie boundaries.
Original validation, special categories, numeric narrowing/field writes, reference
selection, failures and placement execute; lower item ownership is separately proven.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
command,vm,app,src,dst,base,rules,tables,partTable,cloak,target,vt,area,existing,buffer=[m.heap+i*0x1000 for i in range(15)]
ranges=[(0x1405128f0,0x1405134a7),(0x14029dc80,0x14029dd32),(0x14029dd90,0x14029de42),(0x1402a0ff0,0x1402a1066)]
def cstring(p):
 out=bytearray()
 if not p:return b''
 for i in range(256):
  b=u.mem_read(p+i,1)[0]
  if b==0:break
  out.append(b)
 return bytes(out)
def res(p,value):
 b=value.encode('latin1')[:16];u.mem_write(p,b+bytes(17-len(b)));return p
def ident(p):return m.si(p+(8 if p==target else 0x50))&0xffffffff if p else 0
def snapshot(p):
 return dict(modelParts=list(struct.unpack('<3H',u.mem_read(p+0x39c,6))),armorParts=list(struct.unpack('<19H',u.mem_read(p+0x3a2,38))),colors=list(u.mem_read(p+8,6)),partColors=[list(u.mem_read(m.q(p+16+i*8),19))if m.q(p+16+i*8)else None for i in range(6)],armor=m.si(p+0x35c),weight=m.si(p+0x45c))
def hook(u,a,n,_):
 global popIndex,output,cursor
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in[0x14029dc80,0x14029dd90]:trace.append(['icon'if a==0x14029dc80 else'model',z&255,w&65535,m.si(rsp+0x28)&255]);return
 if a==0x1402a0ff0:trace.append(['partColor',y&255,z&255,w&255]);return
 if a in[0x140286160,0x140286110]:
  trace.append(['pop','object'if a==0x140286160 else'int']);ok=popIndex!=c.get('failPop',-1)
  if ok:m.wi(y,args[popIndex])
  popIndex+=1;m.finish(int(ok))
 elif a==0x140286470:output=y&0xffffffff;trace.append(['push',output]);m.finish(c.get('push',1))
 elif a==0x14055b6c0:trace.append(['item',y&0xffffffff]);m.finish(src if c.get('source',True)else 0)
 elif a in[0x140c10324,0x140c10368]:
  if x==0x470:trace.append(['allocate',x]);m.finish(dst)
  else:p=m.heap+0x30000+cursor;cursor+=(x+0xff)&~0xff;m.finish(p)
 elif a==0x140c10370:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x140462e90:trace.append(['construct',y&0xffffffff]);m.finish(dst)
 elif a==0x140466910:
  trace.append(['copy',z&0xffffffff]);
  for off,size in[(8,6),(0x39c,6),(0x3a2,38),(0x35c,4),(0x45c,4)]:u.mem_write(x+off,bytes(u.mem_read(y+off,size)))
  m.finish(c.get('copy',1))
 elif a==0x14029ca00:trace.append(['base',y&0xffffffff]);m.finish(base)
 elif a==0x140115890:trace.append(['warning',m.si(rsp+0x28)]);m.finish()
 elif a==0x140047000:
  fmt=cstring(y).decode('latin1');values=[cstring(z).decode('latin1'),m.si(rsp+0x28)]if '%c'in fmt else[cstring(z).decode('latin1'),w&0xffffffff]
  if '%c'in fmt:values.insert(1,chr(w&255))
  for i,v in enumerate(values):
   if isinstance(v,int)and v>=0x80000000:values[i]=v-0x100000000
  text=fmt%tuple(values);u.mem_write(x,text.encode('latin1')+b'\0');m.finish(len(text))
 elif a==0x14018ded0:m.finish(res(x,cstring(y).decode('latin1')))
 elif a==0x14018de80:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
 elif a==0x14018f590:
  name=cstring(y).decode('latin1');trace.append(['exists',name,z&65535]);m.finish(c.get('fallbackExists',1)if name=='FallbackIcon'else c.get('modelExists',1)if(z&65535)==2002 else c.get('iconExists',1))
 elif a==0x140466500:trace.append(['armor']);m.finish(c.get('computedArmor',17))
 elif a==0x140466660:trace.append(['weight']);m.wi(x+0x45c,c.get('computedWeight',99));m.finish()
 elif a==0x1401a7010:trace.append(['cloakIcon',y&0xffffffff]);m.wi(w,c.get('cloakIcon',3));m.finish(c.get('cloakStatus',1))
 elif a==0x14046c520:trace.append(['possessor',ident(x),y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.wi(x+0x3c8,y);m.finish()
 elif a==0x14055b4c0:trace.append(['object',y&0xffffffff]);m.finish(target if c.get('target',True)else 0)
 elif a==0x140494e80:trace.append(['area','source'if x==src+0x48 else'target']);m.finish(area if c.get('area',True)else 0)
 elif a==0x140464bb0:trace.append(['addArea',ident(x),int(y!=0),m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28),m.si(rsp+0x30)]);m.finish()
 elif a==m.stop+0x10:trace.append(['destroy',ident(x),y&0xffffffff]);m.finish()
 elif m.stop+0x20<=a<=m.stop+0x60:
  cast={m.stop+0x20:'world',m.stop+0x30:'creature',m.stop+0x40:'placeable',m.stop+0x50:'item',m.stop+0x60:'store'}[a];trace.append(['cast',cast]);m.finish(x if(cast=='world'and c.get('world',True)or c.get('kind',5)=={'world':-1,'creature':5,'placeable':9,'item':6,'store':14}[cast])else 0)
 elif a in[0x1403cff30,0x1404b11d0,0x140463e80,0x1404f9ea0]:
  kind={0x1403cff30:5,0x1404b11d0:9,0x140463e80:6,0x1404f9ea0:14}[a];extra=[z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&255,m.si(rsp+0x30)&255,m.si(rsp+0x38),m.si(rsp+0x40)]if kind==5 else[z&0xffffffff,w&255,m.si(rsp+0x28)&255,m.si(rsp+0x30)]if kind!=14 else[z&0xffffffff,w&255,m.si(rsp+0x28)&255];trace.append(['acquire',kind,*extra]);
  if c.get('mutation')=='existing'and kind!=14:m.wq(y,existing)
  m.finish(c.get('acquire',1))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unmapped appearance dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,popIndex,output,cursor,args
 c=case;trace=[];popIndex=0;output=None;cursor=0;u.mem_write(m.heap,bytes(0x80000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df910,vm);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables)
 for p,id in[(src,42),(dst,c.get('id',43)),(target,101),(existing,44)]:m.wq(p,vt);m.wi(p+(8 if p==target else 0x50),id)
 for off,address in[(0,m.stop+0x10),(0x20,m.stop+0x20),(0x60,m.stop+0x30),(0x98,m.stop+0x40),(0x70,m.stop+0x50),(0xd0,m.stop+0x60)]:m.wq(vt+off,address)
 m.wi(src+0x40,c.get('base',22));m.wi(src+0x3c8,c.get('possessor',0x7f000000));m.wi(src+0x35c,4);m.wi(src+0x45c,50);u.mem_write(src+0x39c,struct.pack('<3H',11,22,33));u.mem_write(src+0x3a2,struct.pack('<19H',*range(100,119)));u.mem_write(src+8,bytes(range(6)))
 u.mem_write(base+0x16,bytes([c.get('modelType',2)&255]));u.mem_write(base+0x1e,bytes([c.get('category',0)&255]));m.wi(base+0x84,c.get('genderSpecific',0));u.mem_write(base+0x40,c.get('itemClass','Sword').encode()+b'\0');res(base+0x58,'FallbackIcon');res(base+0x69,'DefaultModel')
 for off in[0x328,0x330,0x338,0x340,0x348,0x350,0x358,0x360,0x368,0x370,0x378,0x380]:m.wq(tables+off,0 if c.get('missingPartTable')else partTable)
 m.wi(partTable+0x50,c.get('rows',12));m.wq(tables+0x1d8,0 if c.get('missingCloakTable')else cloak)
 for i,v in enumerate([1.25,-2.5,3.75]):m.wf(src+0xec+i*4,v);m.wf(target+0xa4+i*4,v*2)
 before=snapshot(src);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c.get('reference'):
  entry=0x14029dc80 if c.get('icon')else 0x14029dd90;registers=[base,buffer,c.get('component',0)&255,c.get('model',0)&65535];m.wi(rsp+0x28,c.get('gender',109)&255)
 else:entry=0x1405128f0;args=[c.get('sourceId',42),c.get('type',4),c.get('index',0),c.get('value',1),c.get('variables',0)];registers=[command,0,c.get('argc',5),0]
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],registers):u.reg_write(r,v)
 try:u.emu_start(entry,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,before=before,after=snapshot(dst),trace=trace,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,reference=cstring(buffer).decode('latin1')if c.get('reference')else None)
cases=[dict(type=t,index=i,value=v)for t,i,v in itertools.product([-1,0,1,2,3,4,5],[-256,0,1,2,3,6,7,18,19,119,1542],[-1,0,1,9,10,175,176,255,65535])]
cases +=[dict(type=3,category=5,value=v)for v in[0,1,255,32768]]
cases +=[dict(type=0,base=80,category=4,modelType=1,value=v,missingCloakTable=missing)for v,missing in itertools.product([0,3,65535],[False,True])]
cases +=[dict(type=t,iconExists=icon,modelExists=model,fallbackExists=fallback)for t,icon,model,fallback in itertools.product([0,2],[0,1],[0,1],[0,1])]
cases +=[dict(type=2,base=b)for b in[19,20,21,25,26,49,64,65,66,101,104]]
cases +=[dict(type=3,index=i,value=v,missingPartTable=missing)for i,v,missing in itertools.product(range(19),[-1,1,12],[False,True])]
cases +=[dict(type=4,possessor=101,kind=k,acquire=a,mutation=mu)for k,a,mu in itertools.product([5,9,6,14,10],[0,1],['keep','existing'])]
cases +=[dict(**d)for d in[dict(argc=4),dict(source=False),dict(sourceId=0x7f000000),dict(copy=0),dict(push=0),dict(variables=-1),dict(possessor=101,target=False),dict(possessor=101,world=False),dict(id=0x80000042),*[dict(failPop=i)for i in range(5)]]]
cases +=[dict(reference=True,icon=icon,modelType=mt,genderSpecific=gs,component=p,model=v,gender=g)for icon,mt,gs,p,v,g in itertools.product([False,True],[0,1,2,3],[0,1],[0,1,2],[0,1,32767,32768,65535,-1],[0,109,255])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-item-appearance-modify-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
