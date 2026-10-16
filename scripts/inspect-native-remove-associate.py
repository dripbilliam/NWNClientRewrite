"""Original RemoveAssociate1403d6e10. Capture lookup/faction/list mutation,
type/master setters and GUI/feedback boundaries. Native branch order and writes
execute, including possession7/8's exceptional retained list and GUI state.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,target,statsA,statsT,app,server,internal,manager,faction,default,linked,client,sheet,inventory,message=[m.heap+n*0x1000 for n in range(1,16)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14055b810:calls.append(['message']);m.finish(message if c.get('message',True) else 0)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(target if c.get('exists',True) else 0)
 elif a==0x140357900:calls.append(['faction',y&0xffffffff]);m.finish(faction if c.get('faction',True) else 0)
 elif a==0x1404ad6b0:calls.append(['member',1 if x==default else 7,y&0xffffffff,z]);m.finish()
 elif a==0x140c10324:m.finish(message)
 elif a==0x1402da770:m.finish()
 elif a==0x1403a2480:calls.append(['feedback',y,100]);m.finish()
 elif a==0x1400b5450:
  if y in ids:ids.remove(y)
  m.finish()
 elif a==0x1403a2cd0:calls.append(['type',y&65535]);u.mem_write(target+0x908,struct.pack('<H',y&65535));m.wi(target+0x8fc,0x7f000000);m.finish()
 elif a==0x1403a34b0:calls.append(['master',y&0xffffffff]);m.wi(target+0x8fc,y);m.finish()
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(client if c.get('client',True) else 0)
 elif a==0x1404be500:calls.append(['display',y&0xffffffff]);m.finish()
 elif a==0x1404d90b0:calls.append(['notPermitted',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1404ccd90:calls.append(['inventoryStatus',z,w&0xffffffff]);m.finish()
 elif a==0x1404be9a0:calls.append(['inventoryOpen',y,z]);m.wi(inventory+8,y);m.finish()
 elif not 0x1403d6e10<=a<0x1403d70ec:raise AssertionError(f'Uncaptured remove associate dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,ids
 c=case;calls=[];ids=list(c.get('ids') or []);u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(server+8,internal);m.wq(internal+0x100b0,manager);m.wq(manager+8,default)
 m.wi(actor+8,99);m.wi(target+8,100);m.wq(actor+0xad0,statsA);m.wi(statsA+0xc4,7);m.wq(target+0xad0,statsT);m.wi(statsT+0xc8,9);m.wi(statsT+0xcc,11);m.wi(actor+0x914,17);u.mem_write(target+0x908,struct.pack('<H',c.get('type',4)));m.wi(target+0x8fc,99);m.wi(target+0x540,c.get('open',0))
 if c.get('ids') is not None:m.wq(actor+0x900,linked)
 m.wi(client+0x48,99);m.wq(client+0x90,sheet if c.get('sheet',True) else 0);m.wq(client+0xa0,inventory);m.wi(inventory+8,c.get('inventoryOpen',0));m.wi(inventory+0x10,c.get('inventoryOwner',100))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,100)
 u.emu_start(0x1403d6e10,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,ids=ids,type=int.from_bytes(u.mem_read(target+0x908,2),'little'),master=m.si(target+0x8fc)&0xffffffff,original=m.si(statsT+0xcc),field914=m.si(actor+0x914),inventoryOpen=m.si(inventory+8))
rows=[run(dict(type=type,ids=ids,faction=faction,exists=exists)) for type,ids,faction,exists in itertools.product(range(10),[None,[],[100],[100,101,100]],[False,True],[False,True])]
rows += [run(dict(type=type,ids=[100],open=opened,client=client,sheet=sheet,message=message,inventoryOpen=invOpen,inventoryOwner=invOwner)) for type,opened,client,sheet,message,invOpen,invOwner in itertools.product([4,5,7],[0,1],[False,True],[False,True],[False,True],[0,1],[100,101])]
out=m.root/'backups/animations/native-remove-associate-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
