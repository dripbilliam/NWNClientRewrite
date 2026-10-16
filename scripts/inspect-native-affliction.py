"""Complete original poison/disease apply and payload owners. Original copy
constructor/assignment and effect equality execute, unlike a structural-copy
stub. Captured lower providers: base construction/allocation/string operations,
active 2DA queries, dice, saves, immunity, nested apply/events/scripts and clocks.
Synthetic data only; not lower combat/effect application or scene acceptance.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,source,effect,ints,pool,vt,app,rules,stats,timer,module,ptable,dtable=[m.heap+n*0x1000 for n in range(13)]
ranges=[(0x14042fce0,0x14043094b),(0x14042c1f0,0x14042c713),(0x1403822d0,0x140382569),(0x140381ab0,0x1403822c5),(0x140423570,0x140423768),(0x140423ce0,0x140423f86),(0x140423ac0,0x140423cb5),(0x140423fc0,0x140423fcb),(0x140425210,0x14042521c),(0x140596b40,0x140596b80),(0x140596e50,0x140596e83),(0x14051ac50,0x14051ad2e),(0x140519be0,0x140519cbe),(0x14038a810,0x14038a927),(0x14049dd55,0x14049de8f)]

def text_at(ptr):
 if not ptr:return ''
 return bytes(u.mem_read(ptr,512)).split(b'\0')[0].decode('cp1252')

def string_at(ptr):
 value=m.q(ptr);size=m.si(ptr+8)
 return bytes(u.mem_read(value,size)).decode('cp1252')if value else''

def allocate(size):
 global allocation
 target=m.heap+0x30000+allocation;allocation+=(size+15)&~15;assert allocation<0x60000;return target

def store_string(ptr,value):
 value=value.encode('cp1252');target=allocate(len(value)+1)
 u.mem_write(target,value+b'\0');m.wq(ptr,target if value else 0);m.wi(ptr+8,len(value))

def snapshot(ptr):
 flags=int.from_bytes(u.mem_read(ptr+10,2),'little')
 return dict(id=f'{m.q(ptr):016x}',type=int.from_bytes(u.mem_read(ptr+8,2),'little'),subtype=flags&~7,durationType=flags&7,duration=m.rf(ptr+12),creatorId=m.si(ptr+24)&0xffffffff,spellId=m.si(ptr+28),casterLevel=m.si(ptr+40),showIcon=m.si(ptr+36),exposed=m.si(ptr+32),bypassImmunity=m.si(ptr+0x108),propertyId=f'{m.q(ptr+0xf0):016x}',customTag=string_at(ptr+0xf8),integers=[m.si(m.q(ptr+0x48)+i*4)for i in range(m.si(ptr+0x40))],strings=[string_at(ptr+0x60+i*16)for i in range(6)])

def hook(u,a,n,_):
 global allocation,ids,rolls,pushed
 if a==m.stop:u.emu_stop();return
 if c.get('pollSupport')and a in [0x14049e046,0x14049e04a]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(actor if c.get('objectType',5)==5 else 0)
 elif c.get('pollSupport')and a in [0x1403822d0,0x140381ab0]:calls.append(['poisonPayload'if a==0x1403822d0 else'diseasePayload',z&0xffffffff,w&0xffffffff]);m.finish()
 elif c.get('pollSupport')and a==0x140596e50:calls.append(['compare',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff])
 elif a==0x1404953b0:m.finish(c.get('dead',0))
 elif a==0x14055b3d0:m.finish(source if c.get('sourceExists',True)else 0)
 elif a==0x140400ab0:calls.append(['immunity',y&255]);m.finish(c.get('immunity',0))
 elif a in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif a==0x1404233d0:
  ids+=int(y!=0);m.wq(x,100+ids if y else 0);m.wq(x+0x48,allocate(32));m.wi(x+0x40,8);m.wi(x+0x20,int(y!=0));m.wi(x+0x24,1);m.wi(x+0x1c,-1);m.wi(x+0x28,-1);m.wi(x+0x18,0x7f000000)
  for i in range(4):m.wi(x+0xc0+i*4,0x7f000000)
  m.finish(x)
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a in [0x140c10370,0x140423770,0x140c10360,0x140c11414,0x14037bd50]:m.finish()
 elif a==0x140047300:u.mem_write(x,bytes(12));m.finish(x)
 elif a==0x140c42060:u.mem_write(x,bytes(z));m.finish(x)
 elif a==0x140425110:m.wi(x+0x18,y);m.finish()
 elif a==0x140286110:m.wi(y,c['constructorInput']);m.finish(1)
 elif a==0x140286330:pushed=snapshot(z);m.finish(1)
 elif a==0x14003d8c0:store_string(x,bytes(u.mem_read(y,z)).decode('cp1252'));m.finish(x)
 elif a==0x140424690:m.finish(x+0x60+y*16)
 elif a==0x140425310:store_string(x+0x60+y*16,string_at(z));m.finish()
 elif a==0x140169e90:m.finish(int(string_at(x)!=string_at(y)))
 elif a==0x14048e350:calls.append(['apply',snapshot(y),z&0xffffffff]);m.finish(0)
 elif a==0x1402da770:messages[x]=dict(objectIds=[z&0xffffffff]);m.finish()
 elif a==0x1402da730:messages[x].setdefault('integers',[0]*10)[y]=z if z<0x80000000 else z-0x100000000;m.finish()
 elif a==0x1402d5210:messages[y]=dict(messages[x]);m.finish()
 elif a==0x1403a2480:calls.append(['feedback',99 if x==actor else 98,y&65535,messages[z]]);m.finish()
 elif a==0x14038a810 and not c.get('feedbackSupport'):calls.append(['self',y&0xffffffff]);m.finish()
 elif a==0x140439ae0:calls.append(['floaty',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a in [0x1401a7010,0x1401a68f0]:
  kind='poison'if x==ptable else'disease';column=string_at(z);value=c.get('table',{}).get(column);found=value is not None
  if a==0x1401a7010:value=int(value)if found else 0;m.wi(w,value);calls.append(['int',kind,y&0xffffffff,column,int(found),value])
  else:value=str(value)if found else'';store_string(w,value);calls.append(['str',kind,y&0xffffffff,column,int(found),value])
  m.finish(int(found))
 elif a==0x1402ad680:rolls+=1;calls.append(['roll',y&255,z&255]);m.finish(c.get('roll',7)+rolls-1)
 elif a==0x1403ec600:
  calls.append(['save',y&255,z&65535,w&255,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),m.si(rsp+0x38)&65535,m.si(rsp+0x40)]);m.finish(c.get('save',0))
 elif a in [0x14055ba10,0x14055b2c0]:m.finish(timer)
 elif a==0x14055b6e0:m.finish(module)
 elif a==0x140597180:calls.append(['time']);m.wi(y,c.get('day',2));m.wi(z,c.get('time',100));m.finish()
 elif a==0x140596b40:calls.append(['addTime',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff])
 elif a==0x14055b960:m.finish(app)
 elif a==0x14055b390:
  calls.append(['client',y&0xffffffff]);m.finish(m.heap+0x20000 if y==99 and c.get('direct')else m.heap+0x20100 if y==98 and c.get('master')else 0)
 elif a==0x14055b810:m.finish(app)
 elif a==0x1404cf090:calls.append(['send',y&0xffffffff,z&255,messages[w]]);m.finish()
 elif a==0x1405570b0:calls.append(['event',m.si(rsp+0x30),snapshot(m.q(rsp+0x38))]);m.finish(1)
 elif a==0x140283990:
  calls.append(['script',string_at(y),z&0xffffffff]);mode=c.get('scriptMutation')
  if mode=='remove':m.wi(actor+0x158,0)
  elif mode=='mutate':m.wi(ints,99)
  elif mode=='replace':
   replacement=m.heap+0x18000;u.mem_write(replacement,bytes(u.mem_read(effect,0x110)));replacement_ints=allocate(32);u.mem_write(replacement_ints,bytes(u.mem_read(ints,32)));m.wq(replacement+0x48,replacement_ints)
   for i in range(6):store_string(replacement+0x60+i*16,string_at(effect+0x60+i*16))
   m.wq(pool,replacement);m.wi(actor+0x158,1)
  m.finish(1)
 elif a==0x14016c810:store_string(x,str(y&0xffffffff));m.finish(x)
 elif a==0x14016ab00:store_string(y,string_at(x)+string_at(z));m.finish(y)
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unexpected affliction dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,allocation,ids,rolls,messages
 c=case;calls=[];allocation=ids=rolls=0;messages={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,app);m.wq(app+0x130,rules);m.wq(rules+0x298,ptable);m.wq(rules+0x2a0,dtable)
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wi(actor+8,99);m.wi(source+8,98);m.wq(actor+0xad0,stats);m.wi(actor+0xfc,c.get('plot',0));m.wi(timer+0x30,1000000);u.mem_write(module+0x3b8,bytes([c.get('minutes',5)]))
 m.wq(effect,77);m.wq(effect+0x48,ints);m.wi(effect+0x40,8);u.mem_write(effect+8,struct.pack('<HH',c.get('type',35 if c['mode'].startswith('poison')else 5),c.get('subtype',8)|(c.get('durationType',0)&7)));m.wf(effect+12,3.25);m.wi(effect+0x20,c.get('exposed',1));m.wi(effect+0x24,c.get('showIcon',1));m.wi(effect+0x18,98);m.wi(effect+0x1c,11);m.wi(effect+0x28,7);m.wi(effect+0x108,c.get('bypass',0));m.wq(effect+0xf0,123)
 for i in range(4):m.wi(effect+0xc0+i*4,0x7f000000)
 for i,value in enumerate(c.get('integers',[0]*8)):m.wi(ints+i*4,value)
 store_string(effect+0x60,c.get('inputScript',''))
 effects=c.get('effects',[])
 if c['mode'].endswith('Payload'):m.wq(pool,effect);m.wi(actor+0x158,1)
 else:
  m.wi(actor+0x158,len(effects))
  for i,typ in enumerate(effects):ptr=m.heap+0x15000+i*0x100;u.mem_write(ptr+8,struct.pack('<H',typ));m.wq(pool+i*8,ptr)
 m.wq(actor+0x150,pool)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 entry={'poison':0x14042fce0,'disease':0x14042c1f0,'poisonPayload':0x1403822d0,'diseasePayload':0x140381ab0}[c['mode']]
 args=[actor,effect,c.get('day',2),c.get('time',100)]if c['mode'].endswith('Payload')else[app,actor,effect,c.get('loading',0)]
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 try:u.emu_start(entry,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,effect=snapshot(effect),liveEffects=[snapshot(m.q(pool+i*8))for i in range(m.si(actor+0x158))]if c['mode'].endswith('Payload')else[])

poison={'Dice_1':4,'Dam_1':2,'Save_DC':17,'Default_1':'STR','Script_1':'','Dice_2':6,'Dam_2':1,'Default_2':'CON','Script_2':''}
disease={'First_Save':18,'Name':123,'Incu_Hours':1,'Subs_Save':19,'Dice_1':4,'Dam_1':1,'Type_1':2,'Dice_2':None,'Dam_2':None,'Type_2':None,'End_Incu_Script':'','24_Hour_Script':''}
rows=[]
for mode,loading,dead,duration,plot,immunity,bypass in itertools.product(['poison','disease'],[0,1],[0,1],[0,1,2,3,4],[0,1],[0,1,2],[0,1]):rows.append(run(dict(mode=mode,table=poison if mode=='poison'else disease,loading=loading,dead=dead,durationType=duration,plot=plot,immunity=immunity,bypass=bypass)))
for save,primary,secondary,script in itertools.product([0,1],['STR','DEX','CON','INT','WIS','CHA','str','unknown','STR\0tail'],['STR','CHA','other'],['','fixture']):rows.append(run(dict(mode='poison',table={**poison,'Default_1':primary,'Default_2':secondary,'Script_1':script,'Script_2':script},save=save)))
for mode,save,duration in itertools.product(['poisonPayload','diseasePayload'],[0,1],[0,1,2,3,4]):rows.append(run(dict(mode=mode,table=disease,save=save,durationType=duration,integers=[0,1,0,17,2,100,0,0],inputScript='fixture')))
for mode,effects,objectType in itertools.product(['poison','disease'],[[],[5],[35],[67,35,5]],[5,6]):rows.append(run(dict(mode=mode,table=poison if mode=='poison'else disease,effects=effects,objectType=objectType)))
for custom,save,time in itertools.product([[0,2,3,4,17,0,0,0],[0,0,0,0,1,0,0,0]],[0,1],[100,990000]):rows.append(run(dict(mode='poison',table=poison,integers=custom,save=save,time=time)))
for mode,exposed in itertools.product(['poison','disease'],[0,2,-1]):rows.append(run(dict(mode=mode,table=poison if mode=='poison'else disease,exposed=exposed)))
for mode,immunity,bypass in itertools.product(['poison','disease'],[0,1],[0,1]):rows.append(run(dict(mode=mode,table=poison if mode=='poison'else disease,sourceExists=False,immunity=immunity,bypass=bypass)))
for stage,previous,save,mutation,script in itertools.product([0,1],[0,1],[0,1],['none','remove','mutate','replace'],['','fixture']):rows.append(run(dict(mode='diseasePayload',table={**disease,'End_Incu_Script':script,'24_Hour_Script':script},integers=[0,previous,stage,2,100,0,0,0],save=save,scriptMutation=mutation)))
def raw_call(address,args,stack_args=()):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x1000,bytes(0x1100));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
 for i,value in enumerate(stack_args):m.wq(rsp+0x28+i*8,value)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 value=u.reg_read(UC_X86_REG_RAX)&0xffffffff;return value if value<0x80000000 else value-0x100000000

times=[];calls=[]
for length,day,otherday,time,othertime in itertools.product([0,1000000,0xffffffff],[2,0xffffffff],[0,1,3],[0,1,999999,0x80000000,0xfffffffe],[0,1,999999,0x80000000,0xfffffffe]):
 m.wi(timer+0x30,length);day_out,time_out=m.heap+0x21000,m.heap+0x21004;m.wi(day_out,0xfeedface);m.wi(time_out,0xdeadbeef)
 result=raw_call(0x140596b40,[timer,day,time,otherday],[othertime,day_out,time_out]);comparison=raw_call(0x140596e50,[timer,day,time,otherday],[othertime]);times.append(dict(length=length,a=dict(day=day,time=time),b=dict(day=otherday,time=othertime),status=result,day=m.si(day_out)&0xffffffff,time=m.si(time_out)&0xffffffff,comparison=comparison))

def full_snapshot(ptr):return{**snapshot(ptr),'floats':[m.rf(ptr+0x50+i*4)for i in range(4)],'objectIds':[m.si(ptr+0xc0+i*4)&0xffffffff for i in range(4)],'vectors':[[m.rf(ptr+0xd0+j*12+i*4)for i in range(3)]for j in range(2)]}

identities=[]
for change in ['same','id','type','flags','creator','spell','level','property','tag','bypass','count','integer','float','object','string','vector','duration','expiry','exposed','icon','nulString']:
 run(dict(mode='poison',loading=1,durationType=2));destination=m.heap+0x18000;raw_call(0x140423ce0,[destination,effect,0]);
 for name,offset,value in [('type',8,36),('flags',10,11)]:
  if change==name:u.mem_write(destination+offset,struct.pack('<H',value))
 for name,offset,value in [('creator',24,97),('spell',28,12),('level',40,8),('bypass',0x108,1),('count',0x40,7),('object',0xc0,99),('expiry',0x10,42),('exposed',0x20,3),('icon',0x24,7)]:
  if change==name:m.wi(destination+offset,value)
 if change=='id':m.wq(destination,78)
 if change=='property':m.wq(destination+0xf0,456)
 if change=='tag':store_string(destination+0xf8,'changed')
 if change=='integer':m.wi(m.q(destination+0x48),2)
 if change=='float':m.wf(destination+0x50,1.25)
 if change=='vector':m.wf(destination+0xd4,2)
 if change=='duration':m.wf(destination+12,7)
 if change=='string':store_string(destination+0x60,'changed')
 if change=='nulString':store_string(destination+0x60,'x\0y');store_string(effect+0x60,'x\0z')
 left,right=full_snapshot(destination),full_snapshot(effect);result=raw_call(0x140423ac0,[destination,effect]);identities.append(dict(change=change,left=left,right=right,result=result))

copies=[]
for icons,bypass in itertools.product([0,1,2],[0,1,-1]):
 run(dict(mode='poison',loading=1,durationType=2,showIcon=5,bypass=bypass,inputScript='source'))
 m.wf(effect+0x50,2);m.wf(effect+0xd4,3);store_string(effect+0xf8,'source_tag');source_value=full_snapshot(effect);destination=m.heap+0x18000;raw_call(0x140423570,[destination,effect,icons]);copies.append(dict(icons=icons,source=source_value,result=full_snapshot(destination)))

constructors=[]
for kind,value in itertools.product(['poison','disease'],[-1,0,257,0x80000001]):
 run(dict(mode='poison',loading=1));c['constructorInput']=value;command=m.heap+0x14000;m.wi(command+12,99);pushed=None;result=raw_call(0x14051ac50 if kind=='poison'else 0x140519be0,[command]);constructors.append(dict(kind=kind,value=value,result=result,effect=pushed))

self_feedback=[]
for direct,master,strref in itertools.product([0,1],[0,1],[66946,66537,0xffffffff]):
 run(dict(mode='poison',loading=1));calls=[];c.update(direct=direct,master=master,feedbackSupport=True);m.wi(actor+0x8fc,98);m.wi(m.heap+0x20048,77);m.wi(m.heap+0x20148,88);raw_call(0x14038a810,[actor,strref]);self_feedback.append(dict(direct=direct,master=master,strref=strref,calls=calls))
polls=[]
for typ,day,time,due_day,due_time,attempted,object_type in itertools.product([35,5],[2,3],[99,100,101,1000000],[2,3],[100,1000000],[0,1],[5,6]):
 run(dict(mode='poison',loading=1,type=typ,objectType=object_type,durationType=2));c['pollSupport']=True;calls=[]
 m.wi(ints+(4 if typ==35 else 3)*4,due_day);m.wi(ints+(5 if typ==35 else 4)*4,due_time);m.wi(ints+24,attempted);initial=snapshot(effect)
 rsp=m.stack+0x1fe00;u.mem_write(rsp-0x1000,bytes(0x1100));u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in [(UC_X86_REG_RAX,typ),(UC_X86_REG_R14,effect),(UC_X86_REG_R15,actor),(UC_X86_REG_RSI,timer),(UC_X86_REG_R13,day),(UC_X86_REG_RDI,time)]:u.reg_write(reg,value)
 u.emu_start(0x14049dd55,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)in [0x14049e046,0x14049e04a]
 polls.append(dict(type=typ,now=dict(day=day,time=time),objectType=object_type,initial=initial,calls=calls))
out=m.root/'backups/animations/native-affliction-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,times=times,identities=identities,copies=copies,constructors=constructors,selfFeedback=self_feedback,polls=polls),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),times=len(times),identities=len(identities),copies=len(copies),constructors=len(constructors),selfFeedback=len(self_feedback),polls=len(polls))))
