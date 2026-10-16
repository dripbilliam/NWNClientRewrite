"""Unchanged ReceiveAssociateCommand1403d69f0, BroadcastAssociateCommand140382bb0
and decoded subtype27 block140454288. Capture allocations, expression/query,
event delivery, unsummon/possession/domination and wire reads as lower boundaries.
This does not prove those lower owners, transport serialization or script AI.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,master,app,server,expression,event,manager,ids,message,strings=[m.heap+n*0x1000 for n in range(1,11)]
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def hook(u,a,n,_):
 if a in [m.stop,0x140453780]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b3d0:
  oid=y&0xffffffff;calls.append(['creature',oid])
  if c['operation']=='receive':ptr=master if c.get('exists',True) else 0
  elif c['operation']=='broadcast':ptr=actor if oid==100 else master if oid==99 else 0
  else:ptr=(master if oid==99 else actor) if c.get('exists',True) and oid==c.get('resolvedId',100) else 0
  m.finish(ptr)
 elif a==0x1403d69f0 and c['operation']!='receive':
  calls.append(['receive',m.si(x+8)&0xffffffff,signed(y)])
  if c.get('mutate') and len(liveIds)>0:liveIds.pop();m.wi(ids+8,len(liveIds))
  m.finish()
 elif a==0x1403daee0:calls.append(['unsummon',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x1403d7160:calls.append(['removeDomination',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x1403daa40:calls.append(['unpossess',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x140c10324:calls.append(['allocate',x]);m.finish(event)
 elif a==0x1404c6490:calls.append(['eventConstructor']);m.finish(x)
 elif a==0x1404956c0:calls.append(['expression',signed(y)]);m.finish(expression)
 elif a==0x1404c72e0:integers[y]=signed(z);calls.append(['integer',y,signed(z)]);m.finish()
 elif a==0x14003d8c0:
  length=z&0xffffffff;value=bytes(u.mem_read(y,length)).decode('ascii');copies[x]=value;calls.append(['copy',value]);m.finish(x)
 elif a==0x1404c7360:values[y]=copies[z];calls.append(['string',y,copies[z]]);m.finish()
 elif a==0x14055b960:calls.append(['ai']);m.finish(manager)
 elif a==0x1405570b0:
  calls.append(['event',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),int.from_bytes(u.mem_read(m.q(rsp+0x38),2),'little')]);m.finish(1)
 elif a==0x140476130:calls.append(['readObject']);m.finish(c.get('targetId',100))
 elif a==0x1402d9ec0:calls.append(['readInt',y]);m.finish(c['command'])
 elif a==0x1402d9460:calls.append(['overflow']);m.finish(c.get('overflow',0))
 elif a==0x1402d9520:calls.append(['underflow']);m.finish(c.get('underflow',0))
 elif a==0x1403d4d70:calls.append(['associateId',y,z]);m.finish(c.get('redirectId',100))
 elif not any(lo<=a<hi for lo,hi in [(0x1403d69f0,0x1403d6bce),(0x140382bb0,0x140382c25),(0x140454288,0x140454336)]):raise AssertionError(f'Uncaptured associate command dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,integers,values,copies,liveIds
 c=case;calls=[];integers={};values={};copies={};liveIds=list(c.get('ids',[]));u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server)
 m.wi(actor+8,100);m.wi(master+8,99);m.wi(actor+0x8fc,c.get('masterId',99));m.wi(master+0x8fc,99);m.wi(actor+0x90c,77);m.wi(actor+0x708,17);m.wi(master+0x910,31);m.wi(master+0x914,32)
 matches=c.get('matches',[]);m.wi(expression+0x10,len(matches));m.wq(expression+8,strings)
 for i,value in enumerate(matches):
  ptr=strings+0x100+i*0x100;data=ptr+0x30;m.wq(strings+i*8,ptr);m.wq(ptr,data);m.wi(ptr+8,len(value));u.mem_write(data,value.encode('ascii')+b'\0')
 m.wq(actor+0x900,ids if c.get('list',True) else 0);m.wq(ids,ids+0x100);m.wi(ids+8,len(liveIds))
 for i,oid in enumerate(liveIds):m.wi(ids+0x100+i*4,oid)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c['operation']=='input':
  for reg,v in [(UC_X86_REG_R15,master if c.get('actor',True) else 0),(UC_X86_REG_RDI,message),(UC_X86_REG_RSI,0)]:u.reg_write(reg,v)
  start=0x140454288
 else:u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,c['command']);start=0x1403d69f0 if c['operation']=='receive' else 0x140382bb0
 u.emu_start(start,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x140453780]
 return dict(case=c,calls=calls,command=m.si(actor+0x90c),field708=m.si(actor+0x708),field910=m.si(master+0x910),field914=m.si(master+0x914),integers=integers,strings=values,ids=liveIds)
rows=[run(dict(operation='receive',command=command,exists=exists,matches=matches)) for command,exists,matches in itertools.product(range(-26,4),[False,True],[[],['whole'],['whole',''],['whole','first','SECOND'],['whole','one','two','three']])]
rows += [run(dict(operation='broadcast',command=command,ids=ids,list=present,mutate=mutate)) for command,ids,present,mutate in itertools.product([-10,-2,19],[[],[100],[100,777,99,100]],[False,True],[False,True])]
rows += [run(dict(operation='input',command=command,actor=actorExists,exists=exists,masterId=owner,targetId=target,overflow=overflow,underflow=underflow)) for command,actorExists,exists,owner,target,overflow,underflow in itertools.product([-19,-13,-10,99],[False,True],[False,True],[99,777],[99,100],[0,1],[0,1])]
rows += [run(dict(operation='input',command=command,targetId=99,resolvedId=99,redirectId=99,exists=True)) for command in [-19,-13,-10,99]]
out=m.root/'backups/animations/native-associate-command-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
