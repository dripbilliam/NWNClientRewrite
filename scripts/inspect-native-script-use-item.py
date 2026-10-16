"""Complete original ActionUseItem14050f190 for object910/location911.
Typed pops, canonical creature/item/area lookup, active-property lookup, UseItem
and the two structure-scope destructor/deleter pairs are captured. Actual ID
scan, narrowing, coordinate/area selection, rejection and cleanup execute the
original binary. No native VM allocator, packet or whole-campaign claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
command,vm,app,actor,item,area,location,handle=[m.heap+n*0x1000 for n in range(1,9)];props=m.heap+0x10000
propertyDestroy,propertyDelete=[m.q(0x140dfbd88+n) for n in [0x10,0x20]]
locationDestroy,locationDelete=[m.q(0x140dfbdc0+n) for n in [0x10,0x20]]
def hook(u,a,n,_):
 global popIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140286160,0x140286030,0x140286110]:
  index=popIndex;popIndex+=1;kind='itemproperty' if a==0x140286030 and y==4 else 'location' if a==0x140286030 else 'object' if a==0x140286160 else 'int';pops.append([kind,index]);okay=index<c.get('argc',5) and index!=c.get('failPop',-1)
  if okay:
   if kind=='itemproperty':m.wq(z,0 if c.get('nullProperty') else handle)
   elif kind=='location':assert y==2;m.wq(z,location if c.get('location',True) else 0)
   else:m.wi(y,c.get('itemId',20) if index==0 else c.get('targetId',100) if index==2 and c.get('ordinal',910)==910 else c.get('variant',0) if index==(2 if c.get('ordinal',910) not in [910,911] else 3) else c.get('consume',1))
  m.finish(int(okay))
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(0 if c.get('missingActor') else actor)
 elif a==0x14055b6c0:calls.append(['item',y&0xffffffff]);m.finish(0 if c.get('missingItem') else item)
 elif a==0x1404686d0:calls.append(['property',y&0xffffffff]);m.finish(props+(y&0xffffffff)*48)
 elif a==0x140494e80:calls.append(['area']);m.finish(0 if c.get('missingArea') else area)
 elif a==0x1403a9f70:
  ptr=m.q(rsp+0x30);calls.append(['use',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&0xffffffff,list(struct.unpack('<3f',u.mem_read(ptr,12))),m.si(rsp+0x38)&0xffffffff,m.si(rsp+0x40)]);m.finish(c.get('useResult',1))
 elif a in [propertyDestroy,locationDestroy]:cleanup.append(['destroy','itemproperty' if a==propertyDestroy else 'location',bool(m.q(m.q(x+8)))]);m.finish()
 elif a in [propertyDelete,locationDelete]:cleanup.append(['delete','itemproperty' if a==propertyDelete else 'location',y&255]);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not 0x14050f190<=a<0x14050f471:raise AssertionError(f'Uncaptured script item dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,popIndex,pops,calls,cleanup
 c=case;popIndex=0;pops=[];calls=[];cleanup=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df910,vm);m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(command+12,99);m.wi(area+0x140,c.get('areaId',7));m.wi(location+0x18,999);m.wq(handle+0xf0,int(c.get('propertyId','0000000100000001'),16));ids=c.get('properties',['0000000000000001','0000000100000001','ffffffffffffffff']);m.wi(item+0x370,c.get('count',len(ids)))
 for index,id in enumerate(ids):m.wq(props+index*48+0x28,int(id,16))
 for index,value in enumerate([4.5,6.25,-8.75]):m.wf(location+index*4,value)
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop)
 for reg,value in zip([UC_X86_REG_RSP,UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[rsp,command,c.get('ordinal',910),c.get('argc',5)]):u.reg_write(reg,value)
 try:u.emu_start(0x14050f190,m.stop,count=100000)
 except Exception as error:raise AssertionError(f'Script item {c} RIP{u.reg_read(UC_X86_REG_RIP):x} calls{calls} pops{pops}') from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;result=result if result<0x80000000 else result-0x100000000
 return dict(case=c,result=result,pops=pops,calls=calls,cleanup=cleanup)
cases=[dict(ordinal=ordinal,propertyId=id,variant=variant,consume=consume,location=loc,missingArea=missing) for ordinal,id,variant,consume,loc,missing in itertools.product([910,911],['0000000000000001','0000000100000001','ffffffffffffffff','0000000000000000'],[-1,0,1,256,258],[0,1,-2],[False,True],[False,True])]
cases += [dict(ordinal=ordinal,**{key:True}) for ordinal,key in itertools.product([910,911],['missingActor','missingItem'])]
cases += [dict(ordinal=ordinal,argc=count,failPop=index) for ordinal,count,index in itertools.product([910,911],[0,1,2,3,4,5],[-1,0,1,2,3,4])]
cases += [dict(ordinal=ordinal,useResult=result) for ordinal,result in itertools.product([910,911],[0,1,2,-1])]
cases += [dict(ordinal=ordinal,properties=ids,propertyId=id) for ordinal,ids,id in itertools.product([910,911],[[],['0000000000000000'],['0000000100000001']*2],['0000000000000000','0000000100000001'])]
cases += [dict(ordinal=ordinal,properties=[f'{n+1:016x}' for n in range(260)],propertyId=f'{index+1:016x}') for ordinal,index in itertools.product([910,911],[254,255,256,257,259])]
cases += [dict(ordinal=911,nullProperty=True,properties=[]),dict(ordinal=910,count=-1),dict(ordinal=909,argc=4),dict(ordinal=911,areaId=0xf0000001),dict(ordinal=910,itemId=0xf1234567,targetId=0xe1234567)]
out=m.root/'backups/animations/native-script-use-item-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=[run(c) for c in cases]))+'\n');print(json.dumps(dict(rows=len(cases),destructors=[hex(v) for v in [propertyDestroy,propertyDelete,locationDestroy,locationDelete]],output=str(out))))
