"""Full LearnScroll140396b80, item-menu callback1409a81e0, inventory
input455f50 subtype13 and client inventory79f150 reply14. Canonical lookup/repository membership, active metadata,
spellbook queries/mutation, item removal/destructor, GUI transport/reply,
allocation, item-widget refresh and feedback are captured boundaries. No native heap/packet claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,item,owner,repo,stats,base,app,rules,spell,prop,schoolTable,message,client,context,transport,vt=[m.heap+n*0x1000 for n in range(1,17)];classes=m.heap+0x20000
def text(ptr):
 b=b''
 while ptr and len(b)<100:
  v=bytes(u.mem_read(ptr+len(b),1))
  if v==b'\0':break
  b+=v
 return b.decode('ascii')
def hook(u,a,n,_):
 global allocation,overflowIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP);index=y&255
 if a in [0x14055b6c0,0x1406abc80]:calls.append(['item',y&0xffffffff]);m.finish(0 if c.get('missingItem') else item)
 elif a==0x1404686d0:calls.append(['activeProperty',y&0xffffffff]);m.finish(0 if c.get('missingProperty') else prop)
 elif a==0x1401a7010:
  column=text(m.q(z));assert column in ['SpellIndex','Opposition'];row=y&0xffffffff;calls.append(['table',column,row]);m.wi(w,c.get('spellId',100) if column=='SpellIndex' else c.get('opposition',2));m.finish(c.get('oppositionStatus',1) if column=='Opposition' else c.get('spellStatus',1))
 elif a==0x1402af4a0:calls.append(['spell',y&0xffffffff]);m.finish(0 if c.get('missingSpell') else spell)
 elif a==0x14055b4c0:calls.append(['owner',y&0xffffffff]);m.finish(0 if c.get('missingOwner') else owner)
 elif a==m.stop+0x100:calls.append(['asCreature']);m.finish(owner)
 elif a==m.stop+0x108:calls.append(['asItem']);m.finish(owner)
 elif a==0x140468bd0:calls.append(['contains',bool(x),z&0xffffffff]);m.finish(c.get('contains',1))
 elif a==0x1403fa4a0:m.finish(index)
 elif a==0x1402af530:calls.append(['level',index]);m.finish(records[index].get('level',2))
 elif a==0x140408120:calls.append(['gain',index,z&255]);m.finish(records[index].get('gain',1))
 elif a==0x140408b70:calls.append(['ability',index,z&255]);m.finish(records[index].get('ability',1))
 elif a==0x1404069d0:calls.append(['school',index]);m.finish(records[index].get('school',0))
 elif a==0x140405730:calls.append(['knownCount',index,z&255]);m.finish(len(known[index]))
 elif a==0x140403420:calls.append(['known',index,z&255,w&255]);m.finish(known[index][w&255])
 elif a==0x1403ef2e0:calls.append(['addKnown',index,z&0xffffffff]);known[index].append(z&0xffffffff);m.finish()
 elif a==0x1403d7490:calls.append(['remove',z&0xffffffff,w&0xffffffff,m.si(rsp+0x28),m.si(rsp+0x30)]);m.finish(c.get('removeResult',1))
 elif a==m.stop+0x110:calls.append(['destroyItem',y&255]);m.finish()
 elif a in [0x140c10324,0x140c10368]:ptr=allocation;allocation+=(x+15)&~15;m.finish(ptr)
 elif a==0x140c10370:m.finish()
 elif a==0x1402da730:feedbackData[x]=z&0xffffffff;calls.append(['feedbackInteger',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1403a2480:calls.append(['feedback',y&65535,feedbackData.get(z)]);m.finish()
 elif a==0x1406abf90:calls.append(['transport']);m.finish(0 if c.get('missingTransport') else transport)
 elif a==0x1407c0ee0:calls.append(['send',y&0xffffffff]);m.finish()
 elif a==0x1402d9460:values=c.get('overflows',[0,0]);value=values[min(overflowIndex,len(values)-1)];overflowIndex+=1;calls.append(['overflow',value]);m.finish(value)
 elif a==0x1402d9520:calls.append(['underflow',c.get('underflow',0)]);m.finish(c.get('underflow',0))
 elif a==0x140476130:calls.append(['readObject']);m.finish(20)
 elif a==0x14055b810:calls.append(['message']);m.finish(message)
 elif a==0x1404ba840:calls.append(['clientObject']);m.finish(actor)
 elif a==m.stop+0x118:calls.append(['asCreature']);m.finish(0 if c.get('missingCreature') else actor)
 elif a==0x140396b80 and kind=='input':calls.append(['learn',y&0xffffffff]);m.finish(c.get('learnResult',1))
 elif a==0x1404da710:calls.append(['reply',y&0xffffffff,z&0xffffffff,w&255]);m.finish()
 elif a==0x1409737c0:calls.append(['readObject']);m.finish(20)
 elif a==0x1402d9600:calls.append(['readBool']);m.finish(c.get('alternate',0))
 elif a==0x1406abbe0:calls.append(['inventory']);m.finish(context)
 elif a==0x1406ac1a0:calls.append(['controlled']);m.finish(actor)
 elif a==0x1406abfd0:calls.append(['alternateInventory']);m.finish(context)
 elif a==0x1406ab9e0:calls.append(['creature',y&0xffffffff]);m.finish(actor)
 elif a==0x1406abb70:calls.append(['objectArray']);m.finish(0 if c.get('missingArray') else app)
 elif a==0x1406abb60:calls.append(['object',y&0xffffffff]);m.finish(0 if c.get('missingItem') else item)
 elif a==m.stop+0x120:calls.append(['asItem']);m.finish(0 if c.get('wrongType') else item)
 elif a==0x14076b760:calls.append(['refreshItem']);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in [(0x140396b80,0x140397040),(0x1409a81e0,0x1409a823a),(0x140455f50,0x140456d2c),(0x14079f150,0x14079fab8)]):raise AssertionError(f'Uncaptured scroll dependency {a:x} {kind} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,which='learn'):
 global c,kind,allocation,calls,known,records,feedbackData,overflowIndex
 c=case;kind=which;allocation=m.heap+0x70000;calls=[];feedbackData={};overflowIndex=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(app,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,rules);m.wq(rules+0x148,rules);m.wq(rules+0xd0,rules);m.wq(rules+0x110,classes);m.wq(rules+0x290,schoolTable);m.wq(actor+0xad0,stats);m.wi(actor+8,10);m.wi(item+0x40,c.get('baseItem',75));m.wi(item+0x3c8,30);m.wi(item+0x454,c.get('stackSize',2));m.wi(item+0x240,7);m.wi(context+0x7f8,20);m.wi(client+0x48,123);m.wi(owner+0x3c8,c.get('bagOwner',10));u.mem_write(owner+0xc,bytes([c.get('ownerType',5)]));m.wq(owner+0x958,repo);m.wq(owner+0x3d0,repo);m.wq(owner,vt);m.wq(vt+0x60,m.stop+0x100);m.wq(vt+0x70,m.stop+0x108);m.wq(item,vt+0x200);m.wq(vt+0x200,m.stop+0x110);m.wq(actor,vt+0x300);m.wq(vt+0x360,m.stop+0x118);u.mem_write(prop+2,struct.pack('<H',c.get('subtype',77)&65535));u.mem_write(spell+0x29,bytes([c.get('spellSchool',2)]))
 records=c.get('classes',[dict(learn=c.get('canLearn',1),level=c.get('level',2),gain=c.get('gain',1),ability=c.get('ability',1),school=c.get('school',0),known=c.get('known',[]))]);known=[r.get('known',[]).copy() for r in records];u.mem_write(stats+0xd8,bytes([len(records)&255]))
 for i,r in enumerate(records):m.wi(classes+i*0x530+0x4fc,r.get('learn',1))
 m.wi(context+0x2f68,10);m.wq(vt+0x268,m.stop+0x120)
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);args=[actor,20,0] if which=='learn' else [context,0,0] if which=='menu' else [message,14,0] if which=='reply' else [message,client,13]
 for reg,value in zip([UC_X86_REG_RSP,UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[rsp,*args]):u.reg_write(reg,value)
 try:u.emu_start(dict(learn=0x140396b80,menu=0x1409a81e0,input=0x140455f50,reply=0x14079f150)[which],m.stop,count=200000)
 except Exception as error:raise AssertionError(f'Scroll {which} {c} RIP{u.reg_read(UC_X86_REG_RIP):x} calls{calls}') from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,known=known,stackSize=m.si(item+0x454),pending=m.si(item+0x240),**(dict(result=u.reg_read(UC_X86_REG_RAX)&0xffffffff) if which!='menu' else {}))
cases=[dict(level=level,gain=gain,ability=ability,school=school,known=known,stackSize=stack,oppositionStatus=status,opposition=opposition) for level,gain,ability,school,known,stack,status,opposition in itertools.product([2,255],[0,1],[0,1],[0,1],[[],[100],[1,2,100]],[-1,1,3],[0,1,2],[2,3])]
cases += [dict(**{key:value}) for key,values in {'missingItem':[True],'baseItem':[49,0,75],'missingProperty':[True],'missingSpell':[True],'missingOwner':[True],'ownerType':[6,9,14],'bagOwner':[11],'contains':[0],'canLearn':[0],'classes':[[],[dict(learn=0),dict(level=255),dict(known=[100])],[dict(known=[100]),dict(known=[])],[dict(known=[]),dict(known=[100])],[dict(known=[]),dict(known=[])]],'spellStatus':[0],'spellId':[0xffffffff,0x80000001],'removeResult':[0]}.items() for value in values]
cases += [dict(ownerType=6,bagOwner=id,stackSize=stack) for id,stack in itertools.product([10,11],[1,2])]
cases += [dict(known=list(range(200,460)),spellId=spellId) for spellId in [100,455,456]]
menus=[dict(missingItem=missing,missingTransport=transport) for missing,transport in itertools.product([False,True],[False,True])]
inputs=[dict(overflows=overflow,underflow=underflow,missingCreature=creature,learnResult=result) for overflow,underflow,creature,result in itertools.product([[0,0],[1,0],[0,1]],[0,1],[False,True],[0,1])]
replies=[dict(alternate=alternate,overflows=overflow,underflow=underflow,missingItem=missing,wrongType=wrong,missingArray=array) for alternate,overflow,underflow,missing,wrong,array in itertools.product([0,1],[[0,0],[1,0],[0,1]],[0,1],[False,True],[False,True],[False,True])]
out=m.root/'backups/animations/native-scroll-learning-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,learn=[run(c) for c in cases],menu=[run(c,'menu') for c in menus],input=[run(c,'input') for c in inputs],reply=[run(c,'reply') for c in replies]))+'\n');print(json.dumps(dict(learn=len(cases),menu=len(menus),input=len(inputs),reply=len(replies),output=str(out))))
