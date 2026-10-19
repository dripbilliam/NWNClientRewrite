"""Original SaveObjectState with complete effect, variable/location, action
and transition save bodies. Opaque solver/JSON saves, VM script situations,
client lookup, GFF storage and repository primitives are captured boundaries.
"""
import importlib,sys,json,struct,copy,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
obj,gff,root,client,app,vm=[m.heap+n*0x2000 for n in range(1,7)];allocation=m.heap+0x30000
ranges=[]
for name in ['copy-save-object-state-owner','object-save-effect','object-save-variables','object-save-actions','object-save-transition','object-save-location']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
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
def exostring(p,s):
 b=s.encode('ascii');a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def word(p,v):u.mem_write(p,(v&65535).to_bytes(2,'little'))
def node(t):nodes.append(dict(fields={},type=t));return len(nodes)-1
def put(n,label,t,v):nodes[n]['fields'][label[:16]]=dict(type=t,value=v)
types={0x1401a2a80:0,0x1401a36f0:2,0x1401a30e0:6,0x1401a31d0:4,0x1401a34f0:5,0x1401a3350:8,0x1401a2d30:10}
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in types:
  t=types[a]
  if t==8:v=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM2)&0xffffffff))[0]
  elif t==10:v=text(z)
  elif t==6:v=str(z)
  elif t==0:v=z&255
  elif t==2:v=z&65535
  elif t==4:v=z&0xffffffff
  else:v=(z&0xffffffff)-0x100000000 if z&0x80000000 else z&0xffffffff
  put(m.si(y),string(w),t,v);m.finish(1);return
 if a==0x14019f4f0:
  idx=node(m.si(rsp+0x28)&0xffffffff);put(m.si(z),string(w),14,nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==0x14019f1e0:
  entries=[];lists.append(entries);put(m.si(z),string(w),15,entries);m.wi(y,len(lists)-1);m.finish(1);return
 if a==0x14019f2b0:
  idx=node(w&0xffffffff);lists[m.si(z)].append(nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a in [m.stop+0x100,m.stop+0x110]:
  kind,value=engineValues[x];calls.append(['empty',kind,value]);m.finish(1 if value is None else 0);return
 if a in [m.stop+0x120,m.stop+0x130]:
  kind,value=engineValues[x];calls.append(['engine',kind,value]);put(m.si(z),'EngineMarker',5,value);m.finish();return
 if a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(client if c['client']is not None else 0);return
 if a==0x1401690b0:m.finish(actionValues[y]);return
 if a==0x140169110:m.wq(y,actionNext[m.q(y)]);m.finish();return
 if a==0x140284d00:
  marker=situations[y];calls.append(['situation',marker]);put(m.si(w),'SituationMarker',5,marker);m.finish(1);return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured object-state dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def fillEffect(e):
 p=alloc(0x110);m.wq(p,int(e['id'],16));word(p+8,e['type']);word(p+10,e['subtype']|e['durationType']);m.wf(p+12,e['duration'])
 for off,key in [(0x10,'expiryDay'),(0x14,'expiryTime'),(0x18,'creatorId'),(0x1c,'spellId'),(0x20,'exposed'),(0x24,'showIcon'),(0x28,'casterLevel'),(0xe8,'skipOnLoad'),(0x108,'bypassImmunity')]:m.wi(p+off,e[key])
 m.wi(p+0x40,len(e['integers']));ints=alloc(max(1,len(e['integers']))*4);m.wq(p+0x48,ints)
 for i,v in enumerate(e['integers']):m.wi(ints+i*4,v)
 for i,v in enumerate(e['floats']):m.wf(p+0x50+i*4,v)
 for i,v in enumerate(e['strings']):exostring(p+0x60+i*16,v)
 for i,v in enumerate(e['objectIds']):m.wi(p+0xc0+i*4,v)
 for i,v in enumerate(e['vectors']):
  for j,n in enumerate(v):m.wf(p+0xd0+i*12+j*4,n)
 exostring(p+0xf8,e['customTag']);return p
def location(p,v):
 for i,n in enumerate(v['position']+v['nativeOrientation']):m.wf(p+i*4,n)
 m.wi(p+24,v['areaId'])
def fillVariables(rows):
 head=alloc(16);m.wq(obj+0x110,head);m.wq(head,head);previous=head
 for name,v in rows:
  p=alloc(0x90);m.wq(previous,p);m.wq(p+8,previous);m.wq(p,head);previous=p;exostring(p+0x10,name);m.wi(p+0x20,v['int']);m.wf(p+0x24,v['float']);m.wi(p+0x28,v['object']);exostring(p+0x30,v['string']);location(p+0x40,v['location']or dict(areaId=0x7f000000,position=[0,0,0],nativeOrientation=[0,0,0]))
  for off,key in [(0x60,'cswy'),(0x78,'json')]:
   wrapper=p+off;vtable=alloc(0x30);m.wq(wrapper,vtable);m.wq(vtable+0x10,m.stop+(0x100 if key=='cswy'else 0x110));m.wq(vtable+0x28,m.stop+(0x120 if key=='cswy'else 0x130));engineValues[wrapper]=(key,v[key])
 m.wq(head+8,previous)
def fillActions(entries):
 internal=alloc(24);m.wq(obj+0x100,internal);previous=0
 for action in entries:
  link=alloc(24);p=alloc(0xa0);actionValues[link]=p;actionNext[link]=0
  if previous:actionNext[previous]=link
  else:m.wq(internal,link)
  previous=link;m.wi(p,action['actionId']);word(p+0x98,action['groupId']);word(p+0x9a,len(action['parameters']))
  for i,param in enumerate(action['parameters']):
   t,value=param;m.wi(p+4+i*4,t)
   if t==4:ptr=alloc(16);exostring(ptr,value);m.wq(p+0x38+i*8,ptr)
   elif t==5:ptr=alloc(8);situations[ptr]=value;m.wq(p+0x38+i*8,ptr)
   else:m.wi(p+0x38+i*8,value)
def run(case):
 global c,cursor,nodes,lists,calls,engineValues,actionValues,actionNext,situations
 c=case;cursor=0;nodes=[];lists=[];calls=[];engineValues={};actionValues={};actionNext={};situations={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));node(0xffffffff);m.wi(root,0);m.wi(obj+8,0x80000123);u.mem_write(obj+12,bytes([c['type']]));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df910,vm);m.wi(client+0xd4,c['client']or 0)
 ptr=alloc(max(1,len(c['effects']))*8);m.wq(obj+0x150,ptr);m.wi(obj+0x158,len(c['effects']))
 for i,e in enumerate(c['effects']):m.wq(ptr+i*8,fillEffect(e))
 fillVariables(c['variables']);fillActions(c['actions']);exostring(obj+0x288,c['transition']['targetTag']);m.wi(obj+0x298,c['transition']['targetObjectId'])
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[obj,gff,root]):u.reg_write(reg,v)
 try:u.emu_start(0x14049a350,m.stop,count=300000)
 except Exception:print(json.dumps(dict(name=c['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,output=nodes[0],calls=calls)
def effect(i,duration):return dict(id=f'{i:016x}',type=91,subtype=16,durationType=duration,duration=1.25,skipOnLoad=257,expiryDay=0xffffffff,expiryTime=123,creatorId=0x80000001,spellId=-1,casterLevel=-1,exposed=256,showIcon=-1,bypassImmunity=2,customTag='tag\0tail',integers=[-1,0,3],floats=[1.25,-2.5,0,5],strings=['','one','nul\0tail','three','four','five'],objectIds=[0x7f000000,0x80000000,0xffffffff,42],vectors=[[1,2,3],[-4.25,8,9]])
def variable(**kw):
 v=dict(int=0,float=0,object=0x7f000000,string='',location=None,cswy=None,json=None);v.update(kw);return v
def base(name):return dict(name=name,type=5,client=None,effects=[],variables=[],actions=[],transition=dict(targetTag='',targetObjectId=0x7f000000))
cases=[base('empty')]
for typ in [5,6,9,16]:
 c=base('duration-filter-'+str(typ));c['type']=typ;c['effects']=[effect(0x20000000000000+i,i)for i in range(8)];cases.append(c)
for id in [0,1,0x20000000000001,0xffffffffffffffff]:
 c=base('id-'+str(id));c['effects']=[effect(id,1)];c['effects'][0]['integers']=[];cases.append(c)
c=base('variables-all-types');c['variables']=[['same',variable(**{'int':-5,'float':1.25,'object':0xffffffff,'string':'a\0b','location':dict(areaId=0x80000100,position=[1.25,2,3],nativeOrientation=[7,8,9]),'cswy':77,'json':88})],['object0',variable(object=0)],['empty',variable()]];cases.append(c)
for field in [None,0,1,-1,256]:
 c=base('action-client-'+str(field));c['client']=field;c['actions']=[dict(actionId=0xffffffff,groupId=65535,parameters=[[1,-123],[2,0x3fa00000],[3,0xffffffff],[4,'text\0tail'],[5,77],[6,258],[0,0],[16,0]]),dict(actionId=1,groupId=1,parameters=[])];cases.append(c)
c=base('transition-id');c['transition']=dict(targetTag='Target\0tail',targetObjectId=0x80000123);cases.append(c)
c=base('all-filtered-item');c['type']=6;c['effects']=[effect(1,0),effect(2,2),effect(3,3)];cases.append(c)
rng=random.Random(49)
for i in range(40):
 c=base('random-'+str(i));c['type']=rng.choice([5,6,9,16]);c['effects']=[effect(rng.randrange(1<<64),rng.randrange(8))for _ in range(rng.randrange(5))];c['variables']=[['v'+str(n),variable(**{'int':rng.choice([0,-1,123]),'float':rng.choice([0,1.5,-2.5]),'object':rng.choice([0,0x7f000000,0x80000111]),'string':rng.choice(['','text'])})]for n in range(rng.randrange(6))];cases.append(c)
observations=[run(c)for c in cases];output=m.root/'backups/animations/native-object-state-save-observations.json';output.write_text(json.dumps(dict(target=m.digest,cases=observations),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(output))))
