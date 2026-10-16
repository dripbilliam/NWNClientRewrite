"""Full original LoadVarTable507640, LoadLocation2e9830, GetLocation507510,
MatchIndex507f00, DeleteIndex506e40 and SetInt5086e0 (no creature journal).
Typed GFF, map lookup/node allocation, structured-engine load/copy/set, and
native name hashing are captured lower boundaries. This is not a Cassowary,
JSON parser, unordered-map/embedded-NUL-name or journal-side-effect oracle.
Stack locals are deliberately zero-seeded; a first failed GetStruct's real
uninitialized output is not determined. Subsequent failed reads retain outputs.
"""
import importlib.util,itertools,json,struct,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
tablePtr,headPtr,bucketPtr,gffPtr,rootPtr,vtPtr,inputPtr,outPtr=[m.heap+n*0x1000 for n in range(1,9)]
ranges=[(0x140507640,0x140507edc),(0x1402e9830,0x1402e99a1),(0x140507510,0x140507564),(0x140507f00,0x140507ff3),(0x140506e40,0x140507000),(0x1405086e0,0x140508920)]
F=lambda t,v:dict(type=t,value=v)
R=lambda **fields:dict(type=0xffffffff,fields=fields)
emptyLocation=dict(areaId=0x7f000000,position=[0,0,0],nativeOrientation=[0,0,0])

def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr

def owning(ptr,value):
 raw=value.encode('cp1252');target=alloc(len(raw)+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)

def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''

def text(ptr):return bytes(u.mem_read(ptr,128)).split(b'\0')[0].decode('cp1252')

def vector(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))

def location(ptr):return dict(areaId=m.si(ptr+24)&0xffffffff,position=vector(ptr),nativeOrientation=vector(ptr+12))

def writeLocation(ptr,value):u.mem_write(ptr,struct.pack('<6fI',*(value['position']+value['nativeOrientation']),value['areaId']&0xffffffff))

def token(value):
 global nextToken
 nextToken+=1;contexts[nextToken]=value;return nextToken

def context(ptr):return contexts.get(m.si(ptr),{}) if ptr else {}

def field(record,key,t,default):
 f=record.get('fields',{}).get(key) if isinstance(record,dict) else None
 return (f['value'],1) if f and f['type']==t else (default,0)

def node(name):
 if name in nodes:return nodes[name]
 ptr=alloc(0xa0);u.mem_write(ptr,bytes(0xa0));m.wq(ptr,headPtr);m.wq(ptr+8,headPtr);owning(ptr+16,name);m.wi(ptr+0x28,0x7f000000);writeLocation(ptr+0x40,emptyLocation)
 for offset in [0x60,0x78]:m.wq(ptr+offset,vtPtr);structures[ptr+offset+8]=None
 nodes[name]=ptr;return ptr

def putStructured(name,offset,value):
 if value is not None:ptr=node(name);structures[ptr+offset+8]=value
 elif name in nodes:structures[nodes[name]+offset+8]=None;prune(name)

def prune(name):
 ptr=nodes[name]
 if m.si(ptr+0x20)==0 and m.rf(ptr+0x24)==0 and m.si(ptr+0x28)==0x7f000000 and m.si(ptr+0x38)==0 and location(ptr+0x40)==emptyLocation and structures.get(ptr+0x68) is None and structures.get(ptr+0x80) is None:del nodes[name]

