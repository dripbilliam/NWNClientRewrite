"""Execute original LoadActionQueue, AddAction and AddActionNodeParameter.
Capture GFF, heap/string, list primitives and opaque VM situation loading.
"""
import importlib,sys,json,struct,random,copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
obj,gff,root,internal=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000,m.heap+0x4000
ranges=[]
for name in ['object-action-load-owner','object-action-add-owner','object-action-add-parameter']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def alloc(n):
 global cursor
 assert 0<=n<0x10000;p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xf0000;return p
def exo(p,value):
 b=value.encode('ascii');a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def string(p):
 b=bytearray()
 while u.mem_read(p,1)[0]:b.append(u.mem_read(p,1)[0]);p+=1
 return b.decode('ascii')
def typed(node,name,t,default):
 f=records[m.si(node)]['fields'].get(name);return(f['value'],1)if f and f['type']==t else(default,0)
readers={0x1401a0ee0:0,0x1401a1950:2,0x1401a1510:4,0x1401a1650:8,0x1401a1770:5}
def hook(u,a,n,_):
 global tail
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in readers:
  t=readers[a];default=m.q(rsp+0x28);default=struct.unpack('<f',struct.pack('<I',default&0xffffffff))[0]if t==8 else default
  value,status=typed(y,string(z),t,default);m.wi(w,status)
  if t==8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish();return
  m.finish(value&255 if t==0 else value&65535 if t==2 else value);return
 if a==0x1401a1130:
  value,status=typed(z,string(w),10,text(m.q(rsp+0x30)));value=''if value.startswith('\0')else value;m.wi(m.q(rsp+0x28),status);exo(y,value);m.finish(y);return
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
 if a==0x140282ab0:
  marker=records[m.si(w)]['fields'].get('Marker',dict(value=0))['value'];calls.append(['situation',marker]);ptr=alloc(8);situations[ptr]=dict(marker=marker);m.wq(y,ptr);m.finish(1);return
 if a in [0x140c10324,0x140c10368]:m.finish(alloc(x));return
 if a==0x14003d8c0:
  b=bytes(u.mem_read(y,z&0xffffffff));exo(x,''if not b or b[0]==0 else b.decode('ascii'));m.finish();return
 if a==0x140169030:
  # Successful AddTail; the original post-append debug scan observes this list.
  assert x==internal;link=alloc(24);m.wq(link,0);m.wq(link+8,tail);m.wq(link+16,y)
  if tail:m.wq(tail,link)
  else:m.wq(internal,link)
  tail=link;queued.append(y);m.finish(link);return
 if a==0x140169110:
  link=m.q(y)
  if link:m.wq(y,m.q(link));m.finish(m.q(link+16))
  else:m.finish(0)
  return
 if a in [0x140c10360,0x140c10370,0x140c10410]:m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured action load dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def snapshot(p):
 count=int.from_bytes(u.mem_read(p+0x9a,2),'little');params=[]
 for i in range(count):
  t=m.si(p+4+i*4)&0xffffffff;slot=p+0x38+i*8
  v=text(m.q(slot))if t==4 else situations[m.q(slot)]if t==5 else m.q(slot)if t==6 else m.si(slot)
  params.append(dict(type=t,value=v))
 return dict(actionId=m.si(p)&0xffffffff,groupId=int.from_bytes(u.mem_read(p+0x98,2),'little'),parameterCount=count,parameters=params,nativeField9c=m.si(p+0x9c))
def run(case):
 global c,cursor,records,lists,calls,situations,queued,tail
 c=case;cursor=0x10000;records=[];lists=[];calls=[];situations={};queued=[];tail=0;u.mem_write(m.heap,bytes(0x100000));m.wq(obj+0x100,internal);u.mem_write(obj+0x18,struct.pack('<HH',c['nextGroup'],c['lastGroup']));m.wi(root,0)
 for data in ([c['seed']]if 'seed'in c else[])+[c['data']]:
  records=[data];lists=[];u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
  for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[obj,gff,root]):u.reg_write(reg,v)
  try:u.emu_start(0x1404963f0,m.stop,count=300000)
  except Exception:print(json.dumps(dict(name=c['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
  assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,output=dict(nextGroup=int.from_bytes(u.mem_read(obj+0x18,2),'little'),lastGroup=int.from_bytes(u.mem_read(obj+0x1a,2),'little'),nodes=[snapshot(p)for p in queued]),calls=calls)
def f(t,v):return dict(type=t,value=v)
def node(fields):return dict(type=1,fields=fields)
def param(t,v=0):return node(dict(Type=f(4,t),Value=f({1:5,2:8,3:4,4:10,5:14,6:0}.get(t,5),node(dict(Marker=f(5,v)))if t==5 else v)))
def action(id,group,params):return node(dict(ActionId=f(4,id),GroupActionId=f(2,group),NumParams=f(2,len(params)),Paramaters=f(15,params)))
def case(name,rows,next=0,last=0):return dict(name=name,data=node(dict(ActionList=f(15,rows))),nextGroup=next,lastGroup=last)
cases=[dict(name='missing',data=node({}),nextGroup=7,lastGroup=4),case('empty',[]),case('defaults',[node({})]),case('all-types',[action(19,0xffff,[param(1,-7),param(2,1.25),param(3,0xffffffff),param(4,'text\0tail'),param(5,17),param(6,255)]),action(12,0xfffe,[])]),case('group-wrap',[action(1,0xffff,[]),action(2,0xffff,[]),action(3,0xfffe,[])],0xfffe,4)]
for t,value in [(1,-2147483648),(2,-0.0),(3,0x80000001),(4,'\0discard'),(5,81),(6,128),(16,0),(0,0)]:cases.append(case('type-'+str(t),[action(7,13,[param(t,value),param(1,99)])]))
short=action(7,1,[param(2,2.5)]);short['fields']['NumParams']=f(2,4);cases.append(case('short-repeat',[short]))
first=action(1,1,[param(1,71)]);missing=action(2,2,[]);missing['fields']['NumParams']=f(2,2);del missing['fields']['Paramaters'];cases.append(case('missing-list-retains',[first,missing]))
empty=action(2,2,[]);empty['fields']['NumParams']=f(2,3);cases.append(case('empty-list-retains-struct',[first,empty]))
vm=param(5,91);vmMissing=node(dict(Type=f(4,5)));cases.append(case('vm-struct-retains',[action(7,1,[vm,vmMissing]),action(8,2,[vmMissing])]))
for next in [0,0xfffe]:
 c=case('append-retains-'+str(next),[action(19,0xfffe,[param(3,0x80000001)]),action(12,0xffff,[])],next,14);c['seed']=node(dict(ActionList=f(15,[action(37,0xffff,[param(5,17)])])));cases.append(c)
rng=random.Random(4963)
for i in range(60):
 rows=[]
 for j in range(rng.randrange(1,5)):
  params=[]
  for n in range(rng.randrange(13)):
   t=rng.randrange(1,7);value=rng.randint(-100000,100000)if t==1 else rng.choice([-2.5,0,1.25,128.75])if t==2 else rng.getrandbits(32)if t==3 else rng.choice(['','word','two\0tail'])if t==4 else rng.randrange(1000)if t==5 else rng.randrange(256);params.append(param(t,value))
  rows.append(action(rng.getrandbits(32),rng.choice([0xffff,0xfffe,rng.randrange(65534)]),params))
 cases.append(case('random-'+str(i),rows,rng.randrange(65535),rng.randrange(65535)))
out=m.root/'backups/animations/native-object-action-load-observations.json';out.write_text(json.dumps(dict(target=m.digest,cases=[run(c)for c in cases]),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(out))))
