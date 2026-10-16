"""Full original UseItem1403a9f70 and AddItemCastSpellActions14037f030.
Registry/casts, CanUseItem, active property/2DA/spell lookup, perception,
equipment, ComputeSpellRange, movement, queue construction and skill/trap
owners are captured. No claim of action46 execution or charge consumption.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,item,parent,target,targetitem,area,otherarea,prop,point,app,rules,spell,base,visibility,vtable,stats=[m.heap+n*0x1000 for n in range(1,17)]
def xyz(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12))) if ptr else None
def getitem(id):return item if id==55 and c.get('item',True) else parent if id==77 and c.get('parent',False) else 0
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b6c0:calls.append(['item',y&0xffffffff]);m.finish(getitem(y&0xffffffff))
 elif a==0x14055b4c0:calls.append(['object',y&0xffffffff]);m.finish(target if c.get('targetExists',True) else 0)
 elif a==0x1403d2410:calls.append(['canUse',z&0xffffffff]);m.finish(c.get('canUse',1))
 elif a==0x1404686d0:calls.append(['property',y&0xffffffff]);m.finish(prop if c.get('property',True) else 0)
 elif a==m.stop+0x100:calls.append(['asCreature']);m.finish(target if c.get('targetCreature',True) else 0)
 elif a==m.stop+0x108:calls.append(['asItem']);m.finish(targetitem)
 elif a==0x1403d5850:calls.append(['visibility',y&0xffffffff]);m.finish(visibility if c.get('visibility',1) is not None else 0)
 elif a==0x14029ca00:calls.append(['base',y&0xffffffff]);m.finish(0 if c.get('missingBase') else base)
 elif a==0x140462c10:calls.append(['equipped']);m.finish(c.get('equipped',1))
 elif a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);m.finish()
 elif a==0x14037f030 and kind=='use':calls.append(['cast',dict(itemId=y&0xffffffff,propertyIndex=z&255,mode=w&255,position=xyz(m.q(rsp+0x28)),targetId=m.si(rsp+0x30)&0xffffffff,location=m.si(rsp+0x38),automatic=m.si(rsp+0x40))]);m.finish(c.get('lowerResult',1))
 elif a==0x1403808c0:calls.append(['trap',y&0xffffffff,z&255,w&0xffffffff,xyz(m.q(rsp+0x28)),m.si(rsp+0x30)&0xffffffff]);m.finish(c.get('lowerResult',1))
 elif a==0x1403aa390:calls.append(['skill',y&255,z&255,w&0xffffffff,xyz(m.q(rsp+0x28)),m.si(rsp+0x30)&0xffffffff,m.si(rsp+0x38)&0xffffffff,m.si(rsp+0x40)]);m.finish(c.get('lowerResult',1))
 elif a==0x1403d54d0:calls.append(['possessed']);m.finish(c.get('possessed',0))
 elif a==0x140402f80:calls.append(['dm']);m.finish(c.get('dm',0))
 elif a==0x140494e80:
  calls.append(['area','target' if x==target else 'actor']);value=c.get('targetArea','same')
  m.finish((area if value=='same' else otherarea if value=='other' else 0) if x==target else area if c.get('area',True) else 0)
 elif a==0x1401a7010:calls.append(['spellIndex',y&65535]);m.wi(w,c.get('spellId',100));m.finish(c.get('indexFound',1))
 elif a==0x1402af4a0:calls.append(['spell',y&0xffffffff]);m.finish(0 if c.get('missingSpell') else spell)
 elif a==0x14019e620:m.finish(x)
 elif a==0x140388d20:
  calls.append(['range',z&0xffffffff]);u.reg_write(UC_X86_REG_XMM0,struct.unpack('<I',struct.pack('<f',c.get('range',5)))[0]);m.finish()
 elif a==0x14037f940:
  calls.append(['move',y&65535,xyz(z),w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),m.rf(rsp+0x38),m.rf(rsp+0x40),*[m.si(rsp+offset) for offset in [0x48,0x50,0x58,0x60,0x68,0x70]]]);m.finish(c.get('lowerResult',1))
 elif a==0x14048cb80:
  params=[];typ=w&0xffffffff;ptr=m.q(rsp+0x28)
  for index in range(12):
   if index:typ=m.si(rsp+0x30+(index-1)*16);ptr=m.q(rsp+0x38+(index-1)*16)
   if typ==0:break
   params.append(dict(type=typ,value=m.si(ptr)&0xffffffff))
  calls.append(['queue',y&0xffffffff,z&65535,params,False]);m.finish(c.get('lowerResult',1))
 elif a==0x140c10368:m.finish(m.heap+0x20000)
 elif a==0x140c10370:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1403a9f70,0x1403aa20c),(0x14037f030,0x14037f936)]):raise AssertionError(f'Uncaptured item request dependency {a:x} {kind} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,owner):
 global c,kind,calls
 c=case;kind=owner;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x20,rules);m.wq(rules+0xd0,rules);m.wq(rules+0x130,rules);m.wq(rules+0x148,rules);m.wq(actor+0xad0,stats)
 m.wi(actor+8,99);m.wi(actor+0x73c,123);m.wi(actor+0x740,124);m.wi(actor+0xec,c.get('commandable',1));m.wi(actor+0x89c,c.get('pc',0));m.wi(actor+0x97c,c.get('polymorph',0));u.mem_write(actor+0x908,struct.pack('<H',c.get('associate',0)&65535));m.wi(item+0x3c8,c.get('owner',99));m.wi(parent+0x3c8,c.get('parentOwner',99));m.wi(item+0x40,c.get('baseItem',49));m.wi(item+0x50,55);m.wi(targetitem+0x3c8,c.get('targetOwner',99));m.wi(target+8,100);u.mem_write(target+12,bytes([c.get('targetType',5)&255]));m.wq(target,vtable);m.wq(vtable+0x60,m.stop+0x100);m.wq(vtable+0x70,m.stop+0x108);m.wi(area+0x140,7);m.wi(otherarea+0x140,8)
 u.mem_write(prop,struct.pack('<HH',c.get('type',15)&65535,c.get('subtype',33)&65535));m.wi(prop+12,c.get('remaining',1));m.wi(base+4,c.get('slots',0));u.mem_write(visibility+4,bytes([(c.get('visibility',1) or 0)&255]))
 for ptr,values in [(actor+0xa4,c.get('actorPoint',[0,0,0])),(target+0xa4,c.get('targetPoint',[2.5,0,0])),(point,c.get('point',[1.25,2.5,3.75]))]:
  for index,value in enumerate(values):m.wf(ptr+index*4,value)
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[actor,55,c.get('propertyIndex',0),c.get('mode',0)]):u.reg_write(reg,value&0xffffffffffffffff)
 values=[c.get('targetId',100),point,7,c.get('automatic',1)] if owner=='use' else [point,c.get('targetId',100),c.get('location',0),c.get('automatic',1)]
 for index,value in enumerate(values):m.wq(rsp+0x28+index*8,value&0xffffffffffffffff)
 u.emu_start(0x1403a9f70 if owner=='use' else 0x14037f030,m.stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;result=result if result<0x80000000 else result-0x100000000
 return dict(case=c,result=result,calls=calls,point=xyz(point),targetField=m.si(actor+0x73c)&0xffffffff,target740=m.si(actor+0x740)&0xffffffff)
usecases=[dict(type=typ,baseItem=base,remaining=remaining,slots=slots,equipped=equipped,visibility=visible,lowerResult=result) for typ,base,remaining,slots,equipped,visible,result in itertools.product([15,55,70,80,1],[49,50,54,75,104],[0,1,-1],[0,16],[0,1],[None,1,4,12,16],[0,1,-1])]
usecases += [dict(owner=owner,parent=parent,parentOwner=parentOwner,associate=associate) for owner,parent,parentOwner,associate in itertools.product([99,77,88],[False,True],[99,100],[0,7,8,9,65543])]
usecases += [dict(**{key:value}) for key,values in {'item':[False],'targetExists':[False],'targetCreature':[False],'canUse':[0,-1],'property':[False],'propertyIndex':[255,256,257,-1],'mode':[255,256,-1],'missingBase':[True],'targetId':[0x7f000000]}.items() for value in values]
queuecases=[dict(baseItem=base,point=point,targetId=target,range=range,dm=dm,location=location,automatic=automatic) for base,point,target,range,dm,location,automatic in itertools.product([49,50,104],[[0,0,0],[3,4,0],[20,0,0]],[100,0x7f000000],[0,5],[0,1],[0,1],[0,1,-1])]
queuecases += [dict(targetType=typ,targetArea=targetArea,targetOwner=owner,targetCreature=creature,visibility=visible) for typ,targetArea,owner,creature,visible in itertools.product([5,6,9],['same','none','other'],[99,100],[False,True],[None,1,4,16,17])]
queuecases += [dict(pc=pc,possessed=possessed,polymorph=poly,baseItem=base) for pc,possessed,poly,base in itertools.product([0,1],[0,1],[0,1,2],[49,50,104])]
queuecases += [dict(**{key:value}) for key,values in {'item':[False],'targetExists':[False],'property':[False],'missingSpell':[True],'area':[False],'commandable':[0,-1],'spellId':[-1,0],'propertyIndex':[-1,255,256],'indexFound':[0]}.items() for value in values]
out=m.root/'backups/animations/native-item-cast-request-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,uses=[run(c,'use') for c in usecases],queues=[run(c,'queue') for c in queuecases]))+'\n');print(json.dumps(dict(useCases=len(usecases),queueCases=len(queuecases),output=str(out))))