def hook(u,at,n,_):
 global pendingName
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x1401a02c0:
  key=text(w);value,ok=field(context(z),key,15,None);calls.append(['read',15,key,None])
  if ok:m.wi(y,token(value))
  m.finish(ok);return
 if at==0x1401a0370:m.finish(len(context(y)));return
 if at==0x1401a03f0:
  values=context(z);ok=isinstance(values,list) and w<len(values)
  if ok:m.wi(y,token(values[w]))
  m.finish(int(ok));return
 if at==0x1401a04e0:
  key=text(w);value,ok=field(context(z),key,14,None);calls.append(['read',14,key,None]);
  if ok:m.wi(y,token(value))
  m.finish(ok);return
 if at in [0x1401a1510,0x1401a1770,0x1401a1650]:
  t={0x1401a1510:4,0x1401a1770:5,0x1401a1650:8}[at];key=text(z);default=m.rf(rsp+0x28) if t==8 else m.si(rsp+0x28);value,ok=field(context(y),key,t,default);calls.append(['read',t,key,default]);m.wi(w,ok)
  if t==8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
  else:m.finish(value)
  return
 if at==0x1401a1130:
  key=text(w);value,ok=field(context(z),key,10,'');calls.append(['read',10,key,'']);owning(y,value);m.wi(m.q(rsp+0x28),ok);m.finish(y);return
 if at==0x140508c40:pendingName=stored(z);m.wq(y,nodes.get(pendingName,headPtr));m.finish(y);return
 if at==0x140506ab0:m.finish(node(pendingName));return
 if at==0x14048b0d0:m.wq(y,nodes[pendingName]);m.finish(y);return
 if at==0x14016b780:m.finish(0);return
 if at==0x14045da90:m.finish(int(location(x+0x20)!=emptyLocation));return
 if at==m.stop+0x10:m.finish(int(structures.get(x+8) is None));return
 if at==m.stop+0x20:structures[x+8]=None;m.finish();return
 if at==0x14035aaf0:m.finish();return
 if at==0x14003d8c0:owning(x,bytes(u.mem_read(y,z&0xffffffff)).decode('cp1252'));m.finish(x);return
 if at==0x1405086e0:calls.append(['setInt',stored(y),z if z<1<<31 else z-(1<<32),w&0xffffffff]);return
 if at==0x140334390:m.wq(x,vtPtr);structures[x+8]=None;m.finish(x);return
 if at==0x14033aa60:calls.append(['loadCswy']);structures[x+8]=c.get('cswy');m.finish(1);return
 if at==0x140506d30:structures[x]=structures.get(y);m.finish(x);return
 if at==0x1405084a0:value=structures.get(z+8);name=stored(y);calls.append(['setCswy',name,value]);putStructured(name,0x60,value);m.finish();return
 if at==0x1403376c0:m.finish();return
 if at==0x14031cfa0:calls.append(['jsonDefault']);m.wq(x,vtPtr);structures[x+8]=None;m.finish(x);return
 if at==0x1403157a0:calls.append(['parseJson',stored(y)]);m.wq(x,vtPtr);structures[x+8]=c.get('jsonResult');m.finish(x);return
 if at==0x14034c650:structures[x]=structures.get(y);m.finish(x);return
 if at==0x140506ce0:structures[x]=None;m.finish();return
 if at==0x140508920:value=structures.get(z+8);name=stored(y);calls.append(['setJson',name,value]);putStructured(name,0x78,value);m.finish();return
 if at==0x140c10360:
  if y==0x90:
   for name,ptr in list(nodes.items()):
    if ptr==x:del nodes[name]
  m.finish();return
 if at==0x140c10370:m.finish();return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=at<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured script-variable dependency {at:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)

def snapshot():
 out={}
 for name,ptr in nodes.items():out[name]=dict(int=m.si(ptr+0x20),float=m.rf(ptr+0x24),object=m.si(ptr+0x28)&0xffffffff,string=stored(ptr+0x30),location=None if location(ptr+0x40)==emptyLocation else location(ptr+0x40),cswy=structures.get(ptr+0x68),json=structures.get(ptr+0x80))
 return out

def run(case):
 global c,cursor,contexts,nextToken,nodes,structures,calls,pendingName
 c=case;cursor=0x10000;contexts={1:c.get('data',R())};nextToken=1;nodes={};structures={};calls=[];pendingName='';u.mem_write(m.heap,bytes(0x100000));m.wq(tablePtr+8,headPtr);m.wq(tablePtr+0x18,bucketPtr);m.wq(headPtr,headPtr);m.wq(headPtr+8,headPtr);m.wq(bucketPtr,headPtr);m.wq(bucketPtr+8,headPtr);m.wq(vtPtr+0x10,m.stop+0x10);m.wq(vtPtr+0x20,m.stop+0x20);m.wi(rootPtr,1)
 for name,value in c.get('initial',{}).items():
  ptr=node(name);m.wi(ptr+0x20,value.get('int',0));m.wf(ptr+0x24,value.get('float',0));m.wi(ptr+0x28,value.get('object',0x7f000000));owning(ptr+0x30,value.get('string',''));writeLocation(ptr+0x40,value.get('location',emptyLocation));structures[ptr+0x68]=value.get('cswy');structures[ptr+0x80]=value.get('json')
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x700,bytes(0x800));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);args=[tablePtr,gffPtr,rootPtr];address=0x140507640
 if c.get('get') is not None:address=0x140507510;owning(inputPtr,c['get']);args=[tablePtr,outPtr,inputPtr]
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value)
 try:u.emu_start(address,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,snapshot=snapshot(),rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,entries=snapshot(),location=location(outPtr) if c.get('get') is not None else None)

