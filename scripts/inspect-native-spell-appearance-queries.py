"""Full original appearance/size/tail VM wrappers and SetMode owner. VM pop/
push, object lookup, type views, GetDetectMode and ToggleMode are captured lower
boundaries. Tail import executes its verified ReadStats block, with decoded GFF
read success/default providers. Not raw malformed GFF, stats allocator, mutation
lifecycle or complete ToggleMode/SetActivity parity. Read-only synthetic cases.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,stats,manager,app,vt=[m.heap+n*0x1000 for n in range(1,6)]
ranges=[(0x14051ec20,0x14051ecd2),(0x1405213f0,0x140521467),(0x140521470,0x140521501),(0x1403a3510,0x1403a3664),(0x1404103b0,0x140410416),(0x140540ee0,0x140540f50),(0x140522b30,0x140522bb5),(0x140531050,0x14053110a)]

def hook(u,a,n,_):
 global pushed
 if a in [m.stop,0x140410416]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286160:m.wi(y,123);m.finish(c.get('pop',1))
 elif a==0x140286110:m.wi(y,c['requested']);m.finish(c.get('intPop',1))
 elif a==0x140286410:pushed=y&0xffffffff;m.finish(c.get('push',1))
 elif a==0x140c10370:m.finish()
 elif a==0x14003d8c0:
  value=bytes(u.mem_read(y,z));ptr=m.heap+0x80000;u.mem_write(ptr,value+b'\0');m.wq(x,ptr);m.wi(x+8,z);m.finish(x)
 elif a==0x140286550:
  size=m.si(y+8);ptr=m.q(y);pushed=bytes(u.mem_read(ptr,size)).decode('cp1252')if ptr else'';m.finish(c.get('push',1))
 elif a==0x14055b4c0:m.finish(actor if c.get('type')is not None else 0)
 elif a==0x14055b3d0:m.finish(actor if c.get('type')==5 else 0)
 elif a==m.stop+0x10:m.finish(actor if c.get('type')==5 else 0)
 elif a==m.stop+0x20:m.finish(actor)
 elif a==m.stop+0x30:m.finish(actor if c.get('type')==6 else 0)
 elif a==0x140390490:calls.append(['detect']);m.finish(c['detect'])
 elif a==0x1403a52b0:calls.append(['toggle',y&255]);m.finish()
 elif a in [0x1401a1510,0x1401a0ee0]:
  key='new'if a==0x1401a1510 else'old';present=c[key]is not None;m.wi(w,int(present));value=c[key]if present else m.si(rsp+0x28);m.finish(value&255 if key=='old'else value)
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected appearance query dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def setup(case):
 global c,calls,pushed
 c=case;calls=[];pushed=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager+8,app)
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(vt+0x98,m.stop+0x20);m.wq(vt+0x30,m.stop+0x20);m.wq(vt+0x70,m.stop+0x30);u.mem_write(actor+0xc,bytes([c.get('type')or 0]));m.wq(actor+0xad0,stats if c.get('stats',1)else 0)
 value=c.get('value',0);u.mem_write(actor+0xa74,(value&65535).to_bytes(2,'little'));u.mem_write(actor+0x32c,(value&65535).to_bytes(2,'little'));m.wi(actor+0x3f8,value);m.wi(actor+0x718,value);m.wi(stats+0xe18,value)
 u.mem_write(actor+0x6ef,bytes([c.get('mode',0)]));u.mem_write(actor+0x6ed,bytes([c.get('stealth',0)]))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);return rsp

def run(address):
 try:u.emu_start(address,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise

queries=[]
for command,typ,value,hasstats in itertools.product(['appearance','size','tail'],[None,5,6,9,10],[-1,0,65537,0x80000001],[0,1]):
 case=dict(command=command,type=typ,value=value,stats=hasstats);setup(case);run(dict(appearance=0x14051ec20,size=0x1405213f0,tail=0x140521470)[command]);queries.append(dict(case=case,pushed=pushed,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
for command,pop,push in itertools.product(['appearance','size','tail'],[0,1],[0,1]):
 case=dict(command=command,type=5,value=7,stats=1,pop=pop,push=push);setup(case);run(dict(appearance=0x14051ec20,size=0x1405213f0,tail=0x140521470)[command]);queries.append(dict(case=case,pushed=pushed,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
modes=[]
for requested,mode,stealth,detect,value in itertools.product(list(range(16))+[-1,256,257],[0,1,5,11,255],[0,1,2],[0,1,2],[-1,0,1,2]):
 case=dict(requested=requested,mode=mode,stealth=stealth,detect=detect,value=value);setup(case);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,requested&0xffffffff);u.reg_write(UC_X86_REG_R8,value&0xffffffff);run(0x1403a3510);modes.append(dict(case=case,calls=calls))
imports=[]
for current,new,old in itertools.product([0,99,-1],[None,0,65537,0x80000001],[None,0,257]):
 case=dict(current=current,new=new,old=old);rsp=setup(case);m.wi(stats+0xe18,current);u.reg_write(UC_X86_REG_R14,stats);u.reg_write(UC_X86_REG_RSI,app);u.reg_write(UC_X86_REG_R12,app+100);run(0x1404103b0);imports.append(dict(case=case,result=m.si(stats+0xe18)))
droppable=[]
for typ,previous,requested in itertools.product([None,5,6,9,10],[-1,0,1,256],[-1,0,1,2,0x80000001]):
 case=dict(type=typ,previous=previous,requested=requested);setup(case);m.wi(actor+0x448,previous);run(0x140540ee0);after=m.si(actor+0x448);run_result=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);run(0x140522b30);droppable.append(dict(case=case,after=after,pushed=pushed,result=run_result))
subraces=[]
for typ,hasstats,text in itertools.product([None,5,6,9,10],[0,1],['','Dark Elf','caf\u00e9','Winter\0tail']):
 case=dict(type=typ,stats=hasstats,text=text);setup(case);value=text.encode('cp1252');ptr=m.heap+0x90000;u.mem_write(ptr,value+b'\0');m.wq(stats+0xd28,ptr if value else 0);m.wi(stats+0xd30,len(value));run(0x140531050);subraces.append(dict(case=case,pushed=pushed,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
output=m.root/'backups/animations/native-spell-appearance-query-observations.json';output.write_text(json.dumps(dict(binarySha256=m.digest,queries=queries,modes=modes,imports=imports,droppable=droppable,subraces=subraces),indent=2));print(json.dumps(dict(output=str(output),queries=len(queries),modes=len(modes),imports=len(imports),droppable=len(droppable),subraces=len(subraces))))
