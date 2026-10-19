"""Unchanged LoadGameEffect owner; captured typed GFF/heap/string/creator calls.
No original install writes, process injection or proprietary assets copied.
"""
import importlib,sys,json,struct,copy,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
obj,gff,root=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000
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
 f=records[m.si(node)]['fields'].get(name)
 return (f['value'],1)if f and f['type']==t else(default,0)
readers={0x1401a1470:6,0x1401a1950:2,0x1401a1650:8,0x1401a0f60:0,0x1401a1510:4,0x1401a1770:5}
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in readers:
  t=readers[a];default=m.q(rsp+0x28);default=struct.unpack('<f',struct.pack('<I',default&0xffffffff))[0]if t==8 else default
  value,status=typed(y,string(z),t,default);m.wi(w,status);calls.append(['read',string(z),t,status])
  if t==8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish();return
  if t==0:value=int((value&255)!=0)
  elif t==2:value&=65535
  m.finish(int(value));return
 if a==0x1401a1130:
  value,status=typed(z,string(w),10,text(m.q(rsp+0x30)));m.wi(m.q(rsp+0x28),status);exo(y,value);calls.append(['read',string(w),10,status]);m.finish(y);return
 if a==0x1401a02c0:
  value,status=typed(z,string(w),15,[]);calls.append(['list',string(w),status])
  if status:lists.append(value);m.wi(y,len(lists)-1)
  m.finish(status);return
 if a==0x1401a0370:m.finish(len(lists[m.si(y)]));return
 if a==0x1401a03f0:
  rows=lists[m.si(z)];status=int(w<len(rows));calls.append(['element',int(w),status])
  if status:records.append(rows[w]);m.wi(y,len(records)-1)
  m.finish(status);return
 if a==0x140425110:
  calls.append(['creator',y&0xffffffff,m.si(x+0x1c),m.si(x+0x28)]);m.wi(x+0x18,c['resolvedCreator'])
  if m.si(x+0x1c)==-1:m.wi(x+0x1c,777)
  if m.si(x+0x28)==-1:m.wi(x+0x28,888)
  m.finish();return
 if a==0x14003d8c0:
  b=bytes(u.mem_read(y,z&0xffffffff));exo(x,''if not b or b[0]==0 else b.decode('ascii'));m.finish();return
 if a==0x140c10368:m.finish(alloc(x));return
 if a==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x);return
 if a in [0x140c10370,0x140c10410]:m.finish();return
 if not 0x1404246d0<=a<=0x140424d49:raise RuntimeError(f'Uncaptured effect load dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def initial():return dict(id='1234567890abcdef',type=17,subtype=16,durationType=2,duration=3,skipOnLoad=1,expiryDay=5,expiryTime=6,creatorId=0x80000001,spellId=-1,casterLevel=-1,exposed=1,showIcon=1,bypassImmunity=2,customTag='old',propertyId='abcdef1234567890',integers=[1,2,3],floats=[11,12,13,14],strings=['a','b','c','d','e','f'],objectIds=[101,102,103,104],vectors=[[1,2,3],[4,5,6]])
def fill(e):
 m.wq(obj,int(e['id'],16));u.mem_write(obj+8,struct.pack('<HH',e['type'],e['subtype']|e['durationType']));m.wf(obj+12,e['duration'])
 for off,key in [(0x10,'expiryDay'),(0x14,'expiryTime'),(0x18,'creatorId'),(0x1c,'spellId'),(0x20,'exposed'),(0x24,'showIcon'),(0x28,'casterLevel'),(0xe8,'skipOnLoad'),(0x108,'bypassImmunity')]:m.wi(obj+off,e[key])
 m.wq(obj+0xf0,int(e['propertyId'],16));m.wi(obj+0x40,len(e['integers']));ptr=alloc(len(e['integers'])*4);m.wq(obj+0x48,ptr)
 for i,v in enumerate(e['integers']):m.wi(ptr+i*4,v)
 for i,v in enumerate(e['floats']):m.wf(obj+0x50+i*4,v)
 for i,v in enumerate(e['strings']):exo(obj+0x60+i*16,v)
 for i,v in enumerate(e['objectIds']):m.wi(obj+0xc0+i*4,v)
 for i,v in enumerate(e['vectors']):
  for j,n in enumerate(v):m.wf(obj+0xd0+i*12+j*4,n)
 exo(obj+0xf8,e['customTag'])
def snapshot():
 e=initial();e.update(id=f'{m.q(obj):016x}',type=int.from_bytes(u.mem_read(obj+8,2),'little'),subtype=int.from_bytes(u.mem_read(obj+10,2),'little')&~7,durationType=int.from_bytes(u.mem_read(obj+10,2),'little')&7,duration=m.rf(obj+12),propertyId=f'{m.q(obj+0xf0):016x}')
 for off,key in [(0x10,'expiryDay'),(0x14,'expiryTime'),(0x18,'creatorId'),(0x1c,'spellId'),(0x20,'exposed'),(0x24,'showIcon'),(0x28,'casterLevel'),(0xe8,'skipOnLoad'),(0x108,'bypassImmunity')]:e[key]=m.si(obj+off)&0xffffffff if key in ['expiryDay','expiryTime','creatorId']else m.si(obj+off)
 e['integers']=[m.si(m.q(obj+0x48)+i*4)for i in range(m.si(obj+0x40))];e['floats']=[m.rf(obj+0x50+i*4)for i in range(4)];e['strings']=[text(obj+0x60+i*16)for i in range(6)];e['objectIds']=[m.si(obj+0xc0+i*4)&0xffffffff for i in range(4)];e['vectors']=[[m.rf(obj+0xd0+i*12+j*4)for j in range(3)]for i in range(2)];e['customTag']=text(obj+0xf8);return e
def run(case):
 global c,cursor,records,lists,calls
 c=case;cursor=0x10000;records=[c['data']];lists=[];calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));fill(c['initial']);m.wi(root,0);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[obj,gff,root]):u.reg_write(reg,v)
 try:u.emu_start(0x1404246d0,m.stop,count=50000)
 except Exception:print(json.dumps(dict(name=c['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls[-5:])));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,output=snapshot(),calls=calls)
def f(t,v):return dict(type=t,value=v)
def node(fields):return dict(type=2,fields=fields)
def case(name,data):return dict(name=name,data=data,initial=initial(),resolvedCreator=0x80000123)
cases=[case('missing-all',node({})),case('mistyped-scalars',node({n:f(10,'wrong')for n in ['Id','Type','SubType','SkipOnLoad','Duration','NumIntegers','CreatorId']}))]
saved=json.loads((m.root/'backups/animations/native-object-state-save-observations.json').read_text())
for o in saved['cases']:
 for i,e in enumerate(o['output']['fields'].get('EffectList',{}).get('value',[])):cases.append(case(o['case']['name']+'-'+str(i),copy.deepcopy(e)))
# Fixed payload loops keep the shared prior element when a list ends early.
for name,t in [('FloatList',8),('StringList',10),('ObjectList',4),('VectorList',8)]:
 fields=dict(NumIntegers=f(5,3),IntList=f(15,[node(dict(Value=f(5,7)))]))
 fields[name]=f(15,[]);cases.append(case('empty-after-int-'+name,node(fields)))
 fields=copy.deepcopy(fields);fields[name]=f(15,[node(dict(Value=f(t,'one'if t==10 else 1.25 if t==8 else 0x80000001),ValueX=f(8,3),ValueY=f(8,4),ValueZ=f(8,5)))]);cases.append(case('short-'+name,node(fields)))
for value in [0,1,2,128,255]:cases.append(case('skip-bool-'+str(value),node(dict(SkipOnLoad=f(0,value)))))
out=m.root/'backups/animations/native-game-effect-load-observations.json';out.write_text(json.dumps(dict(target=m.digest,cases=[run(c)for c in cases]),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(out))))
