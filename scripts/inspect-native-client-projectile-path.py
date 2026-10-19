"""Original client projectile configure987770, deterministic initializer987f10
and motion coordinator984f00. Object/model/part lookups, linked-list allocator,
special path builders, next-node and final motion/set-position are captured
lower boundaries in their callers. Separate build/next modes execute the actual
high-ballistic/spiral builders and advancement with zero child-spawn counts.
Part animation and node initialization are captured lowers in next-node mode.
Imported sqrtf is a correctly rounded binary32 boundary. This is not evidence
for captured implementations or child spawning.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,vt,node,node2,obj,ovt,model,mvt,linked,app=[m.heap+n*0x1000 for n in range(1,11)]
setPosition,modelHandle,partPose,stage,setOrientation=m.stop+0x10,m.stop+0x20,m.stop+0x30,m.stop+0x40,m.stop+0x50
ranges=[(0x140987770,0x140987ea0),(0x140987f10,0x140988d59),(0x140984f00,0x1409854c2),(0x14022b180,0x14022b1ae),(0x140986390,0x140986599),(0x140986890,0x140986bd3),(0x140230920,0x1402309f6),(0x140988ed0,0x1409893bd),(0x1409845c0,0x1409848cc),(0x1409848d0,0x140984c14)]
def ub(a):return int.from_bytes(u.mem_read(a,1),'little')
def ui(a):return m.si(a)&0xffffffff
def vector(a):return list(struct.unpack('<3f',u.mem_read(a,12)))
def bits(a):return list(struct.unpack('<3I',u.mem_read(a,12)))
def writeVector(a,v):u.mem_write(a,struct.pack('<3f',*v))
def syncList():m.wq(linked,m.heap+0xb000 if queue else 0)
def writeNode(a,d):
 writeVector(a,d['point']);writeVector(a+0xc,d['attachment'])
 for off,key in [(0x18,'targetId'),(0x1c,'childPath'),(0x20,'duration'),(0x24,'threshold')]:m.wi(a+off,d[key])
 m.wf(a+0x28,d['radius']);u.mem_write(a+0x2c,bytes([d['spawnCount'],d['kind']]))
def readNode(a):return None if not a else dict(point=bits(a),attachment=bits(a+0xc),targetId=ui(a+0x18),childPath=ui(a+0x1c),duration=ui(a+0x20),threshold=ui(a+0x24),radius=m.rf(a+0x28),spawnCount=ub(a+0x2c),kind=ub(a+0x2d))
def snap():
 return dict(position=bits(actor+0x38),orientation=bits(actor+0x44),endpoint=bits(actor+0x188),velocity=bits(actor+0x204),acceleration=bits(actor+0x210),previousPosition=bits(actor+0x174),remaining=ui(actor+0x194),elapsed=ui(actor+0x58),totalTime=ui(actor+0x21c),path=ui(actor+0x1f8),spiralSide=ub(actor+0x238),stage=int.from_bytes(u.mem_read(actor+0x5c,2),'little'),node=readNode(m.q(actor+0x228)),nodes=[readNode(v)for v in queue])
def hook(u,a,n,_):
 global allocation,nextIndex,lookupIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406abb70:m.finish(m.heap+0xc000)
 elif a==0x140296470:
  calls.append(['getObject',y&0xffffffff]);m.wq(z,obj);lookupIndex+=1;m.finish(c['lookup'] if lookupIndex<2 else c.get('secondLookup',c['lookup']))
 elif a==0x1406abb60:calls.append(['clientObject',y&0xffffffff]);m.finish(obj if c['clientObject'] else 0)
 elif a==modelHandle:calls.append(['model']);m.finish(model if c['model'] else 0)
 elif a==partPose:
  calls.append(['nodePose']);assert m.q(w)==0x3f800000
  if c['pose']:writeVector(z,c['posePoint'])
  m.finish(c['pose'])
 elif a==0x1401692a0:value=queue.pop(0) if queue else 0;syncList();m.finish(value)
 elif a==0x140169030:queue.append(y);syncList();m.finish(0)
 elif a==0x140c10324:assert x==0x30;calls.append(['allocate',48]);ptr=m.heap+0x10000+allocation*0x100;allocation+=1;u.mem_write(ptr,b'\xa5'*0x30);m.finish(ptr)
 elif a==0x140c10360:assert y==0x30;calls.append(['destroy',readNode(x)]);m.finish()
 elif a in [0x140986390,0x140986890,0x140985750,0x140986db0,0x140985f20] and c['mode']=='configure':
  path={0x140986390:3,0x140986890:6,0x140985750:8,0x140986db0:11 if y==1 else 12,0x140985f20:13}[a];calls.append(['build',path]);writeNode(node2,c['generated']);queue.append(node2);syncList();m.finish()
 elif a==0x140987f10 and c['mode'] in ['configure','next']:calls.append(['initialize',bits(y)]);m.finish()
 elif a in [setPosition,setOrientation]:calls.append(['position' if a==setPosition else 'orientation',bits(y)]);writeVector(actor+(0x38 if a==setPosition else 0x44),vector(y));m.finish()
 elif a==0x140c7ed00:calls.append(['random']);m.finish(c['random'])
 elif a==0x140c7d6d8:
  value=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM0)&0xffffffff))[0];u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(value)),'little'));m.finish()
 elif a==0x14008c080:calls.append(['animateExternal']);m.finish()
 elif a==stage:calls.append(['stage',y&65535]);m.finish(c['animateResult'])
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x140988ed0 and c['mode']=='update':
  calls.append(['next',ui(actor+0x194),ui(actor+0x58)]);nextIndex+=1
  if c['advance']:
   m.wq(actor+0x228,node2 if c['advance']==1 else 0);m.wi(actor+0x194,777)
  m.finish(c['nextResult'])
 elif a in [0x1409845c0,0x1409848d0] and c['mode']=='update':
  calls.append(['basic' if a==0x1409845c0 else 'spiral']);writeVector(actor+0x38,[6,7,8]);writeVector(actor+0x204,[9,10,11]);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured path dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,queue,allocation,nextIndex,lookupIndex
 c=case;calls=[];queue=[];allocation=nextIndex=lookupIndex=0;u.mem_write(m.heap,bytes(0x20000));m.wq(0x1412df970,app)
 m.wq(actor,vt);m.wq(vt+0x120,setOrientation);m.wq(vt+0x128,setPosition);m.wq(vt+0x140,modelHandle);m.wq(obj,ovt);m.wq(ovt+0x140,modelHandle);u.mem_write(obj+0xc,bytes([c['objectType']]));writeVector(obj+0x38,c['objectPosition']);m.wq(model,mvt);m.wq(mvt+0x138,partPose)
 handle,hvt=m.heap+0x17000,m.heap+0x18000;m.wq(actor+0x78,handle if c['model'] else 0);m.wq(handle,hvt);m.wq(hvt+0x80,stage);u.mem_write(actor+0x5c,struct.pack('<H',c['stage']))
 for off,key in [(0x38,'position'),(0x44,'orientation'),(0x188,'endpoint'),(0x204,'velocity'),(0x210,'acceleration'),(0x174,'previousPosition')]:writeVector(actor+off,c[key])
 for off,key in [(0x194,'remaining'),(0x58,'elapsed'),(0x21c,'totalTime'),(0x198,'targetId'),(0x1f8,'oldPath')]:m.wi(actor+off,c[key])
 u.mem_write(actor+0x238,bytes([c['spiralSide']]))
 u.mem_write(actor+0x239,bytes([c['facing']]))
 m.wq(actor+0x220,linked);m.wq(actor+0x228,node if c['hasNode'] else 0);u.mem_write(actor+0x1e4,bytes([c['result']]));m.wq(actor+0x1a0,m.heap+0xd000);u.mem_write(m.heap+0xd000,b'impact\0');writeNode(node,c['node']);writeNode(node2,c['generated'])
 if c['mode']=='configure':
  for i in range(c['oldNodes']):ptr=m.heap+0xe000+i*0x100;writeNode(ptr,c['node']);queue.append(ptr)
  syncList()
 if c['mode']=='next':
  for i,d in enumerate(c['nextNodes']):
   ptr=m.heap+0xe000+i*0x100
   if d:writeNode(ptr,d)
   queue.append(ptr if d else 0)
  syncList()
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x1000,bytes(0x1100));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,c['path'] if c['mode'] in ['configure','flow'] else actor+0x44)
 start=0x140986390 if c['mode']=='build' and c['path']==3 else 0x140986890 if c['mode']=='build' else dict(configure=0x140987770,flow=0x140987770,initialize=0x140987f10,update=0x140984f00,next=0x140988ed0)[c['mode']]
 try:u.emu_start(start,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 if c['mode']=='flow':
  observations=[dict(state=snap(),calls=calls)];calls=[]
  for _ in range(c['maxSteps']):
   m.wi(actor+0x58,c['step']);m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor)
   u.emu_start(0x140984f00,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
   observations.append(dict(state=snap(),calls=calls));calls=[]
   if ui(actor+0x194)==0:break
  return dict(case=c,observations=observations)
 return dict(case=c,calls=calls,state=snap(),result=(u.reg_read(UC_X86_REG_RAX)&0xffffffff) if c['mode']=='next' else None)
nodeData=dict(point=[.25,.5,.75],attachment=[8,9,10],targetId=0x80000064,childPath=0,duration=500,threshold=0,radius=-1,spawnCount=0,kind=1)
generated=nodeData|dict(point=[12,13,14],attachment=[15,16,17],duration=777)
default=dict(path=1,oldPath=123,targetId=0x80000064,position=[1.25,-2,3.5],orientation=[.5,.25,.75],endpoint=[4,5,6],velocity=[2,3,4],acceleration=[5,6,7],previousPosition=[-1,-2,-3],remaining=1000,elapsed=16,totalTime=1000,hasNode=1,result=0,lookup=0,clientObject=1,model=1,pose=1,posePoint=[21,22,23],objectPosition=[31,32,33],objectType=5,oldNodes=2,node=nodeData,generated=generated,advance=0,nextResult=0,random=1,spiralSide=0,stage=3,animateResult=1,facing=0)
rows=[run(default|dict(mode='configure',path=path,targetId=target,lookup=lookup,clientObject=client,totalTime=duration,oldNodes=old))for path,target,lookup,client,duration,old in itertools.product([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,49,50,51,-1],[0x7f000000,0x80000064],[0,1],[0,1],[0,1000,0xffffffff],[0,2])]
rows += [run(default|dict(mode='initialize',targetId=target,lookup=lookup,objectType=typ,model=model,pose=pose,node=nodeData|dict(kind=kind),position=position,remaining=time))for target,lookup,typ,model,pose,kind,position,time in itertools.product([0x7f000000,0x80000064],[0,1],[4,5],[0,1],[0,1],[0,1,2,3,5,6,10,11,13,255],[[0,0,0],[.25,.5,.75]],[0,1000])]
rows += [run(default|dict(mode='update',lookup=lookup,secondLookup=second,model=model,pose=pose,result=result,remaining=time,elapsed=elapsed,node=nodeData|dict(kind=kind,targetId=target,radius=radius,threshold=threshold),advance=advance,nextResult=ret))for lookup,second,model,pose,result,time,elapsed,kind,target,radius,threshold,advance,ret in itertools.product([0,1],[0,1],[0,1],[0,1],[0,2,3,4],[16,1000],[16],[1,6,7],[0x7f000000,0x80000064],[-1,100],[0],[0,1,2],[0,1])]
rows += [run(default|dict(mode='update',remaining=time,elapsed=elapsed,node=nodeData|dict(kind=kind,radius=radius,threshold=threshold),advance=advance,nextResult=ret))for (time,elapsed),kind,radius,threshold,advance,ret in itertools.product([(0,0),(1,16),(16,16),(1000,16),(0xffffffff,0xffffffff)],[0,1,2,4,5,6,9,10,12,255],[-1,0,100],[0,999,0xffffffff],[0,1,2],[0,1])]
rows += [run(default|dict(mode=mode,hasNode=0))for mode in ['initialize','update']]
rows += [run(default|dict(mode='build',path=path,targetId=target,lookup=lookup,clientObject=client,totalTime=duration,random=random,endpoint=endpoint))for path,target,lookup,client,duration,random,endpoint in itertools.product([3,6],[0x7f000000,0x80000064],[0,1],[0,1],[0,2499,2500,2501,0xffffffff],[0,1,32767],[[1.25,-2,3.5],[4,5,6]])]
rows += [run(default|dict(mode='next',hasNode=has,model=model,lookup=lookup,animateResult=animate,elapsed=elapsed,nextNodes=[None if kind is None else generated|dict(kind=kind,duration=duration,targetId=target)for kind in kinds]))for has,model,lookup,animate,elapsed,kinds,duration,target in itertools.product([0,1],[0,1],[0,1],[0,1],[0,16,1000],[[],[None],[1],[11],[11,1],[1,11],[11,11,1]],[0,16,17,1000],[0x7f000000,0x80000064])]
rows += [run(default|dict(mode='flow',path=path,targetId=target,model=model,pose=pose,totalTime=duration,random=random,step=100,maxSteps=80,hasNode=0,facing=2))for path,target,model,pose,duration,random in itertools.product([1,2,3,5,6],[0x7f000000,0x80000064],[0,1],[0,1],[1000,2500,5000],[0,1])]
out=m.root/'backups/animations/native-client-projectile-path-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),counts={mode:sum(r['case']['mode']==mode for r in rows)for mode in ['configure','initialize','update','build','next','flow']},flowSteps=sum(len(r.get('observations',[]))-1 for r in rows if r['case']['mode']=='flow'),output=str(out))))
