"""Original EffectSummonCreature14051bf80. Capture base allocation/VM/string/
creator/lookup boundaries; execute argument grouping, type and setters unchanged.
Application/placement/associate/destruction are separate owners, not proven here.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
command,vm,effect,integers,string,app,target,stats,vtable,closure=[m.heap+n*0x1000 for n in range(1,11)]
def hook(u,a,n,_):
 global output,popIndex
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a in [0x140286110,0x140286160,0x1402860c0,0x1402861b0]:
  popIndex+=1
  if popIndex==c.get('failPop',0):m.finish(0);return
  if a==0x1402861b0:m.wq(y,string);m.wi(y+8,len(c['name']));u.mem_write(string,c['name'].encode()+b'\0')
  elif a==0x1402860c0:m.wf(y,c['delay'])
  else:m.wi(y,args.pop(0))
  m.finish(1)
 elif a==0x140c10324:m.finish(effect)
 elif a==0x1404233d0:
  u.mem_write(effect,bytes(0x110));m.wq(effect+0x48,integers);m.wi(effect+0x40,8);m.wi(effect+0x18,0x7f000000);m.wi(effect+0x1c,-1);m.wi(effect+0x28,-1)
  for i in range(4):m.wi(effect+0xc0+i*4,0x7f000000)
  m.finish(effect)
 elif a==0x140425110:m.wi(effect+0x18,y);m.wi(effect+0x1c,17);m.wi(effect+0x28,3);m.finish()
 elif a==0x140425310:strings[y]=c['name'];m.finish()
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(target if c.get('exists',True) else 0)
 elif a==0x140286330:
  output=dict(type=int.from_bytes(u.mem_read(z+8,2),'little'),subtype=int.from_bytes(u.mem_read(z+10,2),'little'),creatorId=m.si(z+0x18)&0xffffffff,
   spellId=m.si(z+0x1c),casterLevel=m.si(z+0x28),integers=list(struct.unpack('<8i',u.mem_read(integers,32))),objectIds=list(struct.unpack('<4I',u.mem_read(z+0xc0,16))),floats=list(struct.unpack('<4f',u.mem_read(z+0x50,16))),strings=strings.copy());m.finish(c.get('push',1))
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a in [0x140423770,0x140c10360,0x140c10370,0x1405536b0,0x140553400,m.stop+0x10]:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14051bf80,0x14051c281),(0x140425210,0x14042521c),(0x140425200,0x14042520a),(0x140425300,0x140425314)]):raise AssertionError(f'Uncaptured summon constructor dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,args,output,strings,calls,popIndex
 c=case;args=[c.get('visual',-1),c.get('appear',0),c.get('unsummon',99),c.get('target',100)];output=None;strings={};calls=[];popIndex=0
 u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df910,vm);m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(command+0xc,99);m.wq(target+0xad0,stats);m.wi(stats+0xb0,c.get('pc',0))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[command,83,c['argc']]):u.reg_write(reg,v)
 u.emu_start(0x14051bf80,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,output=output,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,pops=popIndex)
rows=[run(dict(argc=argc,name=name,delay=delay,appear=appear,visual=visual,unsummon=unsummon,pc=pc,exists=exists)) for argc,name,delay,appear,visual,unsummon,pc,exists in itertools.product([1,2,3,4,5,6],['','nw_wolf','LongResRef01234567890'],[-2,0,.5],[0,2],[-1,100],[99,321],[0,1],[False,True])]
rows += [run(dict(argc=6,name='wolf',delay=.5,failPop=fail,push=push)) for fail,push in itertools.product(range(7),[0,1])]
out=m.root/'backups/animations/native-summon-constructor-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
