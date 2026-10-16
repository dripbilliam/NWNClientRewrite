"""Unchanged creature script-event7 block14038f623..14038f888, capture-string
clear/append140491060/14048db90 and VM178/179 bodies. Query/VM/heap/string and
RunEventScript boundaries are explicit. This does not prove lower script AI,
possession, text transport, C++ allocation failures or whole EventHandler.
"""
import importlib.util,json,itertools,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,event,app,server,vm,command,vtable,pointers,stringtemp=[m.heap+n*0x1000 for n in range(1,10)]
def signed(v):return struct.unpack('<i',struct.pack('<I',v&0xffffffff))[0]
def text(ptr,length):return bytes(u.mem_read(ptr,length)).decode('ascii') if ptr and length else ''
def value(ptr):return text(m.q(ptr),m.si(ptr+8))
def allocate(size):
 global nextHeap
 ptr=nextHeap;nextHeap+=((size+15)//16)*16;return ptr
def writeString(ptr,s):
 data=allocate(len(s)+1);u.mem_write(data,s.encode('ascii')+b'\0');m.wq(ptr,data);m.wi(ptr+8,len(s));m.wi(ptr+12,len(s)+1)
def hook(u,a,n,_):
 global output
 if a in [m.stop,0x14038faed]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1403d4d70:calls.append(['associateId',y,z]);m.finish(101)
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(actor if c.get('client') else 0)
 elif a==0x1403daa40:calls.append(['unpossess']);m.finish()
 elif a==0x1404c6af0:calls.append(['integer',y]);m.finish(c.get('integers',[])[y] if y<len(c.get('integers',[])) else 0)
 elif a==0x1404c6b30:calls.append(['string',z]);writeString(y,c.get('strings',[])[z] if z<len(c.get('strings',[])) else '');m.finish(y)
 elif a==0x14003d8c0:writeString(x,text(y,z&0xffffffff));m.finish(x)
 elif a in [0x140c10370,0x140c10360,0x140c4f024]:m.finish()
 elif a in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif a==0x140c4f038:
  ptr=allocate(y)
  if x:u.mem_write(ptr,bytes(u.mem_read(x,min(y,m.si(actor+0x1f8)*8))))
  m.finish(ptr)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x140491060 and c['operation']=='event':calls.append(['clear']);m.wq(actor+0x1f0,0);m.wq(actor+0x1f8,0);m.finish()
 elif a==0x14048db90 and c['operation']=='event':
  s=value(y);calls.append(['append',s]);captured.append(s);m.finish()
 elif a==m.stop+0x10:calls.append(['scriptName',y]);m.finish(stringtemp)
 elif a==0x1403d54d0:calls.append(['possessed']);m.finish(c.get('possessed',0))
 elif a==0x1402ae870:calls.append(['rulesetName',text(x,y)]);m.finish(stringtemp)
 elif a==0x1402a4130:calls.append(['rulesetInt',z]);m.finish(c.get('rule',0))
 elif a==0x1404998a0:calls.append(['runScript',y,value(z)]);m.finish(1)
 elif a==0x140286110:
  calls.append(['pop']);m.wi(y,c.get('index',0));m.finish(c.get('pop',1))
 elif a==0x14055b850:calls.append(['array']);m.finish(server)
 elif a==0x140296470:calls.append(['object',y&0xffffffff]);m.wq(z,actor if c.get('exists',True) else 0);m.finish(c.get('lookup',0))
 elif a==0x140286550:output=value(y);m.finish(c.get('push',1))
 elif a==0x140286410:output=signed(y);m.finish(c.get('push',1))
 elif not any(lo<=a<hi for lo,hi in [(0x14038f623,0x14038f88d),(0x140491060,0x14049110a),(0x14048db90,0x14048dc6f),(0x14052b6e0,0x14052b852),(0x14052b860,0x14052b8d8)]):raise AssertionError(f'Uncaptured listen event dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,output,nextHeap,captured
 c=case;calls=[];output=None;nextHeap=m.heap+0x10000;captured=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(0x1412df910,vm)
 m.wi(actor+8,99);u.mem_write(actor+0xc,bytes([c.get('type',5)]));m.wq(actor,vtable);m.wq(vtable+0x1e0,m.stop+0x10)
 writeString(stringtemp,c.get('script','custom'));m.wi(command+0xc,99)
 values=c.get('values',['old','OTHER']);capacity=c.get('capacity',len(values));m.wq(actor+0x1f0,pointers if capacity else 0);m.wi(actor+0x1f8,len(values));m.wi(actor+0x1fc,capacity)
 for i,s in enumerate(values):
  if s is None:ptr=0
  else:ptr=allocate(16);writeString(ptr,s)
  m.wq(pointers+i*8,ptr)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x800,bytes(0x900));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 op=c['operation']
 if op=='event':
  frame=rsp-0x500;m.wi(frame+0x2a0,c.get('caller',100))
  for reg,v in [(UC_X86_REG_RSI,actor),(UC_X86_REG_R14,event),(UC_X86_REG_RBP,frame),(UC_X86_REG_R12,1),(UC_X86_REG_RDI,0),(UC_X86_REG_R15,0x140d80070)]:u.reg_write(reg,v)
  # Empty CExoString fallback used only for null script/string pointers.
  u.emu_start(0x14038f623,m.stop,count=10000)
 elif op in ['clear','append']:
  u.reg_write(UC_X86_REG_RCX,actor)
  if op=='append':writeString(stringtemp,c.get('append','new'));u.reg_write(UC_X86_REG_RDX,stringtemp)
  u.emu_start(0x140491060 if op=='clear' else 0x14048db90,m.stop,count=10000)
 else:
  u.reg_write(UC_X86_REG_RCX,command);u.reg_write(UC_X86_REG_RDX,178 if op=='get' else 179);u.reg_write(UC_X86_REG_R8,1 if op=='get' else 0)
  u.emu_start(0x14052b6e0 if op=='get' else 0x14052b860,m.stop,count=10000)
 assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x14038faed]
 out=dict(case=c,calls=calls,output=output)
 if op=='event':out.update(speaker=m.si(actor+0x1b8)&0xffffffff,pattern=m.si(actor+0x1e8),text=value(actor+0x1c8),voice=m.si(actor+0x1bc),volume=m.si(actor+0x1c0),captured=captured)
 elif op in ['clear','append']:
  count=m.si(actor+0x1f8);ptr=m.q(actor+0x1f0);out.update(count=count,capacity=m.si(actor+0x1fc),values=[value(m.q(ptr+i*8)) if m.q(ptr+i*8) else None for i in range(count)])
 else:out['result']=signed(u.reg_read(UC_X86_REG_RAX))
 return out
rows=[run(dict(operation='event',client=client,possessed=possessed,rule=rule,script=script,integers=ints,strings=['whole','first','SECOND','third'],caller=0xffffffff)) for client,possessed,rule,script,ints in itertools.product([False,True],[0,1],[0,1],['','default','Default','defaultmore','custom'],[[],[0,-5],[1,-2,7,3],[3,-7,9,-1],[4,-19,-1,255],[-1,-3,0,0]])]
rows += [run(dict(operation='clear',values=values,capacity=max(16,len(values)))) for values in [[],['a'],[None,'a',None,'b'],['a']*17]]
rows += [run(dict(operation='append',values=['old']*count,capacity=capacity,append=value)) for count,capacity in [(0,0),(0,16),(1,16),(16,16),(17,32),(32,32)] for value in ['', 'CAPTURE']]
rows += [run(dict(operation=op,values=['whole','first','SECOND'],exists=exists,type=kind,index=index,lookup=lookup)) for op,exists,kind,index,lookup in itertools.product(['get','count'],[False,True],[3,4,5,6,14],[-1,0,1,2,3,2147483647],[0,1])]
out=m.root/'backups/animations/native-listen-event-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
