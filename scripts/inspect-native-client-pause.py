"""Original client pause receiver7a5680, internal state6e1fc0, clear6d6770,
active timer6d7fe0, exclusion6dab20 and creature reset807680. Timer reset/get
snapshot execute; pause/snapshot/unpause/time outputs, object lookup/casts,
scene/audio/GUI virtuals, scalars and allocator boundaries are captured. Tracy
is disabled. No complete raw transport, scene/GPU/audio or campaign acceptance.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
state,world,one,two,old,oldIds,incoming,incomingIds,app,profile,gui,message,vt,audio,audioOwner,audioVt,scene,sceneVt,buffer=[m.heap+n*0x2000 for n in range(19)]
entries={'set':0x1406e1fc0,'clear':0x1406d6770,'timer':0x1406d7fe0,'excluded':0x1406dab20,'receive':0x1407a5680,'reset':0x140807680}
ranges=[(0x140597040,0x140597045),(0x1406f9a90,0x1406f9a94)]
body=json.loads((m.root/'backups/animations/rea-pause-reset-timer-owner.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in body['ranges'])
for name in ['internal-owner','exclusion-reset','active-timer','is-excluded','message-receiver']:
 body=json.loads((m.root/f'backups/animations/rea-client-pause-{name}.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in body['ranges'])
body=json.loads((m.root/'backups/animations/rea-client-creature-pause-reset-time-v2.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in body['ranges'])
timers={world:'world',one:'one',two:'two'}
fields={'mode':(0,4),'fixedRate':(4,4),'counter':(8,8),'previousCounter':(16,8),'paused':(24,4),'pausedDay':(28,4),'pausedTime':(32,4),'dayOffset':(36,4),'timeOffset':(40,4),'minutesPerHour':(44,1),'dayLength':(48,4),'secondsPerDay':(52,4)}
def ids(owner):return[m.si(m.q(owner)+i*4)&0xffffffff for i in range(m.si(owner+8))]
def hook(u,a,n,_):
 global index,disposed,allocated,reallocations
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140597760:calls.append(['pause',timers[x]]);m.wi(x+24,1);m.finish()
 elif a==0x140597ba0:calls.append(['unpause',timers[x]]);m.wi(x+24,0);m.finish()
 elif a==0x140597880:calls.append(['snapshot',timers[x]]);m.wq(x+16,m.q(x+8));m.wq(x+8,m.q(x+8)+100);m.finish()
 elif a==0x1405977e0:calls.append(['reset',timers[x],timers[y]])
 elif a==0x140597040:calls.append(['sync',timers[x]])
 elif a==0x140597180:
  calls.append(['time',timers[x]]);day,time={'world':(10,100),'one':(20,200),'two':(30,300)}[timers[x]];m.wi(y,day);m.wi(z,time);m.finish()
 elif a==0x140296470:
  id=y&0xffffffff;calls.append(['object',id]);m.wq(z,objects.get(id,0));m.finish()
 elif a==0x140807680:calls.append(['resetObject',m.si(x+8)&0xffffffff,y&0xffffffff,z&0xffffffff])
 elif a==m.stop+0x10:calls.append(['asObject',m.si(x+8)&0xffffffff]);m.finish(x if c.get('asObject',True)else 0)
 elif a==0x1407630a0:calls.append(['scene',m.si(x+8)&0xffffffff]);m.finish(scene if c.get('scene',True)else 0)
 elif a in [m.stop+0x20,m.stop+0x30]:calls.append(['sceneVirtual',0x150 if a==m.stop+0x20 else 0x158]);m.finish()
 elif a==0x1406abea0:m.finish(audio)
 elif a in [m.stop+0x40,m.stop+0x50]:calls.append(['audio',a==m.stop+0x40]);m.finish()
 elif a==0x1406cb2e0:calls.append(['pauseText',y&0xffffffff]);m.finish()
 elif a==0x14008ae10:
  values=ids(x)
  if not m.q(x):m.wq(x,oldIds);m.wi(x+12,16)
  if len(values)==m.si(x+12):m.wi(x+12,max(16,m.si(x+12)*2))
  m.wi(m.q(x)+len(values)*4,y);m.wi(x+8,len(values)+1);m.finish()
 elif a in [0x140c10324,0x140c10368]:
  if x==16:allocated=True;m.finish(incoming)
  elif x==7:m.finish(buffer)
  else:raise AssertionError(f'Unknown allocation {x}')
 elif a==0x140c4f038:reallocations.append(y);m.finish(incomingIds)
 elif a in [0x140c10370,0x140c4f024,0x140c10360]:
  if x==incoming:disposed=True;calls.append(['dispose'])
  m.finish()
 elif a==0x1406f9a90:calls.append(['guiActive'])
 elif a==0x1406fae70:calls.append(['guiBlocked',y&0xffffffff]);m.finish()
 elif a in [0x1406f63d0,0x1406fa410]:calls.append(['guiSet'if a==0x1406f63d0 else'guiClear',y&255]);m.finish()
 elif a==0x1402d9630:assert y==2 and z==1;calls.append(['byte',2,1]);m.finish(c.get('mask',0))
 elif a==0x1402d9600:calls.append(['bool']);m.finish(c.get('value',0))
 elif a==0x1402da450:assert y==16;calls.append(['word',16]);m.finish(len(c.get('incoming',[])))
 elif a==0x1409737c0:calls.append(['objectId']);m.finish(c['incoming'][index]);index+=1
 elif a==0x1402d9460:calls.append(['overflow']);m.finish(c.get('overflow',0))
 elif a==0x1406acc40:calls.append(['apply',y&255,z&0xffffffff,ids(w)]);m.finish()
 elif a==0x1406abbc0:calls.append(['gui']);m.finish(gui if c.get('gui',True)else 0)
 elif a==0x140874cd0:calls.append(['refreshGui']);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unknown client pause dependency {a:x} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def seedTimer(ptr,i):
 for key,(offset,size)in fields.items():
  value={'mode':i%2,'fixedRate':30+i,'counter':0x123456789abcdef0+i*1000,'previousCounter':0x123456789abcdef0+i*1000-100,'paused':i%2,'pausedDay':100+i,'pausedTime':200+i,'dayOffset':300+i,'timeOffset':400+i,'minutesPerHour':5+i,'dayLength':7200000+i,'secondsPerDay':7200+i}[key];u.mem_write(ptr+offset,value.to_bytes(size,'little'))
def timer(ptr):return{key:str(m.q(ptr+off))if size==8 else int.from_bytes(u.mem_read(ptr+off,size),'little')for key,(off,size)in fields.items()}
def run(case):
 global c,calls,index,disposed,allocated,reallocations,objects
 c=case;calls=[];index=0;disposed=False;allocated=False;reallocations=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(state+0x4c8,bytes([c.get('flags',0)]));m.wq(state+0x50,world);m.wq(state+0x58,one);m.wq(state+0x60,two);m.wq(state+0x28,state);m.wq(state+8,profile);m.wi(profile+0x128,c.get('profileMode',0));m.wi(state+0x48,c.get('controlledId',11));m.wq(state+0x90,gui if c.get('gui',True)else 0);m.wi(gui+0x28,c.get('guiActive',1));m.wq(gui+0xa8,c.get('guiA8',1));m.wq(0x1412df970,app);m.wq(app,state);m.wq(vt+0x10,0x140807680);m.wq(vt+0x18,m.stop+0x10);m.wq(scene,sceneVt);m.wq(sceneVt+0x150,m.stop+0x20);m.wq(sceneVt+0x158,m.stop+0x30);m.wq(audio+0xf8,audioOwner if c.get('audio',True)else 0);m.wq(audioOwner+0x248,audioVt);m.wq(audioVt,audioVt+0x100);m.wq(audioVt+0x100+0xd0,m.stop+0x40);m.wq(audioVt+0x100+0xc8,m.stop+0x50)
 m.wq(state+0x4d0,0 if c.get('nullList')else old);m.wq(old,oldIds);m.wi(old+8,len(c.get('old',[11])));m.wi(old+12,256)
 for i,id in enumerate(c.get('old',[11])):m.wi(oldIds+i*4,id)
 m.wq(incoming,incomingIds);m.wi(incoming+8,len(c.get('incoming',[])));m.wi(incoming+12,256)
 for i,id in enumerate(c.get('incoming',[])):m.wi(incomingIds+i*4,id)
 if c['mode']=='receive':u.mem_write(incoming,bytes(16))
 objects={id:m.heap+0x50000+i*0x1000 for i,id in enumerate([11,22,0xf0000001])}
 for id,ptr in objects.items():m.wq(ptr,vt);m.wi(ptr+8,id);m.wi(ptr+0x50,77);m.wi(ptr+0x54,88)
 for i,ptr in enumerate(timers):seedTimer(ptr,i)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 args=[state,c.get('mask',0),c.get('value',0),0 if c.get('nullIncoming')else incoming]
 if c['mode']in['timer','excluded']:args=[state,c.get('id',11),0,0]
 elif c['mode']=='receive':args=[message,0,0,0]
 elif c['mode']=='reset':args=[objects[11],c.get('day',0),c.get('time',0),0]
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 try:u.emu_start(entries[c['mode']],m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls[-12:])));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=dict(case=c,calls=calls,flags=u.mem_read(state+0x4c8,1)[0],exclusions=None if c.get('nullList')else ids(old),disposed=disposed,allocated=allocated,reallocations=reallocations,timers={name:timer(ptr)for ptr,name in timers.items()},stamps={str(id):[m.si(ptr+0x50)&0xffffffff,m.si(ptr+0x54)&0xffffffff]for id,ptr in objects.items()})
 if c['mode']=='timer':result['result']=timers[u.reg_read(UC_X86_REG_RAX)]
 elif c['mode']in['excluded','receive']:result['result']=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return result
cases=[dict(mode='set',flags=flags,mask=mask,value=value,incoming=incoming)for flags,mask,value,incoming in itertools.product([0,1,2,3,4,255],[0,1,2,3,4,255],[-1,0,1,2],[[],[22,22,33,0xf0000001]])]
cases += [dict(mode='set',flags=1,mask=1,value=0,old=[11,22],incoming=[22],**options)for options in[{'asObject':False},{'scene':False},{'gui':False},{'guiActive':0},{'profileMode':1},{'audio':False},{'nullIncoming':True}]]
cases += [dict(mode=mode,flags=flags,id=id,nullList=null)for mode,flags,id,null in itertools.product(['timer','excluded'],[0,1,2,3],[11,22,0xf0000001,0x7f000000],[False,True])]
cases += [dict(mode='clear',flags=flags,old=values)for flags,values in itertools.product([0,1,2,3],[[],[11],[11,11,22,33]])]
cases += [dict(mode='receive',mask=mask,value=value,incoming=values,overflow=overflow,gui=gui,guiA8=guiA8)for mask,value,values,overflow,gui,guiA8 in itertools.product([0,1,2,3],[-1,0,1,2],[[],[11,22],[11]*17],[0,1],[False,True],[0,1])]
cases += [dict(mode='reset',day=day,time=time)for day,time in itertools.product([0,0xffffffff],[0,0xf0000001])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-client-pause-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),modes={mode:sum(r['case']['mode']==mode for r in rows)for mode in entries})))
