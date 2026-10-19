"""Original visual/UUID savers, curve WriteGFF, Progress and RefreshInternally.
Native zero-map tree traversal and resref conversion execute. GFF/string heap,
clock/world timer and UUID eligibility are captured lower boundaries.
"""
import importlib,sys,json,struct,random,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
obj,gff,root,curve,world,exo,app=[m.heap+n*0x2000 for n in range(1,8)];allocation=m.heap+0x30000
ranges=[]
for name in ['visual-transform','material-overrides','texture-overrides','animation-overrides','misc-visuals','uuid','curve-owner','curve-progress','curve-refresh','transform-identity','vector-identity','curve-identity','resref-char-assign','resref-init']:
 d=json.loads((m.root/'backups/animations'/('rea-item-save-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def alloc(n):
 global cursor
 p=allocation+cursor;cursor+=(n+15)&~15;assert cursor<0xb0000;return p
def string(p):
 b=bytearray()
 while p:
  v=u.mem_read(p,1)[0]
  if not v:break
  b.append(v);p+=1
 return b.decode('ascii')
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def exostring(p,s):
 b=s.encode('ascii');a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def node(t):nodes.append(dict(fields={},type=t));return len(nodes)-1
def put(n,label,t,v):nodes[n]['fields'][label[:16]]=dict(type=t,value=v)
types={0x1401a2a80:0,0x1401a34f0:5,0x1401a3350:8,0x1401a2d30:10,0x1401a2ec0:11}
def hook(u,a,n,_):
 global clockIndex,subtractIndex
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in types:
  t=types[a]
  if t==8:v=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM2)&0xffffffff))[0]
  elif t==10:v=text(z)
  elif t==11:v=string(z)[:16]
  elif t==0:v=z&255
  else:v=(z&0xffffffff)-0x100000000 if z&0x80000000 else z&0xffffffff
  put(m.si(y),string(w),t,v);m.finish(1);return
 if a==0x14019f4f0:
  idx=node(m.si(rsp+0x28)&0xffffffff);put(m.si(z),string(w),14,nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==0x14019f1e0:
  values=[];lists.append(values);put(m.si(z),string(w),15,values);m.wi(y,len(lists)-1);m.finish(1);return
 if a==0x14019f2b0:
  idx=node(w&0xffffffff);lists[m.si(z)].append(nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==0x140c10368:m.finish(alloc(x));return
 if a==0x140c10370:m.finish();return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x140505390:m.finish(int(c['objectType']&255 in [4,5,6,7,9,10,12,13,14]));return
 if a==0x14016dd30:
  calls.append(['clock']);value=int(c['ticks'][min(clockIndex,len(c['ticks'])-1)]);clockIndex+=1;m.finish(value);return
 if a==0x14003d8b0:calls.append(['worldTimer']);m.finish(world if c['world']else 0);return
 if a==0x140597180:
  calls.append(['worldTime']);m.wi(y,c['now']['day']);m.wi(z,c['now']['time']);m.finish();return
 if a==0x140597a20:
  args=[y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff];calls.append(['subtract',*args]);result=c['subtracts'][min(subtractIndex,len(c['subtracts'])-1)];subtractIndex+=1
  if result['status']==0:m.wi(m.q(rsp+0x30),result['day']);m.wi(m.q(rsp+0x38),result['time'])
  m.finish(result['status']);return
 if a==0x140597140:
  value=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM1)&0xffffffff))[0];calls.append(['worldSeconds',value]);m.finish(c['worldDelta']);return
 if a==0x140596b40:
  calls.append(['add',y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&0xffffffff]);result=c['added']
  if result['status']==0:m.wi(m.q(rsp+0x30),result['day']);m.wi(m.q(rsp+0x38),result['time'])
  m.finish(result['status']);return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured visual-save dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def curveBytes(v):
 b=bytearray(64)
 for off,key in [(0,'timer'),(12,'lerp'),(24,'flags'),(28,'repeats')]:struct.pack_into('<I',b,off,v[key]&0xffffffff)
 for off,key in [(4,'to'),(8,'from'),(16,'duration'),(20,'progress')]:struct.pack_into('<f',b,off,v[key])
 for off,key in [(32,'start'),(48,'end')]:struct.pack_into('<Q',b,off,int(v[key])&0xffffffffffffffff)
 for off,key in [(40,'worldStart'),(56,'worldEnd')]:struct.pack_into('<II',b,off,v[key]['day'],v[key]['time'])
 return b
