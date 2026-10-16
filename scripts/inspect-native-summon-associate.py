"""Original AddAssociate1403d0410 type4 branch. Capture module/lookup, old
unsummon, movement-rate/listen/type/master, list storage and faction boundaries.
Other associate categories and destruction are not covered by this fixture.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,old,target,other,app,server,internal,manager,module,faction,linked,values,stats,statsA=[m.heap+n*0x1000 for n in range(1,15)]
objects={99:actor,100:old,101:target,102:other}
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14055b6e0:calls.append(['module']);m.finish(module)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(0 if y==101 and c.get('missing') else objects.get(y,0))
 elif a==0x1403daee0:calls.append(['unsummon',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x1404160a0:calls.append(['rate',101,y]);m.wi(stats+0xe20,y);m.finish()
 elif a==0x1403d8160:calls.append(['patterns',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x1403a2cd0:calls.append(['type',m.si(x+8)&0xffffffff,y&65535]);u.mem_write(x+0x908,struct.pack('<H',y&65535));m.finish()
 elif a==0x1403a34b0:calls.append(['master',m.si(x+8)&0xffffffff,y&0xffffffff]);m.wi(x+0x8fc,y);m.finish()
 elif a==0x140c10324:m.finish(linked)
 elif a==0x140175070:m.finish(int((y&0xffffffff) in ids))
 elif a==0x14008ae10:ids.append(y&0xffffffff);m.finish()
 elif a==0x140357900:calls.append(['faction',y&0xffffffff]);m.finish(faction if c.get('faction',True) else 0)
 elif a==0x1404ad6b0:calls.append(['addMember',y&0xffffffff,z]);m.finish()
 elif not 0x1403d0410<=a<0x1403d0959:raise AssertionError(f'Uncaptured summon associate dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,ids
 c=case;calls=[];ids=list(c.get('ids') or []);u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(server+8,internal);m.wq(internal+0x100b0,manager)
 for id,obj in objects.items():m.wi(obj+8,id);m.wi(obj+0x8fc,0x7f000000)
 for id,type in [(100,c.get('oldType',4)),(101,c.get('targetType',0)),(102,4)]:u.mem_write(objects[id]+0x908,struct.pack('<H',type))
 m.wq(target+0xad0,stats);m.wi(stats+0xe20,c.get('rate',0));m.wq(actor+0xad0,statsA);m.wi(statsA+0xc4,7)
 if c.get('ids') is not None:
  m.wq(actor+0x900,linked);m.wq(linked,values);m.wi(linked+8,len(ids))
  for i,id in enumerate(ids):m.wi(values+i*4,id)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x200,bytes(0x300));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,c.get('id',101),4]):u.reg_write(reg,v)
 u.emu_start(0x1403d0410,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,ids=ids,rate=m.si(stats+0xe20),type=int.from_bytes(u.mem_read(target+0x908,2),'little'),master=m.si(target+0x8fc)&0xffffffff)
rows=[run(dict(ids=ids,rate=rate,oldType=oldType,targetType=targetType,faction=faction,missing=missing)) for ids,rate,oldType,targetType,faction,missing in itertools.product([None,[],[100],[100,101,100],[2130706432,100,102]],[-1,0,1,2,3,4,5,7],[0,4],[0,4],[False,True],[False,True])]
rows += [run(dict(id=99,ids=[100]))]
out=m.root/'backups/animations/native-summon-associate-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
