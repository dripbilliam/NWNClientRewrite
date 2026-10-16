"""Unchanged Rest39f360, AIActionRest3ca890 and CancelRest386940.
Captured external owners: dead/dying/possession, canonical lookup, rules,
message/event allocation, action queue/managers, effects, timing bar,
HP virtual getters, resource restoration, animation and encumbrance.
Not a lower-owner integration, packet or native GUI equivalence claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,area,app,rules,table,node,module,event,vt,client,timer=[m.heap+n*0x1000 for n in range(1,13)]
fields={0x854:'healInterval',0x858:'missingHP',0x85c:'spellInterval',0x860:'spellCursor',0xad8:'startDay',0xadc:'startTime',0x558:'enemyDay',0x55c:'enemyTime',0xe0:'hp',0x8e0:'activities'}
def floatreg(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x140495620:calls.append(['dying']);m.finish(c.get('dying',0))
 elif a==0x1403d54d0:calls.append(['possessed']);m.finish(c.get('possessed',0))
 elif a==0x140494e80:calls.append(['area']);m.finish(0 if c.get('missingArea') else area)
 elif a==0x1402ae870:m.finish(0x140dd0000)
 elif a==0x1402a40d0:calls.append(['radius']);u.reg_write(UC_X86_REG_XMM0,struct.unpack('<I',struct.pack('<f',c.get('radius',30)))[0]);m.finish()
 elif a==0x140392220:calls.append(['enemy',m.si(x+8),floatreg(UC_X86_REG_XMM1),z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish(c.get('enemy',0x7f000000))
 elif a==0x140490b80:calls.append(['clearActions']);m.finish()
 elif a==0x1403a2650:
  calls.append(['activity',y&0xffffffff,z&0xffffffff]);mask=y&0xffffffff
  if m.si(x+0x8e4)&mask!=mask:m.wi(x+0x8e0,m.si(x+0x8e0)|mask if z==1 else m.si(x+0x8e0)&~mask)
  m.finish()
 elif a==0x1403a2480:calls.append(['feedback',y&65535]);m.finish()
 elif a in [0x14037cbc0,0x14037cc30]:calls.append(['actionManager' if a==0x14037cbc0 else 'activityManager',y&0xffffffff]);m.finish()
 elif a==0x1404998a0:calls.append(['runRestScript',y&0xffffffff]);m.finish()
 elif a==0x14048cb80:calls.append(['queue',y&0xffffffff,z&65535,w&0xffffffff,m.si(m.q(rsp+0x28)),m.si(rsp+0x30),m.si(m.q(rsp+0x38))]);m.finish()
 elif a==0x14055b6e0:m.finish(module)
 elif a==0x14055b960:m.finish(app)
 elif a==0x1404c6490:m.finish(x)
 elif a==0x1404c72e0:m.wi(x+0x40,z);m.finish()
 elif a==0x140556eb0:calls.append(['restEvent',m.si(m.q(rsp+0x38)+0x40)]);m.finish()
 elif a==0x1405570b0:calls.append(['removeLater',m.si(m.q(rsp+0x38))]);m.finish()
 elif a in [0x14055b2c0,0x14055ba10]:m.finish(timer)
 elif a==0x140597180:m.wi(y,c.get('day',1));m.wi(z,c.get('time',10000));m.finish()
 elif a==0x140597a20:
  m.wi(m.q(rsp+0x30),0);m.wi(m.q(rsp+0x38),(z-m.si(rsp+0x28))&0xffffffff);m.finish()
 elif a==0x140491110:calls.append(['clearEffectsOnOthers']);m.finish()
 elif a==0x1403822d0:calls.append(['poison',m.si(y)]);m.finish()
 elif a==0x140381ab0:calls.append(['disease',m.si(y)]);m.finish()
 elif a==0x1404035c0:m.finish(c.get('level',5))
 elif a==0x1401a7010:calls.append(['duration']);m.wi(w,c.get('duration',10000));m.finish(1)
 elif a==0x1403a5180:calls.append(['startTiming',y&0xffffffff,z&255]);m.finish()
 elif a==0x1403a5210:calls.append(['stopTiming']);m.finish()
 elif a==0x14055b390:m.finish(0 if c.get('missingClient') else client)
 elif a==0x14055b810:m.finish(0 if c.get('missingMessage') else app)
 elif a==0x1404da310:calls.append(['stopTiming']);m.finish()
 elif a==0x14055b590:m.finish(0 if c.get('missingClient') else client)
 elif a==0x14055b3d0:
  calls.append(['creature',y&0xffffffff]);m.finish(0 if c.get('missingCreature') else m.heap+0x20000+(y&255)*0x1000)
 elif a==0x14039f360 and kind in ['execute','input']:calls.append(['rest',m.si(x+8),y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1404ba840:calls.append(['clientObject']);m.finish(0 if c.get('missingObject') else actor)
 elif a==m.stop+0x120:calls.append(['asCreature']);m.finish(0 if c.get('wrongType') else actor)
 elif a==0x1402d9460:calls.append(['overflow',c.get('overflow',0)]);m.finish(c.get('overflow',0))
 elif a==0x140390060:calls.append(['activityState',y&0xffffffff]);m.finish(int((m.si(x+0x8e0)&y)!=0))
 elif a==0x1403d7160:calls.append(['removeDomination',m.si(x+8)]);m.finish()
 elif a==0x140386940 and kind=='execute':calls.append(['cancel',y&65535]);m.finish()
 elif a==0x140402950:calls.append(['highest']);m.finish(c.get('highest',4))
 elif a==0x1404123b0:calls.append(['readyLevel',y&255]);m.finish()
 elif a==0x14039e020:calls.append(['removeBadEffects']);m.finish()
 elif a==0x14039f760:calls.append(['restoreItems']);m.finish()
 elif a==0x140412b10:calls.append(['resetFeats']);m.finish()
 elif a==0x140412b50:calls.append(['resetAbilities']);m.finish()
 elif a==0x1403db1e0:calls.append(['encumbrance',y&0xffffffff]);m.finish()
 elif a==0x140491570:calls.append(['deleteCurrent',m.si(x+8)]);m.finish()
 elif a==m.stop+0x100:calls.append(['animation',m.si(x+8),y&0xffffffff]);m.finish()
 elif a==m.stop+0x108:m.finish(c.get('maxHP',20)&65535)
 elif a==m.stop+0x110:m.finish(m.si(x+0xe0)&65535)
 elif a==m.stop+0x118:m.finish(x)
 elif a in [0x140c10324,0x140c10368]:ptr=allocation;allocation+=(x+15)&~15;m.finish(ptr)
 elif a==0x140c10370:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in [(0x14039f360,0x14039f740),(0x1403ca890,0x1403cb8f9),(0x140386940,0x140386b0f),(0x1404531b0,0x1404557a4)]):raise AssertionError(f'Uncaptured rest dependency {a:x} {kind} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,which):
 global c,kind,calls,allocation
 c=case;kind=which;calls=[];allocation=m.heap+0xb0000;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(0x14141e310,b'\0\0');m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,table);m.wq(table+0x2c8,table);m.wq(actor+0xad0,stats);m.wi(actor+8,10);m.wi(module+0x30,99);m.wq(actor,vt);m.wq(vt+0x100,m.stop+0x100);m.wq(vt+0x130,m.stop+0x108);m.wq(vt+0x138,m.stop+0x110)
 for offset,key,default in [(0x89c,'pc',1),(0x8fc,'masterId',0x7f000000),(0x574,'excited',0),(0x8e4,'locks',0),(0x8ac,'field8ac',0),(0xec,'commandable',1)]:m.wi(actor+offset,c.get(key,default))
 m.wq(vt+0x60,m.stop+0x120)
 for offset,key in fields.items():m.wi(actor+offset,c.get(key,5 if key=='hp' else 16 if key=='activities' else 0))
 u.mem_write(actor+0x908,struct.pack('<H',c.get('associateType',0)));m.wi(area+0x100,c.get('noRest',0));m.wi(node+0x38,c.get('player',1));m.wi(node+0x40,c.get('started',0))
 effects=c.get('effects',[1,5,35,67]);m.wq(actor+0x150,m.heap+0xe000);m.wi(actor+0x158,len(effects))
 for i,type in enumerate(effects):ptr=m.heap+0xf000+i*0x200;m.wq(m.heap+0xe000+i*8,ptr);m.wi(ptr,i+1);u.mem_write(ptr+8,struct.pack('<H',type))
 associates=c.get('associates',[])
 if associates:
  m.wq(actor+0x900,m.heap+0xd000);m.wq(m.heap+0xd000,m.heap+0xd100);m.wi(m.heap+0xd008,len(associates))
  for i,type in enumerate(associates):id=i+20;m.wi(m.heap+0xd100+i*4,id);ptr=m.heap+0x20000+id*0x1000;m.wi(ptr+8,id);u.mem_write(ptr+0x908,struct.pack('<H',type));m.wi(ptr+0x8fc,10);m.wq(ptr,vt);m.wq(vt+0x20,m.stop+0x118)
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);args=[actor,c.get('associate',0),c.get('seen',0)] if which=='request' else [actor,c.get('reason',20),0] if which=='cancel' else [actor,node,0]
 if which=='input':args=[app,client,13]
 for reg,value in zip([UC_X86_REG_RSP,UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[rsp,*args]):u.reg_write(reg,value&0xffffffffffffffff)
 try:u.emu_start(dict(request=0x14039f360,execute=0x1403ca890,cancel=0x140386940,input=0x1404531b0)[which],m.stop,count=200000)
 except Exception as error:raise AssertionError(f'{which} {c} RIP{u.reg_read(UC_X86_REG_RIP):x} calls{calls}') from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 out=dict(case=c,calls=calls,state={key:m.si(actor+offset)&0xffffffff for offset,key in fields.items()},started=m.si(node+0x40))
 if which in ['execute','input']:out['result']=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return out
requests=[dict(pc=pc,possessed=possessed,associate=associate,associateType=type,noRest=noRest,excited=excited,enemy=enemy,activities=11,locks=locks) for pc,possessed,associate,type,noRest,excited,enemy,locks in itertools.product([0,1],[0,1],[0,1],[0,3],[0,2],[0,50],[0x7f000000,20],[0,1,2,8,16])]
requests += [dict(**{key:value}) for key,values in {'dead':[1],'dying':[1],'missingArea':[True],'masterId':[20],'missingCreature':[True],'seen':[-1,1,2],'radius':[5.5],'associate':[2],'excited':[-1]}.items() for value in values]
executions=[dict(started=started,time=time,duration=duration,hp=hp,highest=highest,startDay=1,startTime=1000,enemyDay=1,enemyTime=time-200) for started,time,duration,hp,highest in itertools.product([0,1],[1000,2000,4500,8000,11000],[9000,15000],[5,20,25],[0,1,4,9])]
executions += [dict(**{key:value}) for key,values in {'dead':[1],'dying':[1],'noRest':[1],'excited':[1],'player':[0],'pc':[0],'associateType':[1,2,3,4,5],'missingClient':[True],'enemy':[20],'activities':[0],'associates':[[0,1,2,3,4,5,6,7]],'effects':[[],[35,35],[5,5],[67]],'healInterval':[1,40],'missingHP':[1,15],'spellInterval':[1,1000],'spellCursor':[1,9]}.items() for value in values]
executions += [dict(player=player,pc=0,associateType=type,masterId=master,started=1,time=10000,startTime=1000,startDay=1) for player,type,master in itertools.product([0,1],[0,1,2,3,4],[0x7f000000,10])]
cancels=[dict(pc=pc,possessed=possessed,missingClient=client,missingMessage=message,reason=reason,associates=associates) for pc,possessed,client,message,reason,associates in itertools.product([0,1],[0,1],[False,True],[False,True],[20,186,65537],[[],[0,1,1,2,3,4]])]
inputs=[dict(missingObject=missing,wrongType=wrong,overflow=overflow,field8ac=field,commandable=commandable,activities=activities) for missing,wrong,overflow,field,commandable,activities in itertools.product([False,True],[False,True],[0,1],[0,1],[0,1,-1],[0,16])]
out=m.root/'backups/animations/native-rest-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,request=[run(c,'request') for c in requests],execute=[run(c,'execute') for c in executions],cancel=[run(c,'cancel') for c in cancels],input=[run(c,'input') for c in inputs]))+'\n');print(json.dumps(dict(request=len(requests),execute=len(executions),cancel=len(cancels),input=len(inputs),output=str(out))))
