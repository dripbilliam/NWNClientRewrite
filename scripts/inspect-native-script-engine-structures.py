"""Original engine save/load/create wrappers and effect/event/location/talent
payload bodies. Captured GFF, successful heap/array/string storage, creator and
opaque SQL/solver/JSON calls. Original effect constructors allocate actual IDs.
"""
import importlib,sys,json,struct,copy,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
gff,root,obj,out,impl=[m.heap+n*0x1000 for n in range(1,6)];counter=0x141290568;fake=m.stop+0x100
ranges=[]
for name in ['vm-engine-save-owner','vm-engine-load-owner','vm-engine-create-owner','vm-event-save-owner','vm-event-load-owner','vm-event-constructor','vm-event-copy-owner','vm-event-integer-setsize','vm-talent-save-owner','vm-talent-load-owner','object-effect-default-constructor','object-save-effect','object-effect-load-owner','object-save-location']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
ranges += [(0x14048bd50,0x14048bd74),(0x1402e9830,0x1402e99a2)]
def alloc(n):
 global cursor
 assert 0<=n<0xb0000;p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xf0000;u.mem_write(p,b'\xa5'*n);sizes[p]=n;return p
def exo(p,s):
 b=s.encode('ascii');a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def string(p):
 b=bytearray()
 while u.mem_read(p,1)[0]:b.append(u.mem_read(p,1)[0]);p+=1
 return b.decode('ascii')
def word(p,v):u.mem_write(p,struct.pack('<H',v&65535))
def node(t):nodes.append(dict(type=t,fields={}));return len(nodes)-1
def put(n,label,t,v):nodes[n]['fields'][label[:16]]=dict(type=t,value=v)
def typed(p,label,t,d):
 f=records[m.si(p)]['fields'].get(label[:16]);return(f['value'],1)if f and f['type']==t else(d,0)
