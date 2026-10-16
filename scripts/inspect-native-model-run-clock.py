"""Complete unchanged Gob::Animate14004dbd0..14004e9dd in explicit
nonprofiled, sceneless, no attachment/sound/override, visible model profiles.
Actual run clock and AnimateEvents execute. Node sampling, root update,
ASCII formatting, array removal/heap and dispatch are lower boundaries.
Comparison scopes the run stage14004e455..14004e8f5; other outer gates open.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
gob,model,root,vt,runlist,handles=[m.heap+n*0x1000 for n in range(6)]
def string(ptr):
 if not ptr:return ''
 raw=bytearray()
 while u.mem_read(ptr+len(raw),1)[0]:raw.append(u.mem_read(ptr+len(raw),1)[0])
 return raw.decode('ascii')
def listptrs():return[m.q(runlist+i*8)for i in range(m.si(gob+0xe8))]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x140c10360:calls.append(['destroyRun',runNames[x],y&0xffffffff]);m.finish()
 elif a==0x140052b30:
  values=listptrs()
  if y in values:values.remove(y)
  for i,v in enumerate(values):m.wq(runlist+i*8,v)
  m.wi(gob+0xe8,len(values));m.finish()
 elif a==0x140047000:u.mem_write(x,(string(y).replace('%s',string(z))).encode()+b'\0');m.finish()
 elif a==0x14004fe90:
  ptr=m.q(0x1412e00a0);calls.append(['applyClip',clipNames[y],m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28),m.rf(0x14128e218),runNames.get(ptr),m.si(0x1412e009c)]);m.finish()
 elif a==m.stop+0x10:calls.append(['event',string(y),z&0xffffffff]);m.finish()
 elif a==m.stop+0x20:m.finish(1)
 elif a==m.stop+0x30:m.finish(0)
 elif a==m.stop+0x40:calls.append(['updateRoot',m.xmm(UC_X86_REG_XMM1)]);m.finish()
 elif a==m.stop+0x50:calls.append(['periodicUpdate']);m.finish()
 elif not(0x14004dbd0<=a<0x14004e9dd or 0x14004fce0<=a<0x14004fe88):raise RuntimeError(f'Unexpected model clock dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def state():
 return[dict(id=runNames[ptr],clip=clipNames[m.q(ptr)],speed8=m.rf(ptr+8),flagsC=m.si(ptr+0xc),previous10=m.rf(ptr+0x10),time14=m.rf(ptr+0x14),weight18=m.rf(ptr+0x18),transition1c=m.rf(ptr+0x1c),scale20=m.rf(ptr+0x20),done24=m.si(ptr+0x24))for ptr in listptrs()]
def run(case):
 global c,calls,runNames,clipNames
 c=case;calls=[];runNames={};clipNames={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(0x14141e310,bytes(8));m.wq(0x1412e00a0,0);m.wi(0x1412e009c,0)
 m.wq(gob,vt);m.wq(root,vt);m.wq(gob+0x68,model);u.mem_write(model+0x92,b'\1');m.wq(gob+0xe0,runlist);m.wq(gob+8,handles);m.wi(gob+0x14,16);m.wq(gob+0x90,root if c['root']else 0);u.mem_write(gob+0x188,int(c['period']&65535).to_bytes(2,'little'))
 for off,target in[(0x298,0x10),(0x260,0x20),(0x2b8,0x30),(0xd0,0x40),(0x2c8,0x50)]:m.wq(vt+off,m.stop+target)
 m.wi(gob+0xe8,len(c['initial']))
 for i,r in enumerate(c['initial']):
  ptr=m.heap+0x10000+i*0x1000;clip=m.heap+0x20000+i*0x1000;event=m.heap+0x30000+i*0x1000;runNames[ptr]=i;clipNames[clip]=i;clipNames[clip+0x500]=i;m.wq(runlist+i*8,ptr);m.wq(ptr,clip);u.mem_write(clip+0x10,f'clip{i}'.encode()+b'\0');m.wf(clip+0x90,r['length']);m.wq(clip+0x50,clip+0x500);m.wq(clip+0xd8,event);m.wi(clip+0xe0,4)
  for j,t in enumerate([0,.25,.5,1]):m.wf(event+j*36,t);u.mem_write(event+j*36+4,f'e{i}_{j}'.encode()+b'\0')
  for off,key in [(8,'speed'),(0x10,'previous'),(0x14,'time'),(0x18,'weight'),(0x1c,'transition'),(0x20,'scale')]:m.wf(ptr+off,r[key])
  m.wi(ptr+0xc,r['flags']);m.wi(ptr+0x24,r['done'])
 frames=[]
 for delta in c['deltas']:
  rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,gob);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',delta),'little'))
  try:u.emu_start(0x14004dbd0,m.stop,count=100000)
  except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
  assert u.reg_read(UC_X86_REG_RIP)==m.stop;frames.append(dict(runs=state(),period=int.from_bytes(u.mem_read(gob+0x188,2),'little',signed=True)))
 return dict(case=c,calls=calls,frames=frames)
def entry(**kw):
 r=dict(length=1.5,speed=1,previous=0,time=-.00001,weight=1,transition=0,scale=1.25,flags=3,done=0);r.update(kw);return r
def profile(initial,**kw):
 c=dict(initial=initial,deltas=[.1,.5,1,.1],root=1,period=0);c.update(kw);return c
rows=[run(profile([entry(speed=speed,time=time,flags=flags,weight=weight,transition=transition)]))for speed,time,flags,(weight,transition) in itertools.product([-.31,0,1],[-.00001,0,.75,1.50001],[0,1,2,3,4,8,32,33,256,257,512,513],[(1,0),(0,.25),(.5,.25)])]
rows.extend(run(profile([entry(flags=first),entry(flags=second,time=.9,weight=.5,transition=.25)]))for first,second in itertools.product([0,3,8,32,33],[0,3,8,32,33]))
rows.extend(run(profile([entry(done=1)],period=period,root=root))for period,root in itertools.product([-32768,-2,-1,0,3,4,5,32767],[0,1]))
rows.append(run(profile([])))
out=m.root/'backups/animations/native-model-run-clock-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
