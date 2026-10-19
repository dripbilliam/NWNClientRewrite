"""Complete original SetPauseState56bd40/Toggle56ded0, add55d010/remove569c70,
active-exclusion564530, active-timer55f0d0, reprocess56a270, creature reset39f0d0
and ResetTimer5977e0. Lower timer pause/unpause/snapshot, message broadcast,
object lookup/virtual reset, array add and memmove are captured boundaries.
Synthetic initialized fields; no native host event queue, effects, renderer,
Time Stop casting, network or whole-campaign acceptance claim.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
state=m.heap;world,one,two,first,second,firstIDs,secondIDs,object,vt=[m.heap+n*0x1000 for n in range(20,29)]
entries={'set':0x14056bd40,'toggle':0x14056ded0,'add':0x14055d010,'remove':0x140569c70,'excluded':0x140564530,'timer':0x14055f0d0,'reprocess':0x14056a270,'creature':0x14039f0d0,'reset':0x1405977e0}
ranges=[(0x140597040,0x140597045)]
for name in ['state','toggle','exclusion-add','exclusion-remove','active-exclusion','active-timer','reprocess-actions','creature-reset-times','reset-timer']:
 body=json.loads((m.root/f'backups/animations/rea-pause-{name}-owner.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in body['ranges'])
timers={world:'world',one:'one',two:'two'}
def wb(a,n):u.mem_write(a,bytes([n&255]))
def signed(n):return(n+2**31)%2**32-2**31
def listIds(owner):return[m.si(m.q(owner)+n*4)&0xffffffff for n in range(m.si(owner+8))]
def hook(u,a,n,_):
 global appended
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140597760:calls.append(['pause',timers[x]]);m.wi(x+0x18,1);m.finish()
 elif a==0x140597ba0:calls.append(['unpause',timers[x]]);m.wi(x+0x18,0);m.finish()
 elif a==0x140597880:calls.append(['snapshot',timers[x]]);m.wq(x+0x10,m.q(x+8));m.wq(x+8,m.q(x+8)+100);m.finish()
 elif a==0x140597040:calls.append(['syncPrevious',timers[x]]);m.finish(m.q(x+8))
 elif a==0x1405977e0:
  if c['mode']!='reset':calls.append(['reset',timers[x],timers[y]])
 elif a==0x14056a270 and c['mode']!='reprocess':
  calls.append(['reprocess',y&255])
  if 'afterReprocess'in c:wb(state+0x10108,c['afterReprocess'])
  m.finish()
 elif a==0x1404dd0c0:calls.append(['send',y&255,signed(z)]);m.finish()
 elif a==0x14008ae10:
  ids=listIds(x);m.wi(m.q(x)+len(ids)*4,y);m.wi(x+8,len(ids)+1);m.finish()
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x140597180:calls.append(['time',timers[x]]);m.wi(y,{'world':10,'one':20,'two':30}[timers[x]]);m.wi(z,{'world':100,'one':200,'two':300}[timers[x]]);m.finish()
 elif a==0x140296470:
  calls.append(['object',y&0xffffffff]);m.wq(z,object if(y&0xffffffff) in [11,22,0xf0000001]else 0);m.wi(object+8,y);m.finish()
 elif a==m.stop+0x10:
  calls.append(['resetObject',m.si(x+8)&0xffffffff,y&0xffffffff,z&0xffffffff])
  if c.get('append')and not appended:
   owner=first if c['mask']==2 else second;ids=listIds(owner);m.wi(m.q(owner)+len(ids)*4,22);m.wi(owner+8,len(ids)+1);appended=True
  m.finish()
 elif a==0x140115890:raise AssertionError('Unreachable native pause timer warning')
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unknown pause dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
fields={'mode':(0,4),'fixedRate':(4,4),'counter':(8,8),'previousCounter':(16,8),'paused':(24,4),'pausedDay':(28,4),'pausedTime':(32,4),'dayOffset':(36,4),'timeOffset':(40,4),'minutesPerHour':(44,1),'dayLength':(48,4),'secondsPerDay':(52,4)}
def seedTimer(ptr,index):
 for key,(offset,size)in fields.items():
  value={'mode':index%2,'fixedRate':30+index,'counter':0x123456789abcdef0+index*1000,'previousCounter':0x123456789abcdef0+index*1000-100,'paused':index%2,'pausedDay':100+index,'pausedTime':200+index,'dayOffset':300+index,'timeOffset':400+index,'minutesPerHour':5+index,'dayLength':7200000+index,'secondsPerDay':7200+index}[key]
  u.mem_write(ptr+offset,value.to_bytes(size,'little'))
def timer(ptr):return{key:str(m.q(ptr+off))if size==8 else int.from_bytes(u.mem_read(ptr+off,size),'little')for key,(off,size)in fields.items()}
def run(case):
 global c,calls,appended
 c=case;calls=[];appended=False;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));wb(state+0x10108,c.get('flags',0));m.wq(state+0x10098,world);m.wq(state+0x100a0,one);m.wq(state+0x100a8,two);m.wq(state+0x100f8,0 if c.get('nullFirst')else first);m.wq(state+0x10100,0 if c.get('nullSecond')else second);m.wq(object,vt);m.wq(vt+0x10,m.stop+0x10)
 for ptr,ids,owner in [(first,c.get('first',[11,0xf0000001]),firstIDs),(second,c.get('second',[22,11]),secondIDs)]:
  m.wq(ptr,owner);m.wi(ptr+8,len(ids));m.wi(ptr+12,256)
  for i,id in enumerate(ids):m.wi(owner+i*4,id)
 for i,ptr in enumerate([world,one,two]):seedTimer(ptr,i)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,world if c['mode']=='reset'else object if c['mode']=='creature'else state)
 args={'add':[c.get('id',11),c.get('mask',0)],'remove':[c.get('id',11),c.get('mask',0)],'set':[c.get('mask',0),c.get('value',0)],'toggle':[c.get('mask',0)],'excluded':[c.get('id',11)],'timer':[c.get('id',11)],'reprocess':[c.get('mask',0)],'creature':[c.get('day',0),c.get('time',0)],'reset':[one]}[c['mode']]
 for reg,value in zip([UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value)
 try:u.emu_start(entries[c['mode']],m.stop,count=30000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=dict(case=c,calls=calls,flags=u.mem_read(state+0x10108,1)[0],first=listIds(first),second=listIds(second),timers={name:timer(ptr)for ptr,name in timers.items()})
 if c['mode']=='timer':result['value']=timers[u.reg_read(UC_X86_REG_RAX)]
 elif c['mode']=='excluded':result['value']=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 elif c['mode']=='creature':result['pairs']=[[m.si(object+off)&0xffffffff,m.si(object+off+4)&0xffffffff]for off in [0x54c,0x578,0xbc]]
 return result
cases=[]
for mode,flags,mask,value in itertools.product(['set','toggle'],[0,1,2,3,4,255],[0,1,2,3,4,255],[-1,0,1,2]):cases.append(dict(mode=mode,flags=flags,mask=mask,value=value))
for mask,flags in itertools.product([1,2],[0,1,2,3]):cases.append(dict(mode='set',flags=flags,mask=mask,value=0,afterReprocess=3))
for mode,mask,id,firstList,secondList in itertools.product(['add','remove'],[0,1,2,3,4,255],[11,22,33,0xf0000001,0x7f000000],[[],[11],[11,11,0xf0000001]],[[],[22],[22,11,11]]):cases.append(dict(mode=mode,mask=mask,id=id,first=firstList,second=secondList))
for mode,flags,id,nullFirst,nullSecond in itertools.product(['excluded','timer'],[0,1,2,3,4,255],[11,22,33,0xf0000001,0x7f000000],[False,True],[False,True]):cases.append(dict(mode=mode,flags=flags,id=id,nullFirst=nullFirst,nullSecond=nullSecond))
for flags,mask,firstList,secondList,append in itertools.product([0,1,2,3],[0,1,2,3],[[],[11,0x7f000000,33]],[[],[11,0xf0000001]],[False,True]):cases.append(dict(mode='reprocess',flags=flags,mask=mask,first=firstList,second=secondList,append=append))
for day,time in itertools.product([0,1,0xffffffff],[0,1,0xffffffff]):cases.append(dict(mode='creature',day=day,time=time))
cases.append(dict(mode='reset'));rows=[run(c)for c in cases];out=m.root/'backups/animations/native-server-pause-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),modes={mode:sum(r['case']['mode']==mode for r in rows)for mode in entries})))