def run(case):
 global c,cursor,nodes,lists,calls,clockIndex,subtractIndex
 c=case;cursor=0;nodes=[];lists=[];calls=[];clockIndex=subtractIndex=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));node(0xffffffff);m.wi(root,0)
 m.wq(0x1412df8b8,exo);m.wq(exo+0x10,exo);m.wq(0x1412df970,app)
 u.mem_write(obj+0xc,bytes([c['objectType']&255]));m.wq(obj+0x2e8,obj);exostring(obj+0x2f8,c['uuid'])
 for off,key in [(0x254,'r'),(0x258,'g'),(0x25c,'b'),(0x268,'distance')]:m.wf(obj+off,c['misc'][key])
 for off,key in [(0x260,'cursor'),(0x26c,'mask'),(0x270,'bubble')]:m.wi(obj+off,c['misc'][key])
 exostring(obj+0x278,c['misc']['text'])
 for off,key,size in [(0x2b8,'materials',108),(0x2c8,'textures',34),(0x2d8,'animations',34)]:
  entries=c[key];ptr=alloc(max(1,len(entries))*size);m.wq(obj+off,ptr);m.wi(obj+off+8,len(entries))
  for i,entry in enumerate(entries):
   p=ptr+i*size
   if key=='materials':
    m.wi(p,entry['type']);u.mem_write(p+4,entry['material'].encode('ascii')[:16].ljust(17,b'\0'));u.mem_write(p+21,entry['param'].encode('ascii')[:64].ljust(65,b'\0'));m.wi(p+88,entry['int'])
    for n,v in enumerate(entry['floats']):m.wf(p+92+n*4,v)
   else:u.mem_write(p,entry[0].encode('ascii')[:16].ljust(17,b'\0')+entry[1].encode('ascii')[:16].ljust(17,b'\0'))
 curvePointers=[]
 if c['transforms']is not None:
  mapPtr=alloc(16);head=alloc(40);m.wq(obj+0x2b0,mapPtr);m.wq(mapPtr,head);u.mem_write(head+25,b'\x01');m.wq(head,head)
  previous=head
  for transform in sorted(c['transforms'],key=lambda x:x['scope']):
   p=alloc(680);u.mem_write(p+25,b'\0');m.wq(p,head);m.wq(p+8,previous);m.wq(p+16,head);m.wi(p+32,transform['scope'])
   if previous==head:m.wq(head,p)
   else:m.wq(previous+16,p)
   previous=p
   for i,v in enumerate(transform['curves']):u.mem_write(p+40+i*64,bytes(curveBytes(v)));curvePointers.append(p+40+i*64)
 u.mem_write(curve,bytes(curveBytes(c['curve'])))
 entries={'all':[0x14049a780,0x140499f20,0x14049a640,0x140499c10,0x14049a230,0x140505c70],'curve':[0x1402ea250],'progress':[0x1402e9cd0]}
 for entry in entries[c['mode']]:
  rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
  this=curve if c['mode']!='all'else obj+0x2e8 if entry==0x140505c70 else obj
  for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[this,gff,root,0]):u.reg_write(r,v)
  if c['mode']=='curve':name=alloc(16);u.mem_write(name,b'Curve\0');u.reg_write(UC_X86_REG_R9,name)
  try:u.emu_start(entry,m.stop,count=500000)
  except Exception:print(json.dumps(dict(name=c['name'],entry=hex(entry),rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls[-8:])));raise
  assert u.reg_read(UC_X86_REG_RIP)==m.stop,(c['name'],hex(u.reg_read(UC_X86_REG_RIP)))
 return dict(case=c,output=nodes[0],calls=calls,curve=list(u.mem_read(curve,64)),transformCurves=[list(u.mem_read(p,64))for p in curvePointers],progressBits=u.reg_read(UC_X86_REG_XMM0)&0xffffffff if c['mode']=='progress'else None)
