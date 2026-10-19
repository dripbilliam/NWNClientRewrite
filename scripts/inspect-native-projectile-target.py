"""Original target setter9873d0, type casts from verified RTTI/vtables, and
successful model-name prefix fragments86e2cb..86e2e0/87168c..871707.
Object lookup, successful model-load gate, allocation/free and CExoString
Init/SubString/concatenation are lower services. Not full loader, scene or wire.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,target,app,node,raw=[m.heap+n*0x1000 for n in range(1,6)]
def ui(p):return m.si(p)&0xffffffff
def text(p):return bytes(u.mem_read(p,512)).split(b'\0')[0].decode('latin1')if p else ''
def get(p):return bytes(u.mem_read(m.q(p),ui(p+8))).decode('latin1')if m.q(p)else ''
def allocate(n):
 global allocated
 p=m.heap+0x10000+allocated*0x400;allocated+=1;assert n<=0x400;return p
def put(p,s):
 b=s.encode('latin1');q=allocate(len(b)+1);u.mem_write(q,b+b'\0');m.wq(p,q);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
rtti=[]
for vt,name in [(0x140e474e8,'CNWCCreature'),(0x140e53950,'CNWCPlaceable'),(0x140e52f68,'CNWCDoor')]:
 col=m.q(vt-8);descriptor=m.base+ui(col+12);assert ui(col)==1 and ui(col+4)==0 and text(descriptor+16)=='.?AV'+name+'@@'
 rtti.append(dict(name=name,vtable=hex(vt),locator=hex(col),placeableCast=hex(m.q(vt+0xa0)),doorCast=hex(m.q(vt+0x28))))
def hook(u,a,n,_):
 if a in [m.stop,0x14086e2e0,0x140871707]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406abb60:calls.append(['object',y&0xffffffff]);m.finish(target if c['kind']else 0)
 elif a==0x140c10368:m.finish(allocate(x))
 elif a==0x140c10370:
  if x==inputBuffer:calls.append(['freeInput'])
  m.finish()
 elif a==0x14003d8c0:
  s=text(y)if z&0xffffffff==0xffffffff else bytes(u.mem_read(y,z&0xffffffff)).decode('latin1');calls.append(['init',s,z&0xffffffff]);put(x,s);m.finish(x)
 elif a==0x14016c710:
  start=z&0xffffffff;count=w&0xffffffff;calls.append(['substring',get(x),start,count]);put(y,get(x)[start:]if count==0xffffffff else get(x)[start:start+count]);m.finish(y)
 elif a==0x14016ab00:
  calls.append(['concat',get(x),get(z)]);put(y,get(x)+get(z));m.finish(y)
 elif not any(lo<=a<hi for lo,hi in [(0x1409873d0,0x14098769c),(0x14086e2cb,0x14086e2e0),(0x14087168c,0x140871707),(0x140870b10,0x140870b14),(0x14086df20,0x14086df24),(0x140296220,0x140296230),(0x1402961e0,0x1402961f0)]):raise AssertionError(f'Uncaptured target dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocated,inputBuffer
 c=case;calls=[];allocated=0;inputBuffer=-1;u.mem_write(m.heap,bytes(0x90000));rsp=m.stack+0x1fe08;rbp=rsp-0x200;u.mem_write(rsp-0x1000,bytes(0x1100));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rbp)
 kind=c['kind'];m.wq(0x1412df970,app);m.wq(app,app)
 vt={5:0x140e474e8,9:0x140e53950,10:0x140e52f68}.get(kind,0x140e474e8);m.wq(target,vt)
 if c['model']and kind in [9,10]:
  u.mem_write(raw,c['name'].encode('latin1')+b'\0')
  if kind==9:
   u.reg_write(UC_X86_REG_RDI,target);u.reg_write(UC_X86_REG_RSI,raw);u.reg_write(UC_X86_REG_R13,0);start=0x14087168c
  else:u.reg_write(UC_X86_REG_RBX,target);u.reg_write(UC_X86_REG_RSI,raw);start=0x14086e2cb
  u.emu_start(start,m.stop,count=1000)
 prefix=get(target+(0x1e0 if kind==9 else 0x1c8))if kind in [9,10]else ''
 prefixCalls=calls;calls=[];put(actor+0x1a0,'old');put(node,c['node']);inputBuffer=m.q(node)
 m.wi(actor+0x198,123);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,c['targetId']);u.reg_write(UC_X86_REG_R8,node)
 try:u.emu_start(0x1409873d0,m.stop,count=1500)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,prefix=prefix,prefixCalls=prefixCalls,calls=calls,targetId=ui(actor+0x198),impactNode=get(actor+0x1a0),inputCleared=bytes(u.mem_read(node,16))==bytes(16))
rows=[run(dict(kind=kind,name=name,model=model,node=nodeName,targetId=id))for kind,name,model,nodeName,id in itertools.product([0,5,9,10],['','plc_a01','plc_ABC','x','abcd','prefix_custom_01','PLc_MiXeD','plc_\xe9'],[0,1],['','hand','custom\0tail','\xe9'],[0,0x80000063,0x7f000000])]
out=m.root/'backups/animations/native-projectile-target-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rtti=rtti,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
