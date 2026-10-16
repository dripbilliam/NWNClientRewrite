"""Complete original curve loader2e9ef0, restart2ea120 and transform loader
48f8c0, including the2ea110 tail thunk. Typed GFF and clock/world-time methods
are captured boundaries. Caller-owned output and scratch bytes are explicitly
seeded; no claim is made about uninitialized native stack contents in general.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
outPtr,gffPtr,rootPtr,labelPtr,statusPtr,appPtr,servicePtr,worldPtr=[m.heap+n*0x1000 for n in range(1,9)]
names=['AnimationSpeed','ScaleX','ScaleY','ScaleZ','RotateX','RotateY','RotateZ','TranslateX','TranslateY','TranslateZ']
def number(value):return dict(nan=float('nan'),inf=float('inf'),negativeInf=-float('inf')).get(value,value) if isinstance(value,str) else value
def normalize(value):
 if isinstance(value,float)and not math.isfinite(value):return 'nan'if math.isnan(value)else'inf'if value>0 else'negativeInf'
 if isinstance(value,list):return[normalize(v)for v in value]
 if isinstance(value,dict):return{k:normalize(v)for k,v in value.items()}
 return value
def ctext(ptr):return bytes(u.mem_read(ptr,256)).split(b'\0')[0].decode('ascii')
def read(record,kind,key,fallback):
 calls.append(['read',record,kind,key,fallback])
 if record=='root':return c.get('properties',{}).get(key,{}).get('direct',dict(status=0,value=fallback))
 return c['properties'][record].get('fields',{}).get(key,dict(status=0,value=fallback))
def hook(u,at,n,_):
 global clocks,worldCalls
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at in [0x1401a1650,0x1401a1770]:
  kind='float'if at==0x1401a1650 else'int';entry=read(descriptors[y],kind,ctext(z),m.rf(rsp+0x28)if kind=='float'else m.si(rsp+0x28));m.wi(w,entry['status'])
  if kind=='float':u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',number(entry['value'])),'little'));m.finish()
  else:m.finish(entry['value'])
  return
 if at==0x1401a04e0:
  name=ctext(w);calls.append(['struct',name]);status=c.get('properties',{}).get(name,{}).get('structStatus',0)
  if status:descriptors[y]=name
  m.finish(status);return
 if at==0x14016dd30:
  assert y==0;now=(int(c.get('clockBase','1000000'))+17*clocks)&0xffffffffffffffff;clocks+=1;calls.append(['clock',str(now)]);m.finish(now);return
 if at==0x14003d8b0:calls.append(['worldTimer']);m.finish(worldPtr if c.get('world',True) else 0);return
 if at==0x140597140:
  duration=m.xmm(UC_X86_REG_XMM1);calls.append(['worldSeconds',duration]);m.finish(c.get('delta',500));return
 if at==0x140597180:
  day,time=c.get('worldTimes',[[42,1234]])[min(worldCalls,len(c.get('worldTimes',[[42,1234]]))-1)];worldCalls+=1;calls.append(['worldTime',day,time]);m.wi(y,day);m.wi(z,time);m.finish();return
 if at==0x140596b40:
  delta=m.si(rsp+0x28)&0xffffffff;calls.append(['addWorld',y&0xffffffff,z&0xffffffff,w&0xffffffff,delta]);status=c.get('addStatus',0)
  if status==0:m.wi(m.q(rsp+0x30),(y+2)&0xffffffff);m.wi(m.q(rsp+0x38),(z+delta)&0xffffffff)
  m.finish(status);return
 if not any(lo<=at<hi for lo,hi in[(0x1402e9ef0,0x1402ea10e),(0x1402ea110,0x1402ea115),(0x1402ea120,0x1402ea249),(0x14048f8c0,0x14048fe11)]):raise AssertionError(f'Uncaptured visual transform dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,clocks,worldCalls,descriptors
 c=case;calls=[];clocks=worldCalls=0;descriptors={rootPtr:'root'};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8b8,servicePtr);m.wq(servicePtr+0x10,servicePtr);m.wq(0x1412df970,appPtr)
 size=640 if c['mode']=='transform' else 64;u.mem_write(outPtr,bytes([c.get('seed',165)])*size)
 if c['mode']=='restart':
  for offset,value in[(0,c.get('timer',0)),(12,c.get('lerp',1)),(24,123456),(28,-7)]:m.wi(outPtr+offset,value)
  for offset,value in[(4,c.get('to',3)),(8,c.get('from',1)),(16,c.get('duration',.1)),(20,.25)]:m.wf(outPtr+offset,number(value))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes([c.get('seed',165)])*0x700);m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c['mode']=='curve':
  name=c.get('name','ScaleX');u.mem_write(labelPtr,name.encode('ascii')+b'\0');m.wq(rsp+0x28,statusPtr);m.wf(rsp+0x30,c.get('fallback',1));args=[outPtr,gffPtr,rootPtr,labelPtr];address=0x1402e9ef0
 elif c['mode']=='restart':args=[outPtr];address=0x1402ea120
 else:args=[gffPtr,rootPtr,outPtr];address=0x14048f8c0
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 try:u.emu_start(address,m.stop,count=1000000)
 except Exception:print(json.dumps(normalize(dict(case=c,calls=calls[-12:],rip=hex(u.reg_read(UC_X86_REG_RIP))))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return normalize(dict(case=c,calls=calls,bytes=bytes(u.mem_read(outPtr,size)).hex()))
rows=[]
def prop(timer,lerp,duration=.1):return dict(structStatus=1,fields={name:dict(status=1,value=value)for name,value in dict(TimerType=timer,ValueTo=3,LerpType=lerp,ValueFrom=1,LerpDuration=duration,LerpProgress=.25,BehaviorFlags=123456,RepeatsRemaining=-7).items()})
for direct,root,lerp,timer,duration in itertools.product([0,1,2],[0,1,2],[0,1,2],[-1,0,1,2],[0,.1,-1]):
 p=prop(timer,lerp,duration);p['structStatus']=root;p['direct']=dict(status=direct,value=2 if direct else 1);rows.append(run(dict(mode='curve',properties=dict(ScaleX=p))))
for timer,lerp,same,duration in itertools.product([-1,0,1,2],[0,1,4],[False,True],[0,.125,-.1,2e13]):rows.append(run(dict(mode='restart',timer=timer,lerp=lerp,**{'from':3 if same else 1},duration=duration)))
for value in [-1e32,-1e13,-9223372036854.776,9223372036854.776,18446744073709.55,18446744073709.555,18446744073709.56,1e32,'nan','inf','negativeInf']:
 rows.append(run(dict(mode='restart',duration=value)));rows.append(run(dict(mode='curve',properties=dict(ScaleX=prop(0,1,value)))))
rows.append(run(dict(mode='restart',clockBase='18446744073709551610',duration=.01)))
for world,status in itertools.product([False,True],[0,-2]):
 rows.append(run(dict(mode='restart',timer=1,world=world,addStatus=status)));rows.append(run(dict(mode='curve',properties=dict(ScaleX=prop(1,1)),world=world,addStatus=status)))
for name,timer in itertools.product(names,[0,1]):rows.append(run(dict(mode='transform',properties={name:prop(timer,1)},worldTimes=[[42,1234],[43,5678]])))
rows.append(run(dict(mode='transform')))
rows.append(run(dict(mode='transform',properties={name:prop(i%3,1,.1+i)for i,name in enumerate(names)})))
rows.append(run(dict(mode='curve',properties=dict(ScaleX=dict(structStatus=1,direct=dict(status=0,value=2.25),fields=dict(LerpType=dict(status=1,value=1)))))))
out=m.root/'backups/animations/native-object-visual-transform-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
