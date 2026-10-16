"""Full original ActionUseFeat14050ee70..14050f190, including typed pop
failure, auxiliary normalization, canonical lookups, area/point selection and
cleanup. VM pop, object/area/casts, UseFeat and location destruction are captured
boundaries; no claim of native VM execution or all lower feat/spell effects.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
command,vm,app,objects,actor,target,area,location,spell,vtable=[m.heap+n*0x1000 for n in range(1,11)]
destroy=m.q(0x140dfbc00+0x10);delete=m.q(0x140dfbc00+0x20)
def hook(u,a,n,_):
 global popIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140286110,0x140286160,0x140286030]:
  index=popIndex;popIndex+=1;pops.append(['location' if a==0x140286030 else 'object' if a==0x140286160 else 'int',index]);okay=index<c['argc'] and index!=c.get('failPop',-1)
  if okay:
   if a==0x140286030:assert y==2;m.wq(z,location if c.get('location') else 0)
   else:m.wi(y,c.get('featId',257) if index==0 else c.get('targetId',100) if index==1 else c.get('auxiliary',20))
  m.finish(int(okay))
 elif a==0x1402af4a0:calls.append(['spell',y&0xffffffff]);m.finish(0 if c.get('missingSpell') else spell)
 elif a==0x14055b850:m.finish(objects)
 elif a==0x140296470:calls.append(['object',y&0xffffffff]);m.wq(z,actor if c.get('selfExists',True) else 0);m.finish(0 if c.get('selfExists',True) else 1)
 elif a==0x14055b4c0:calls.append(['object',y&0xffffffff]);m.finish(target if c.get('targetExists',True) else 0)
 elif a==m.stop+0x100:calls.append(['asCreature']);m.finish(actor if c.get('creature',True) else 0)
 elif a==m.stop+0x108:calls.append(['asObject']);m.finish(actor if c.get('worldObject',True) else 0)
 elif a==0x140494e80:calls.append(['area']);m.finish(area if c.get('area',True) else 0)
 elif a==0x14055b2e0:calls.append(['areaById',y&0xffffffff]);m.finish(area if c.get('locationArea',True) else 0)
 elif a==0x1403a91d0:
  ptr=m.q(rsp+0x30);calls.append(['use',y&65535,z&65535,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,list(struct.unpack('<3f',u.mem_read(ptr,12))) if ptr else None]);m.finish(c.get('useResult',1))
 elif a==destroy:cleanup.append(['destroy',bool(m.q(m.q(x+8)))]);m.finish()
 elif a==delete:cleanup.append(['delete',y&255]);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not 0x14050ee70<=a<0x14050f190:raise AssertionError(f'Uncaptured ActionUseFeat dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,popIndex,calls,pops,cleanup
 c=case;popIndex=0;calls=[];pops=[];cleanup=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df910,vm);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,app);m.wq(app+0xd0,app);m.wi(command+12,99);m.wq(actor,vtable);m.wq(vtable+0x60,m.stop+0x100);m.wq(vtable+0x20,m.stop+0x108);m.wi(area+0x140,7);m.wi(location+0x18,8);m.wi(spell+0x198,c.get('spellFeat',1009)<<16)
 for index,value in enumerate([1.25,-2.5,30.75]):m.wf(actor+0xa4+index*4,value)
 for index,value in enumerate([4.5,6.25,-8.75]):m.wf(location+index*4,value)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,command);u.reg_write(UC_X86_REG_RDX,287);u.reg_write(UC_X86_REG_R8,c['argc'])
 u.emu_start(0x14050ee70,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;result=result if result<0x80000000 else result-0x100000000
 return dict(case=c,result=result,calls=calls,pops=pops,cleanup=cleanup)
cases=[dict(argc=argc,featId=id,auxiliary=aux,spellFeat=feat,targetExists=exists,location=loc,locationArea=valid) for argc,id,aux,feat,exists,loc,valid in itertools.product([2,4],[5,304,305,334,335,342,343,872,1060,257,65541],[20,-1],[1009,65535],[False,True],[False,True],[False,True])]
cases += [dict(argc=4,featId=257,**{key:value}) for key in ['selfExists','creature','area','worldObject','missingSpell'] for value in [False,True]]
cases += [dict(argc=count,failPop=index,location=True) for count,index in itertools.product([0,1,2,3,4],[0,1,2,3])]
cases += [dict(argc=4,useResult=result) for result in [0,1,-1,2147483647]]
rows=[run(c) for c in cases];out=m.root/'backups/animations/native-script-use-feat-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out),destructor=hex(destroy),deleter=hex(delete))))