def row(t,value=None,valueType=None,name='Same',nameType=10,typeType=4):
 fields=dict(Name=F(nameType,name),Type=F(typeType,t))
 if value is not None:fields['Value']=F(valueType if valueType is not None else {1:5,2:8,3:10,4:4,5:14,6:14,7:14}.get(t,5),value)
 return R(**fields)

rows=[]
initial={'Same':dict(int=7,float=2.5,object=91,string='old',location=dict(areaId=77,position=[1,2,3],nativeOrientation=[4,5,6]),cswy=dict(old='solver'),json=dict(old='json'))}
for t,value in [(1,0),(1,-7),(1,2147483647),(2,0),(2,-.125),(2,1.23456789),(3,''),(3,'a\0tail'),(4,0),(4,0x7f000000),(4,0xffffffff),(5,R()),(5,R(Area=F(4,0x7f000000))),(5,R(Area=F(4,0x7f000000),PositionX=F(8,5.1))),(5,R(Area=F(4,77),OrientationZ=F(8,1.25)))]:
 for old in [{},initial]:rows.append(run(dict(data=R(VarTable=F(15,[row(t,value)])),initial=old)))
for t,old in itertools.product(range(10),[{},initial]):rows.append(run(dict(data=R(VarTable=F(15,[row(t)])),initial=old)))
for t in range(1,6):
 for wrong in [0,4,5,8,10]:
  if wrong=={1:5,2:8,3:10,4:4,5:14}[t]:continue
  rows.append(run(dict(data=R(VarTable=F(15,[row(t,'wrong' if wrong==10 else 25,valueType=wrong)])),initial=initial)))
for t,cswy,jsonResult,present in itertools.product([6,7],[None,dict(solver=1)],[None,False,0,[],{},dict(parsed=1)],[False,True]):
 data=R(JSON=F(10,'{"fixture":1}')) if present else R();rows.append(run(dict(data=R(VarTable=F(15,[row(t,data)])),initial=initial,cswy=cswy,jsonResult=jsonResult)))
for loc in [emptyLocation,dict(areaId=0x7f000000,position=[1,0,0],nativeOrientation=[0,0,0]),dict(areaId=77,position=[0,0,0],nativeOrientation=[0,0,0])]:
 rows.append(run(dict(get='Same',initial={'Same':dict(location=loc)})))
rows.append(run(dict(get='missing')))
rows.extend([run(dict(data=R())),run(dict(data=R(VarTable=F(10,'wrong'))))])
rows.append(run(dict(data=R(VarTable=F(14,R())))))
for record in [row(1,7,nameType=0,name=0),row(1,7,nameType=11,name='wrong'),row(1,7,typeType=5),row('1',7,valueType=5,typeType=10)]:rows.append(run(dict(data=R(VarTable=F(15,[record])))))
rows.append(run(dict(data=R(VarTable=F(15,[row(5,R(Area=F(4,0x7f000000),OrientationZ=F(8,1.5)))])))))
rows.append(run(dict(get='Same',initial={'Same':dict(int=9)})))
for value in [dict(json=False),dict(cswy=dict(solver=1))]:rows.append(run(dict(data=R(VarTable=F(15,[row(1,0)])),initial={'Same':value})))
for t in [5,6,7]:
 value=R(Area=F(4,77),PositionX=F(8,12.5),JSON=F(10,'{"fixture":1}'))
 rows.append(run(dict(data=R(VarTable=F(15,[row(t,value),row(t,name='Other')])),cswy=dict(solver=1),jsonResult=dict(parsed=1))))
rng=random.Random(20261016)
for _ in range(100):
 entries=[]
 for n in range(12):
  t=rng.randrange(1,5);value={1:rng.randrange(-9,10),2:rng.uniform(-4,4),3:rng.choice(['','word','Other']),4:rng.choice([0,91,0x7f000000])}[t];entries.append(row(t,value,name=rng.choice(['Same','same','Other',''])))
 rows.append(run(dict(data=R(VarTable=F(15,entries)),initial={})))
out=m.root/'backups/animations/native-script-variable-load-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
