"""Complete unchanged Gob::PlayAnimation140052580..140052a22. Model clip
lookup, FindAnimScale, LerpFloat::Lerped, array insert/remove, heap, formatting
and dispatch are explicit providers; verifies owner ordering/state, not scene
sampling, blending, allocation capacity policy or the upper Animate clock.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
gob,model,override,vt,runlist,nameptr=[m.heap+n*0x1000 for n in range(6)]
def string(ptr):
 if not ptr:return ''
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def writef(ptr,value):m.wf(ptr,value)
def listptrs():return[m.q(runlist+i*8)for i in range(m.si(gob+0xe8))]
def writelist(values):
 for i,v in enumerate(values):m.wq(runlist+i*8,v)
 m.wi(gob+0xe8,len(values))
def hook(u,a,n,_):
 global allocations
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x140c9a9fc:
  l,r=string(x).lower(),string(y).lower();m.finish(0 if l==r else 1)
 elif a==0x140050f80:
  name=string(y);kind='override'if x==override else'base';calls.append(['findAnimation',kind,name]);m.finish(clipByName.get((kind,name.lower()),0))
 elif a==0x140050ed0:
  calls.append(['animationScale','override'if x==override else'base',clipNames.get(y)]);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c['animationScale']),'little'));m.finish()
 elif a==0x1402e9a80:
  calls.append(['playbackScale']);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c['playbackScale']),'little'));m.finish()
 elif a==0x140c10324:
  ptr=m.heap+0x40000+allocations*0x100;runNames[ptr]=allocations+100;allocations+=1;calls.append(['createRun',runNames[ptr]]);m.finish(ptr)
 elif a==0x140c10360:calls.append(['destroyRun',runNames[x],y&0xffffffff]);m.finish()
 elif a==0x140052b30:
  values=listptrs()
  if y in values:values.remove(y)
  writelist(values);m.finish()
 elif a==0x140051b90:
  values=listptrs();values.insert(z&0xffffffff,y);writelist(values);m.finish()
 elif a==0x140047000:
  u.mem_write(x,(string(y).replace('%s',string(z))).encode()+b'\0');m.finish()
 elif a==m.stop+0x10:calls.append(['event',string(y),z&0xffffffff]);m.finish()
 elif not 0x140052580<=a<0x140052a22:raise RuntimeError(f'Unexpected model playback dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def state():
 return[dict(id=runNames[ptr],clip=clipNames[m.q(ptr)],speed8=m.rf(ptr+8),flagsC=m.si(ptr+0xc),previous10=m.rf(ptr+0x10),time14=m.rf(ptr+0x14),weight18=m.rf(ptr+0x18),transition1c=m.rf(ptr+0x1c),scale20=m.rf(ptr+0x20),done24=m.si(ptr+0x24))for ptr in listptrs()]
def run(case):
 global c,calls,allocations,runNames,clipByName,clipNames
 c=case;calls=[];allocations=0;runNames={};clipByName={};clipNames={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(gob,vt);m.wq(vt+0x298,m.stop+0x10);m.wq(gob+0x68,model);m.wq(gob+0x80,override if c['override']else 0);m.wq(gob+0xe0,runlist)
 for i,(kind,name)in enumerate([('base','impact'),('base','duration'),('base','cessation'),('override','impact')]):
  ptr=m.heap+0x10000+i*0x1000;clipByName[kind,name]=ptr;clipNames[ptr]=f'{kind}:{name}';u.mem_write(ptr+0x10,name.encode()+b'\0');m.wf(ptr+0x90,c['length']);m.wf(ptr+0x94,c['transition'])
 values=[]
 for i,record in enumerate(c['initial']):
  ptr=m.heap+0x20000+i*0x100;values.append(ptr);runNames[ptr]=i;m.wq(ptr,clipByName['base',record['name']]);
  for off,value in[(8,.75),(0x10,.125),(0x14,.375),(0x18,.625),(0x1c,.25),(0x20,1.5)]:m.wf(ptr+off,value)
  m.wi(ptr+0xc,record['flags']);m.wi(ptr+0x24,1)
 writelist(values);frames=[]
 for request in c['requests']:
  u.mem_write(nameptr,request['name'].encode()+b'\0');rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wf(rsp+0x28,request['start']);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,gob);u.reg_write(UC_X86_REG_RDX,nameptr if request['name']!='<null>'else 0);u.reg_write(UC_X86_REG_R9,request['flags']);u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',request['speed']),'little'))
  try:u.emu_start(0x140052580,m.stop,count=100000)
  except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
  assert u.reg_read(UC_X86_REG_RIP)==m.stop;frames.append(dict(result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,runs=state()))
 return dict(case=c,calls=calls,frames=frames)
def request(name='impact',speed=1,flags=3,start=0):return dict(name=name,speed=speed,flags=flags,start=start)
def profile(**kw):
 c=dict(override=0,animationScale=1.25,playbackScale=.5,length=1.5,transition=.25,initial=[],requests=[request()]);c.update(kw);return c
rows=[run(profile(initial=initial,requests=[request(name,speed,flags,start)],override=override))for initial,name,speed,flags,start,override in itertools.product([[],[dict(name='impact',flags=3)],[dict(name='duration',flags=0),dict(name='impact',flags=8)]],['impact','current','missing'],[-.31,0,1],[0,1,2,3,8,16,32,64,128,512],[-1,0,.75,5],[0,1])]
rows.extend(run(profile(initial=[dict(name='duration',flags=flags),dict(name='impact',flags=0)],requests=[request(name)]))for flags,name in itertools.product([0,8,32,40],['','NULL','<null>']))
rows.extend(run(profile(requests=[request(),request('impact',-.31),request('impact',1,512),request('impact',1,128)]))for _ in range(1))
out=m.root/'backups/animations/native-model-playback-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
