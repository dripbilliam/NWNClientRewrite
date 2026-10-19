"""Original AssociateAccess510b50, AddAssociate3d0410 type1, max-henchmen
wrappers, ctor write and typed loader block. VM transfers, object/module lookup,
possession/DM guards, activity/invisibility, lower ownership/faction/list/message
calls are captured boundaries. Full henchman AI, client-info/network imports,
effect removal and save/export are not established by these captures.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,old,target,other,app,server,internal,manager,module,faction,linked,values,stats,statsA,message,resource,root,field=[m.heap+n*0x1000 for n in range(1,19)]
objects={99:actor,100:old,101:target,102:other}
ranges=[(0x140510b50,0x140510cec),(0x1403d0410,0x1403d0959),(0x14052b960,0x14052b9a8),(0x1405438b0,0x140543946),(0x140478922,0x14047892d),(0x140480dc6,0x140480def),(0x1401a1770,0x1401a17e2)]
ends={0x14047892d,0x140480def}

def hook(u,a,n,_):
 global pops,output
 if a==m.stop or a in ends:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140286160:
  calls.append(['popObject']);m.wi(y,c.get('master',99) if pops==0 else c.get('id',101));pops+=1;m.finish(int(pops!=c.get('failPop',0)))
 elif a==0x140286110:calls.append(['popInt']);m.wi(y,c.get('value',1));m.finish(c.get('pop',1))
 elif a==0x140286410:calls.append(['push',y&0xffffffff]);output=y&0xffffffff;m.finish(c.get('push',1))
 elif a==0x14055b6e0:calls.append(['module']);m.finish(module if c.get('module',True) else 0)
 elif a==0x14055b3d0:
  oid=y&0xffffffff;calls.append(['creature',oid]);m.finish(0 if (oid==99 and not c.get('masterExists',True)) or (oid==101 and not c.get('exists',True)) else objects.get(oid,0))
 elif a==0x1403d54d0:calls.append(['possessed',101]);m.finish(c.get('possessed',0))
 elif a==0x140402f80:calls.append(['dm',101]);m.finish(c.get('dm',0))
 elif a==0x1403d0410 and c['mode']=='script':calls.append(['add',m.si(x+8)&0xffffffff,y&0xffffffff,z&65535]);m.finish()
 elif a==0x1403a2650:calls.append(['activity',m.si(x+8)&0xffffffff,y,z]);m.finish()
 elif a==0x14039e500:calls.append(['invisibility',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x1403d6e10:calls.append(['remove',m.si(x+8)&0xffffffff,y&0xffffffff]);m.finish()
 elif a==0x1403d4d70:calls.append(['associate',m.si(x+8)&0xffffffff,y,z]);m.finish(c.get('associate',101))
 elif a==0x1404160a0:calls.append(['rate',101,y]);m.wi(stats+0xe20,y);m.finish()
 elif a==0x1403d8160:calls.append(['patterns',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x1403a2cd0:calls.append(['type',m.si(x+8)&0xffffffff,y&65535]);u.mem_write(x+0x908,struct.pack('<H',y&65535));m.finish()
 elif a==0x1403a34b0:calls.append(['master',m.si(x+8)&0xffffffff,y&0xffffffff]);m.wi(x+0x8fc,y);m.finish()
 elif a==0x140c10324:m.finish(message if x==0x48 else linked)
 elif a==0x1402da730:assert y==0;m.wi(message+0x100,z);m.finish()
 elif a==0x1403a2480:calls.append(['feedback',y,m.si(message+0x100)]);m.finish()
 elif a==0x140175070:m.finish(int((y&0xffffffff) in ids))
 elif a==0x14008ae10:ids.append(y&0xffffffff);m.finish()
 elif a==0x140357900:calls.append(['faction',y&0xffffffff]);m.finish(faction if c.get('faction',True) else 0)
 elif a==0x1404ad6b0:calls.append(['addMember',y&0xffffffff,z]);m.finish()
 elif a==0x14019fcc0:assert bytes(u.mem_read(z,len(b'Mod_MaxHenchmen\0')))==b'Mod_MaxHenchmen\0';calls.append(['field']);m.finish(7)
 elif a==0x14019fc20:assert z==7;calls.append(['descriptor']);m.finish(field if c.get('present',True) else 0)
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured henchman dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,ids,pops,output
 c=case;calls=[];ids=list(c.get('ids') or []);pops=0;output=None;u.mem_write(m.heap,bytes(0x100000))
 m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(server+8,internal);m.wq(internal+0x100b0,manager)
 for oid,obj in objects.items():m.wi(obj+8,oid);m.wi(obj+0x8fc,c.get('owner',99))
 for oid,kind in [(100,c.get('oldType',1)),(101,c.get('type',0)),(102,1)]:u.mem_write(objects[oid]+0x908,struct.pack('<H',kind&65535))
 m.wi(target+0x89c,c.get('pc',0));m.wq(target+0xad0,stats);m.wi(stats+0xe20,c.get('rate',0));m.wq(actor+0xad0,statsA);m.wi(statsA+0xc4,7);m.wi(module+0x3fc,c.get('max',1));m.wi(module+0x400,17)
 if c.get('ids') is not None:
  m.wq(actor+0x900,linked);m.wq(linked,values);m.wi(linked+8,len(ids))
  for i,oid in enumerate(ids):m.wi(values+i*4,oid)
 m.wq(module+8,resource);m.wi(field,c.get('fieldType',5));m.wi(field+8,c.get('value',1))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_RSI,UC_X86_REG_R14],[actor,c.get('command',365),c.get('argc',2),module,module]):u.reg_write(reg,value)
 if c['mode']=='add':u.reg_write(UC_X86_REG_RDX,c.get('id',101));u.reg_write(UC_X86_REG_R8,1)
 start={'script':0x140510b50,'add':0x1403d0410,'get':0x14052b960,'set':0x1405438b0,'ctor':0x140478922,'load':0x140480dc6}[c['mode']]
 u.emu_start(start,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop or u.reg_read(UC_X86_REG_RIP) in ends
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,ids=ids,rate=m.si(stats+0xe20),type=int.from_bytes(u.mem_read(target+0x908,2),'little'),master=m.si(target+0x8fc)&0xffffffff,max=m.si(module+0x3fc),adjacent=m.si(module+0x400))

rows=[run(dict(mode='script',command=command,argc=argc,pc=pc,possessed=possessed,dm=dm,type=kind,owner=owner))for command,argc,pc,possessed,dm,kind,owner in itertools.product([365,366,503,99],[1,2],[0,1,-1],[0,1],[0,1],[0,1,4],[99,102])]
rows += [run(dict(mode='script',command=command,failPop=fail,masterExists=master,exists=exists,associate=associate))for command,fail,master,exists,associate in itertools.product([365,366,503],[0,1,2],[False,True],[False,True],[101,0x7f000000])]
rows += [run(dict(mode='add',ids=ids,max=cap,rate=rate,oldType=kind,faction=faction,exists=exists,module=module))for ids,cap,rate,kind,faction,exists,module in itertools.product([None,[],[100],[100,101,100],[2130706432,100,102]],[-1,0,1,2,100],[-1,0,2,3,4,7],[0,1],[False,True],[False,True],[False,True])]
rows += [run(dict(mode='add',id=99,ids=[100]))]
rows += [run(dict(mode=mode,value=value,max=value,pop=pop,push=push,module=module))for mode,value,pop,push,module in itertools.product(['get','set'],[-0x80000000,-1,0,1,2,99,100,101,0x7fffffff],[0,1],[0,1],[False,True])]
rows += [run(dict(mode='load',value=value,fieldType=fieldType,present=present))for value,fieldType,present in itertools.product([-1,0,1,2,100,101,0x7fffffff,-0x80000000],[0,4,5,8],[False,True])]
rows += [run(dict(mode='ctor'))]
out=m.root/'backups/animations/native-henchmen-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
