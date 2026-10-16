"""Unchanged AIActionItemCastSpell1403c07b0, SetCharges14046c440 and
GetUsedActivePropertyUsesLeft140469170. Synthetic canonical lookup, tables,
world clock, activity/round/presentation/impact/event boundaries. Full action
instructions execute, including consumption, cleanup and saved node timers.
This is not a claim that every downstream spell effect is implemented.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
from native_rule_fixture import ruleset_value
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,target,item,node,props,app,rules,spell,child,clock,vtable,allocated,model,roundState=[m.heap+n*0x4000 for n in range(1,15)]
q,si,wi,wq,wf,finish=[getattr(m,n) for n in ['q','si','wi','wq','wf','finish']]
def xyz(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))
def props_out():return [dict(type=int.from_bytes(u.mem_read(props+i*48,2),'little'),costValue=int.from_bytes(u.mem_read(props+i*48+6,2),'little'),remaining=si(props+i*48+12),usesPerDay=u.mem_read(props+i*48+16,1)[0]) for i in range(len(properties))]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14037cc30:calls.append(['activityManager',y&0xffffffff]);finish()
 elif a==0x1404953b0:calls.append(['dead']);finish(c.get('dead',0))
 elif a==0x140495620:calls.append(['dying']);finish(c.get('dying',0))
 elif a==0x14055b2c0:calls.append(['worldTime',y&0xffffffff]);finish(clock)
 elif a==0x140597180:wi(y,c.get('nowDay',3));wi(z,c.get('nowTime',9000));finish()
 elif a==0x14055ba10:finish(clock)
 elif a==0x140597a20:
  calls.append(['elapsed',y&0xffffffff,z&0xffffffff,w&0xffffffff,si(rsp+0x28)&0xffffffff]);wi(q(rsp+0x30),c.get('elapsedDays',0));wi(q(rsp+0x38),c.get('elapsed',0));finish(0)
 elif a==0x14055b4c0:calls.append(['object',y&0xffffffff]);finish(target if c.get('targetExists',True) else 0)
 elif a==m.stop+0x10:calls.append(['asCreature']);finish(target if c.get('targetCreature',True) else 0)
 elif a==m.stop+0x20:calls.append(['animation','target' if x==target else 'actor',y&65535]);finish()
 elif a==0x14055b6c0:calls.append(['item',y&0xffffffff]);finish(item if c.get('item',True) else 0)
 elif a==0x1404686d0:
  index=y&0xffffffff;calls.append(['property',index]);finish(props+48*index if c.get('property',True) and index<len(properties) else 0)
 elif a==0x1401a7010:
  text=u.mem_read(q(z),si(z+8)).decode('ascii');calls.append(['propertyInt',y&65535,text]);wi(w,c.get('spellId',101) if text=='SpellIndex' else c.get('casterLevel',7));finish(c.get('tableFound',1))
 elif a==0x1402af4a0:
  id=y&0xffffffff;calls.append(['spell',id]);finish(0 if not c.get('spell',True) or id!=(c.get('spellId',101)&0xffffffff) and c.get('childMissing') else spell if id==(c.get('spellId',101)&0xffffffff) else child)
 elif a==0x1402af850:calls.append(['subRadialSpell',y&255]);finish(c.get('childId',102))
 elif a==0x1401a68f0:
  calls.append(['modelType']);text=c.get('model','P').encode();u.mem_write(model,text+b'\0');wq(w,model);wi(w+8,len(text));finish(1)
 elif a==0x14016af10:
  text=u.mem_read(q(x),si(x+8));index=text.find(bytes([y&255]));finish(index)
 elif a==0x1402a4130:finish(ruleset_value(c.get('rulesOverrides',{}),y,z))
 elif a==0x14037a000:calls.append(['startRound',y&0xffffffff]);wi(roundState+0x2f04,1);finish()
 elif a==0x140375a30:calls.append(['decrementRound',y&0xffffffff,z&0xffffffff]);finish()
 elif a==0x140379c70:calls.append(['pause',y&0xffffffff,z&0xffffffff]);finish()
 elif a==0x140379c30:calls.append(['pauseTimer',y&0xffffffff,z&0xffffffff]);finish()
 elif a==0x140392ec0:calls.append(['playerCharacter']);finish(c.get('pc',1))
 elif a==0x14055b420:calls.append(['difficulty',y&0xffffffff]);finish(c.get('difficulty',1))
 elif a==0x140382eb0:calls.append(['opportunity',y&0xffffffff,z&0xffffffff]);finish()
 elif a==0x140469170:calls.append(['usesLeft',y&255])
 elif a==0x14046c440:calls.append(['setCharges',y&0xffffffff,z&0xffffffff])
 elif a==0x14048fe20:calls.append(['projectileTime',y&255]);wi(actor+0x220,c.get('projectileTime',450));finish()
 elif a==0x14049c4b0:
  calls.append(['impact',y&0xffffffff,xyz(z),w&0xffffffff,si(rsp+0x28)&255,si(rsp+0x30)&0xffffffff,si(rsp+0x38),si(rsp+0x40),si(rsp+0x48)&255,si(rsp+0x50)]);wi(actor+0x224,1);finish()
 elif a==0x1403766e0:finish(si(roundState+0x2f04))
 elif a==0x140378f80:calls.append(['removeSpellActions']);finish()
 elif a==0x14039ecb0:calls.append(['removeRoundSpell']);finish()
 elif a==0x14039be00:calls.append(['pendingEquipment']);finish()
 elif a==0x1403a2480:calls.append(['feedback',y&0xffffffff]);finish()
 elif a==0x14055b960:finish(app)
 elif a==0x1405570b0:calls.append(['enqueue',si(rsp+0x30),w&0xffffffff,si(rsp+0x28)&0xffffffff,z&0xffffffff,None]);assert q(rsp+0x38)==0;finish()
 elif a==0x14046cf20:calls.append(['activeChanged',y&0xffffffff]);finish()
 elif a==0x140c10368:finish(allocated)
 elif a==0x140c10370:finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1403c07b0,0x1403c1a28),(0x140469170,0x1404692a9),(0x14046c440,0x14046c516),(0x1402ae870,0x1402ae899)]):raise AssertionError(f'Uncaptured item cast dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,properties
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));wq(0x1412df970,app);wq(app+8,app);wq(0x1412df8f8,rules);wq(rules+0xd0,rules);wq(rules+0x130,rules);wq(rules+0x148,rules);wq(rules+0x100,rules)
 wi(actor+8,99);wi(actor+0xa0,7);wi(actor+0x828,c.get('activated',0));wi(actor+0x224,c.get('impactDone',0));wi(actor+0x228,11);wi(actor+0x218,12);wi(actor+0x214,13);wi(actor+0x818,14);wi(actor+0x824,15);wi(actor+0x820,16);u.mem_write(actor+0x22d,b'\x11');u.mem_write(actor+0x23c,b'\x12\x00');wq(actor+0x880,roundState);wi(roundState+0x2f04,c.get('started',0));wi(actor+0x740,19)
 wq(actor,vtable);wq(target,vtable);wq(vtable+0x60,m.stop+0x10);wq(vtable+0x100,m.stop+0x20);wi(target+0x8fc,c.get('masterId',0x7f000000))
 wi(item+0x40,c.get('baseItem',49));wi(item+0x50,55);wi(item+0x144,c.get('plot',0));wi(item+0x388,c.get('charges',10));wi(item+0x454,c.get('stackSize',1));wi(item+0x398,0)
 properties=[dict(type=c.get('type',15),costValue=c.get('cost',1),remaining=c.get('remaining',1),usesPerDay=c.get('daily',1)),*c.get('others',[])];wq(item+0x368,props);wi(item+0x370,len(properties))
 for i,prop in enumerate(properties):u.mem_write(props+i*48,struct.pack('<HHHH',prop['type']&65535,33,0,prop['costValue']&65535));wi(props+i*48+12,prop['remaining']);u.mem_write(props+i*48+16,bytes([prop['usesPerDay']&255]))
 u.mem_write(spell+0x170,bytes([c.get('children',0)&255]));wi(spell+0xe0,c.get('castTime',1000));wi(child+0xe0,c.get('childCastTime',2000));wi(node+0x9c,c.get('releaseFlag',1))
 values=[55,c.get('index',0),c.get('variant',0),c.get('targetId',100),*[struct.unpack('<i',struct.pack('<f',v))[0] for v in c.get('point',[1.25,2.5,3.75])],c.get('startDay',3),c.get('startTime',1000),c.get('consume',1)]
 for i,v in enumerate(values):wq(node+0x38+i*8,v&0xffffffffffffffff)
 rsp=m.stack+0x1fc08;wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,node);u.emu_start(0x1403c07b0,m.stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,properties=props_out(),charges=si(item+0x388),stackSize=si(item+0x454),priceDirty=si(item+0x398),releaseFlag=si(node+0x9c),start=[si(node+0x70)&0xffffffff,si(node+0x78)&0xffffffff],actor={str(off):si(actor+off) for off in [0x740,0x748,0x828,0x218,0x214,0x224,0x228,0x818,0x820,0x824]},point=xyz(actor+0x208),meta=u.mem_read(actor+0x22d,1)[0],feat=int.from_bytes(u.mem_read(actor+0x23c,2),'little'))
cases=[dict(baseItem=b,elapsed=t,model=model,pc=pc,difficulty=d,started=started) for b,t,model,pc,d,started in itertools.product([49,104,54,75,81,50],[0,499,500,749,750,1499,1500,1999,2000,2499,2500,3500],['P','F','S','p'],[0,1],[0,1],[0,2])]
cases += [dict(baseItem=b,elapsed=4000,cost=cost,charges=charges,plot=plot,others=others) for b,cost,charges,plot,others in itertools.product([49,54,75,104,50,81],range(1,15),[0,1,4,5,6],[0,1],[[],[dict(type=15,costValue=6,remaining=1,usesPerDay=0)],[dict(type=1,costValue=2,remaining=1,usesPerDay=0)]])]
cases += [dict(elapsed=t,cost=cost,remaining=r,daily=d,stackSize=stack) for t,cost,r,d,stack in itertools.product([0,750],[1,2,7,8,12,13],[0,1,-1],[0,1,2],[0,1,2,256])]
cases += [dict(**{key:v}) for key,values in {'dead':[1,2],'dying':[1,2],'item':[False],'property':[False],'targetExists':[False],'targetCreature':[False],'spell':[False],'index':[-1,255,256],'activated':[-1,2],'impactDone':[1,-1],'consume':[0,-1],'tableFound':[0],'startDay':[0],'targetId':[0x7f000000],'children':[1],'masterId':[99]}.items() for v in values]
cases += [dict(children=1,variant=v,childMissing=missing,elapsed=t) for v,missing,t in itertools.product([-1,255,256,257],[False,True],[0,750,4000])]
cases += [dict(startDay=0,startTime=0,dead=d) for d in [0,1]]+[dict(baseItem=104,masterId=99,elapsed=t,model=model) for t,model in itertools.product([0,750],['P','S'])]+[dict(rulesOverrides={'FAST_SPELLCAST_ROUND':875},castTime=0xffffffff,baseItem=b,elapsed=1500) for b in [49,50,54]]
out=m.root/'backups/animations/native-item-cast-action-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=[run(c) for c in cases]))+'\n');print(json.dumps(dict(cases=len(cases),output=str(out))))
