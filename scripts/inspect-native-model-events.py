"""Unchanged AnimateEvents14004fce0, Gob::DoEvent140050d50 and Detonate
140061a30 together. Heap/backing-array allocation, CRT ASCII stricmp and explicit
test listeners are captured boundaries. Native active-dispatch handle lifetime,
event ordering, listener matching/userdata and actual detonate BYTE writes run.
Synthetic owner destruction callback invalidates native handles, not a full Gob
destructor. Upper animation clock, listener creation/destruction and locale open.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
owner,clip,events,listeners,array,vt=[m.heap+n*0x1000 for n in range(6)]
def string(ptr):
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def hook(u,a,n,_):
 global allocated
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140c4f038:
  allocated+=1;ptr=m.heap+0x90000+allocated*0x1000
  if x:u.mem_write(ptr,bytes(u.mem_read(x,min(y,0x1000))))
  m.finish(ptr)
 elif a==0x140c9a9fc:m.finish(0 if string(x).lower()==string(y).lower()else 1)
 elif a==0x140061a30:calls.append(['detonate',string(y),names[z]])
 elif a==m.stop+0x10:
  name=string(y);calls.append(['listener',name,names[z]])
  if c['destroy']:
   for i in range(m.si(owner+0x10)):m.wq(m.q(m.q(owner+8)+i*8),0)
   m.wi(owner+0x10,0)
  m.finish()
 elif not(0x14004fce0<=a<0x14004fe88 or 0x140050d50<=a<0x140050eaf or 0x140061a30<=a<0x140061a39):raise RuntimeError(f'Unexpected native event dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocated,names
 c=case;calls=[];allocated=0;names={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(owner,vt);m.wq(vt+0x298,0x140050d50)
 targets=[]
 for i in range(6):ptr=m.heap+0x20000+i*0x1000;names[ptr]=i;targets.append(ptr)
 patterns=['Detonate','','*tail','detonate','Sound'];m.wq(owner+0x460,array);m.wi(owner+0x468,len(patterns))
 for i,pattern in enumerate(patterns):
  ptr=listeners+i*0x100;u.mem_write(ptr,pattern.encode()+b'\0');m.wq(array+i*8,ptr);m.wq(ptr+0x20,0x140061a30 if i in [0,3]else m.stop+0x10);m.wq(ptr+0x28,targets[i])
 m.wq(clip+0xd8,events);m.wi(clip+0xe0,len(c['events']))
 for i,event in enumerate(c['events']):m.wf(events+i*36,event['time']);u.mem_write(events+i*36+4,event['name'].encode()+b'\0')
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,owner);u.reg_write(UC_X86_REG_RDX,clip);u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',c['fromTime']),'little'));u.reg_write(UC_X86_REG_XMM3,int.from_bytes(struct.pack('<f',c['toTime']),'little'));m.wi(rsp+0x28,c['flags'])
 if c['direct']:
  u.mem_write(events,b'dEtOnAtE\0');u.reg_write(UC_X86_REG_RDX,events);u.reg_write(UC_X86_REG_R8,targets[5] if c['data']else 0)
 try:u.emu_start(0x140050d50 if c['direct']else 0x14004fce0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,detonated=[u.mem_read(ptr+0x108,1)[0]for ptr in targets],activeHandles=m.si(owner+0x10),capacity=m.si(owner+0x14),allocated=allocated)
sets=[[],[dict(time=0,name='detonate'),dict(time=.25,name='Sound'),dict(time=.5,name='DETONATE'),dict(time=1,name='unknown')],[dict(time=.5,name='Sound'),dict(time=.25,name='Detonate'),dict(time=.25,name='unknown'),dict(time=1.5,name='Sound')]]
rows=[run(dict(fromTime=start,toTime=end,flags=flags,events=events,direct=0,data=0,destroy=0))for start,end,flags,events in itertools.product([-.25,0,.25,.5,1.5],[0,.25,.5,1,1.5],range(4),sets)]
rows.extend(run(dict(fromTime=0,toTime=0,flags=0,events=[],direct=1,data=data,destroy=destroy))for data,destroy in itertools.product([0,1],[0,1]))
out=m.root/'backups/animations/native-model-events-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