def cv(**kw):
 v=dict(timer=0,to=0,**{'from':0},lerp=0,duration=0,progress=0,flags=0,repeats=0,start='0',end='0',worldStart=dict(day=0,time=0),worldEnd=dict(day=0,time=0));v.update(kw);return v
def base(name,mode='all'):return dict(name=name,mode=mode,objectType=6,uuid='',misc=dict(r=-1,g=-1,b=-1,distance=45,cursor=-1,mask=15,bubble=0,text=''),materials=[],textures=[],animations=[],transforms=None,curve=cv(),ticks=['100','200'],world=True,now=dict(day=1,time=100),subtracts=[dict(status=0,day=0,time=500),dict(status=0,day=0,time=1000)],worldDelta=2000,added=dict(status=0,day=1,time=2100))
cases=[base('defaults')]
for t in [4,5,6,7,8,9,10,12,13,14,15,16,262]:
 c=base('uuid-'+str(t));c['objectType']=t;c['uuid']='abcd\0tail';cases.append(c)
for count in [0,1,3,1025]:
 c=base('materials-'+str(count));c['materials']=[dict(type=[1,2,258][i%3],material='MatName\0tail',param='Parameter',int=-123,floats=[1.25,2.5,-3.5,4])for i in range(count)];cases.append(c)
c=base('replacement-case');c['textures']=[['UpperCaseOld','NewTexture']];c['animations']=[['aNiMaTion','Replace']];c['misc'].update(r=.5,g=.75,b=.25,distance=100,cursor=7,mask=-1,bubble=2,text='Text\0tail');cases.append(c)
for kind in ['empty','zero','nonzero','repeat']:
 c=base('transform-'+kind);c['transforms']=[]if kind=='empty'else[dict(scope=-2,curves=[cv()for _ in range(10)]),dict(scope=12,curves=[cv()for _ in range(10)])]
 if kind=='nonzero':c['transforms'][1]['curves'][0]['to']=1
 if kind=='repeat':c['transforms'][0]['curves'][9]=cv(lerp=1,to=1,repeats=1,duration=2,flags=1,start='0',end='50')
 cases.append(c)
for timer,lerp,repeat,progress in itertools.product([0,1,2],[0,1],[-2,-1,0,1,2],[0,.5,1]):
 c=base(f'progress-{timer}-{lerp}-{repeat}-{progress}','progress');c['curve']=cv(timer=timer,lerp=lerp,to=2,repeats=repeat,progress=progress,duration=2,flags=1,start='0',end='50',worldEnd=dict(day=1,time=50));cases.append(c)
for start,end,now in [(0,1000,500),(500,1000,0),(0,2**63+1,1),(2**63,2**64-1,2**63+1),(0,2**62+2**38+1,1),(2**64-1,50,10)]:
 c=base('clock-fraction-'+str(end),'progress');c['curve']=cv(lerp=1,to=2,start=str(start),end=str(end));c['ticks']=[str(now),str(now)];cases.append(c)
for world,denom,status in [(False,1000,0),(True,0,0),(True,1000,-2),(True,1000,0)]:
 c=base(f'world-fraction-{world}-{denom}-{status}','curve');c['world']=world;c['curve']=cv(timer=1,lerp=1,to=2,duration=2,repeats=1,worldEnd=dict(day=1,time=200));c['subtracts'][1].update(time=denom,status=status);cases.append(c)
observations=[run(c)for c in cases]
output=m.root/'backups/animations/native-object-visual-save-observations.json';output.write_text(json.dumps(dict(target=m.digest,cases=observations),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(output))))