writers={0x1401a2a80:0,0x1401a36f0:2,0x1401a30e0:6,0x1401a31d0:4,0x1401a34f0:5,0x1401a3350:8,0x1401a2d30:10}
readers={0x1401a0ee0:0,0x1401a0f60:0,0x1401a1950:2,0x1401a1470:6,0x1401a1510:4,0x1401a1650:8,0x1401a1770:5}
opaqueCtors={0x1405877f0:5,0x140334390:6,0x14031cfa0:7}
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in writers:
  t=writers[a];v=text(z)if t==10 else str(z)if t==6 else struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM2)&0xffffffff))[0]if t==8 else z&255 if t==0 else z&65535 if t==2 else z&0xffffffff if t==4 else(z&0xffffffff)-0x100000000 if z&0x80000000 else z&0xffffffff;put(m.si(y),string(w),t,v);m.finish(1);return
 if a in readers:
  t=readers[a];d=m.q(rsp+0x28);d=struct.unpack('<f',struct.pack('<I',d&0xffffffff))[0]if t==8 else d;v,status=typed(y,string(z),t,d);m.wi(w,status)
  if t==8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',v),'little'));m.finish();return
  v=int(v)
  if a==0x1401a0f60:v=int((v&255)!=0)
  elif t==0:v&=255
  elif t==2:v&=65535
  m.finish(v);return
 if a==0x1401a1130:
  v,status=typed(z,string(w),10,text(m.q(rsp+0x30)));m.wi(m.q(rsp+0x28),status);exo(y,''if v.startswith('\0')else v);m.finish(y);return
 if a==0x14019f4f0:
  idx=node(m.si(rsp+0x28)&0xffffffff);put(m.si(z),string(w),14,nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==0x14019f1e0:
  rows=[];lists.append(rows);put(m.si(z),string(w),15,rows);m.wi(y,len(lists)-1);m.finish(1);return
 if a==0x14019f2b0:
  idx=node(w&0xffffffff);lists[m.si(z)].append(nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==0x1401a02c0:
  rows,status=typed(z,string(w),15,[])
  if status:lists.append(rows);m.wi(y,len(lists)-1)
  m.finish(status);return
 if a==0x1401a0370:m.finish(len(lists[m.si(y)]));return
 if a==0x1401a03f0:
  rows=lists[m.si(z)];status=int(w<len(rows))
  if status:records.append(rows[w]);m.wi(y,len(records)-1)
  m.finish(status);return
 if a==0x1401a04e0:
  value,status=typed(z,string(w),14,None)
  if status:records.append(value);m.wi(y,len(records)-1)
  m.finish(status);return
 if a in [0x140c10324,0x140c10368]:m.finish(alloc(x));return
 if a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish();return
 if a==0x140047300:u.mem_write(x,bytes(12));m.finish(x);return
 if a==0x14003d8c0:
  b=bytes(u.mem_read(y,z&0xffffffff));exo(x,''if not b or b[0]==0 else b.decode('ascii'));m.finish();return
 if a==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x);return
 if a==0x140c4f038:
  p=alloc(y)
  if x:u.mem_write(p,bytes(u.mem_read(x,min(sizes[x],y))))
  m.finish(p);return
 if a==0x1400f5140:
  count=m.si(x+8);old=m.q(x);p=alloc(y*16);u.mem_write(p,bytes(y*16))
  if count:u.mem_write(p,bytes(u.mem_read(old,count*16)))
  m.wq(x,p);m.wi(x+12,y);m.finish();return
 if a==0x140425110:m.wi(x+0x18,y);return m.finish()
 if a in opaqueCtors:
  vt=alloc(0x38);m.wq(x,vt);m.wq(vt+0x28,fake);m.wq(vt+0x30,fake+16);opaque[x]=dict(kind=opaqueCtors[a],marker=0);m.finish(x);return
 if a==fake:put(m.si(z),'Opaque',5,opaque[x]['marker']);m.finish(77);return
 if a==fake+16:
  value,_=typed(z,'Opaque',5,0);opaque[x]['marker']=value;m.finish(0);return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a in [0x140c10360,0x140c10370,0x140c4f024]:m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured engine-structure dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def fillEffect(p,e):
 m.wq(p,int(e['id'],16));word(p+8,e['type']);word(p+10,e['subtype']|e['durationType']);m.wf(p+12,e['duration']);m.wq(p+0x30,0);m.wq(p+0x38,0)
 for off,key in [(0x10,'expiryDay'),(0x14,'expiryTime'),(0x18,'creatorId'),(0x1c,'spellId'),(0x20,'exposed'),(0x24,'showIcon'),(0x28,'casterLevel'),(0xe8,'skipOnLoad'),(0x108,'bypassImmunity')]:m.wi(p+off,e[key])
 m.wq(p+0xf0,int(e.get('propertyId','0'),16));m.wi(p+0x40,len(e['integers']));ptr=alloc(len(e['integers'])*4);m.wq(p+0x48,ptr)
 for i,v in enumerate(e['integers']):m.wi(ptr+i*4,v)
 for i,v in enumerate(e['floats']):m.wf(p+0x50+i*4,v)
 for i,v in enumerate(e['strings']):exo(p+0x60+i*16,v)
 for i,v in enumerate(e['objectIds']):m.wi(p+0xc0+i*4,v)
 for i,v in enumerate(e['vectors']):
  for j,n in enumerate(v):m.wf(p+0xd0+i*12+j*4,n)
 exo(p+0xf8,e['customTag'])
def snapshotEffect(p):
 packed=int.from_bytes(u.mem_read(p+10,2),'little');e=dict(id=f'{m.q(p):016x}',type=int.from_bytes(u.mem_read(p+8,2),'little'),subtype=packed&~7,durationType=packed&7,duration=m.rf(p+12),propertyId=f'{m.q(p+0xf0):016x}')
 for off,key in [(0x10,'expiryDay'),(0x14,'expiryTime'),(0x18,'creatorId'),(0x1c,'spellId'),(0x20,'exposed'),(0x24,'showIcon'),(0x28,'casterLevel'),(0xe8,'skipOnLoad'),(0x108,'bypassImmunity')]:e[key]=m.si(p+off)&0xffffffff if key in ['expiryDay','expiryTime','creatorId']else m.si(p+off)
 e.update(integers=[m.si(m.q(p+0x48)+i*4)for i in range(m.si(p+0x40))],floats=[m.rf(p+0x50+i*4)for i in range(4)],strings=[text(p+0x60+i*16)for i in range(6)],objectIds=[m.si(p+0xc0+i*4)&0xffffffff for i in range(4)],vectors=[[m.rf(p+0xd0+i*12+j*4)for j in range(3)]for i in range(2)],customTag=text(p+0xf8));return e
eventArrays=[(8,'integers',4),(0x18,'floats',4),(0x28,'strings',16),(0x38,'objectIds',4)]
def fillEvent(p,e):
 word(p,e['type'])
 for off,key,stride in eventArrays:
  values=e[key];cap=e['nativeCapacities'][key];ptr=alloc(cap*stride)if cap else 0;m.wq(p+off,ptr);m.wi(p+off+8,len(values));m.wi(p+off+12,cap)
  if ptr:u.mem_write(ptr,bytes(cap*stride))
  for i,v in enumerate(values):(exo if stride==16 else m.wf if key=='floats'else m.wi)(ptr+i*stride,v)
def snapshot(kind,p):
 if kind in [0,4]:return snapshotEffect(p)
 if kind==1:
  e=dict(type=int.from_bytes(u.mem_read(p,2),'little'),nativeCapacities={})
  for off,key,stride in eventArrays:
   e[key]=[(text if stride==16 else m.rf if key=='floats'else m.si)(m.q(p+off)+i*stride)for i in range(m.si(p+off+8))];e['nativeCapacities'][key]=m.si(p+off+12)
   if key=='objectIds':e[key]=[v&0xffffffff for v in e[key]]
  return e
 if kind==2:return dict(areaId=m.si(p+24)&0xffffffff,position=[m.rf(p+i*4)for i in range(3)],nativeOrientation=[m.rf(p+12+i*4)for i in range(3)])
 if kind==3:return dict(type=m.si(p),id=m.si(p+4),classIndex=u.mem_read(p+8,1)[0],itemId=m.si(p+12)&0xffffffff,itemPropertyIndex=m.si(p+16),casterLevel=u.mem_read(p+20,1)[0],metamagic=u.mem_read(p+21,1)[0])
 return opaque[p]['marker']if kind in [5,6,7]else'previous'
def fill(kind,p,v):
 if kind in [0,4]:fillEffect(p,v)
 elif kind==1:fillEvent(p,v)
 elif kind==2:
  for i,n in enumerate(v['position']+v['nativeOrientation']):m.wf(p+i*4,n)
  m.wi(p+24,v['areaId'])
 elif kind==3:
  for off,key in [(0,'type'),(4,'id'),(12,'itemId'),(16,'itemPropertyIndex')]:m.wi(p+off,v[key])
  for off,key in [(8,'classIndex'),(20,'casterLevel'),(21,'metamagic')]:u.mem_write(p+off,bytes([v[key]&255]))
 elif kind in [5,6,7]:vt=alloc(0x38);m.wq(p,vt);m.wq(vt+0x28,fake);opaque[p]=dict(kind=kind,marker=v)
def run(c):
 global cursor,sizes,nodes,records,lists,opaque
 cursor=0x10000;sizes={};nodes=[];lists=[];opaque={};records=[c.get('data',dict(fields={}))];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wi(root,0);m.wq(counter,c['seed']);m.wq(out,obj);kind=c['kind'];mode=c['mode'];rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if mode=='save':node(0xffffffff);fill(kind,obj,c['value']);args=[impl,kind&0xffffffff,obj,gff];m.wq(rsp+0x28,root);entry=0x140552d60
 elif mode=='load':args=[impl,kind&0xffffffff,out,gff];m.wq(rsp+0x28,root);entry=0x1405521d0
 elif mode=='create':args=[impl,kind&0xffffffff];entry=0x14050d170
 elif mode=='event-copy':source=m.heap+0x7000;fillEvent(source,c['value']);u.mem_write(obj,bytes(0x48));args=[obj,source];entry=0x1404c68d0
 else:fillEvent(obj,c['value']);args=[obj,gff,root];entry=0x1404c6ba0
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v)
 try:u.emu_start(entry,m.stop,count=400000)
 except Exception:print(json.dumps(dict(name=c['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX);value=(snapshot(kind,result)if result else None)if mode=='create'else nodes[0]if mode=='save'else snapshot(kind,m.q(out)if mode=='load'else obj)
 return dict(case={**c,'seed':f'{c["seed"]:016x}'},output=value,status=None if mode in ['create','event-copy']else result&0xffffffff,nextId=f'{m.q(counter):016x}')
def event(n=0):return dict(type=11,integers=list(range(n)),floats=[1.25],strings=['text\0tail'],objectIds=[0x80000001,0xffffffff],nativeCapacities=dict(integers=0 if n==0 else 16 if n<=16 else 32,floats=16,strings=16,objectIds=16))
source=json.loads((m.root/'backups/animations/native-object-state-save-observations.json').read_text());effect=copy.deepcopy(next(c['case']['effects'][0]for c in source['cases']if c['case']['effects']));effect['propertyId']='fedcba9876543210';values={0:effect,1:event(17),2:dict(areaId=0xffffffff,position=[1.25,2,3],nativeOrientation=[7,8,9]),3:dict(type=-1,id=-7,classIndex=255,itemId=0x80000001,itemPropertyIndex=-2,casterLevel=254,metamagic=255),4:effect,5:51,6:61,7:71,8:None,-16:None}
cases=[]
for kind,value in values.items():cases.append(dict(name='save-'+str(kind),mode='save',kind=kind,value=copy.deepcopy(value),seed=0x2000000000000001))
saved=[run(c)for c in cases];observations=list(saved)
for row in saved:
 for seed in [0x2000000000000001,0xffffffffffffffff]:observations.append(run(dict(name='load-'+str(row['case']['kind'])+'-'+str(seed),mode='load',kind=row['case']['kind'],data=row['output'],seed=seed)))
empty=dict(type=0xffffffff,fields={'GameDefinedStrct':dict(type=14,value=dict(type=0,fields={}))})
for kind in range(8):observations.append(run(dict(name='load-empty-'+str(kind),mode='load',kind=kind,data=empty,seed=0x2000000000000001)))
eventData=saved[1]['output']['fields']['GameDefinedStrct']['value']
for n in [0,1,16,17,31]:observations.append(run(dict(name='append-event-'+str(n),mode='event-load',kind=1,value=event(n),data=eventData,seed=17)))
for kind in range(10):observations.append(run(dict(name='create-'+str(kind),mode='create',kind=kind,seed=0x2000000000000001)))
for n in [0,1,16,17,31]:observations.append(run(dict(name='copy-event-'+str(n),mode='event-copy',kind=1,value=event(n),seed=17)))
path=m.root/'backups/animations/native-script-engine-structures-observations.json';path.write_text(json.dumps(dict(target=m.digest,cases=observations),indent=2)+'\n');print(json.dumps(dict(cases=len(observations),output=str(path))))
