"""Unchanged original Package population, selection/help, recommendation,
Cancel/Escape, OK scalar metadata and Configure callback transfer. Table lookup,
resource allocation, GUI delivery, preference helpers, skill summary, associate
name service and customization activation are explicit providers. This proves
their coordinator boundaries, not their bodies, the catalog parser or pixels.
"""
import importlib.util,json,random,re,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,creature,stats,rules,classes,vt,rowmap,tabmap,gui,tlk=[m.heap+n for n in[0x1000,0x5000,0x9000,0x10000,0x20000,0x40000,0x42000,0x44000,0x46000,0x48000]]
ranges=[(0x1408e96b0,0x1408e9aa0),(0x1408e66f0,0x1408e6724),(0x1408e69d0,0x1408e6c46),(0x1408e7d90,0x1408e7dcb),(0x1408e11d0,0x1408e1200),(0x1408e3420,0x1408e3450),(0x1408e4620,0x1408e5362),(0x1408e1ec0,0x1408e2234),(0x1401eff30,0x1401eff8c),(0x1401e5ae0,0x1401e5b38)]
def byte(a,v):u.mem_write(a,bytes([v&255]))
def cstring(a):return bytes(u.mem_read(a,256)).split(b'\0')[0].decode('cp1252') if a else ''
def value(a):return cstring(m.q(a)) if m.q(a) else ''
def allocate(n):
 global bump
 p=m.heap+bump;bump+=(max(n,32)+15)&~15;assert bump<0xf0000;return p
def string(dest,text):
 raw=text.encode('cp1252');p=allocate(len(raw)+1);u.mem_write(p,raw+b'\0');m.wq(dest,p);m.wi(dest+8,len(raw));m.wi(dest+12,len(raw)+1)
def integer(text):
 s=str(text).strip();pat=re.match(r'^[+-]?(?:0[xX][0-9a-fA-F]+|\d+)',s)
 if not pat:return 0
 t=pat.group();sign=-1 if t.startswith('-')else 1;t=t.lstrip('+-');return sign*int(t,16 if t.lower().startswith('0x')else 10)
def table_entry(pointer,index,key):
 data=tables.get(pointer,{})
 rows=data.get('orderedRows',[]);row=rows[index]if 0<=index<len(rows)else{}
 for name,cell in row.items():
  if name.lower()==key.lower():return str(cell),str(cell)not in['','****']
 return str(data.get('defaultValue','****')),False
def hook(u,a,n,_):
 global custom
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg)for reg in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif a in [0x140c10370,0x140c4f024,0x140c10410,0x140715100,0x1401fb710,0x1401eb5c0,0x1401fb540,0x1407faf60,0x140234d80,0x140234e80,0x140236390,0x140115890,m.stop+0x10]:m.finish()
 elif a==0x14018ded0:u.mem_write(x,cstring(y).encode('cp1252')[:16].ljust(17,b'\0'));m.finish(x)
 elif a==0x14018dea0:u.mem_write(x,value(y).encode('cp1252')[:16].ljust(17,b'\0'));m.finish(x)
 elif a==0x14018de80:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
 elif a==0x14003d8c0:string(x,bytes(u.mem_read(y,z)).decode('cp1252'));m.finish(x)
 elif a==0x1401a62b0:
  name=cstring(y).lower();data=case['tables'].get(name,{})
  tables[x]=data;m.wq(x,vt);m.wi(x+0x50,len(data.get('orderedRows',[])));m.finish(x)
 elif a==0x1401a73a0:m.finish(1 if tables.get(x)else 0)
 elif a in [0x1401a7010,0x1401a68f0]:
  index=y&0xffffffff;index=index-0x100000000 if index>=0x80000000 else index
  text,ok=table_entry(x,index,value(z))
  if a==0x1401a7010:m.wi(w,integer(text))
  else:string(w,text if ok else '')
  m.finish(int(ok))
 elif a==0x140800c90:m.finish(creature if case.get('present',True)else 0)
 elif a==0x1407f0f60:m.finish(case['classId']&255)
 elif a==0x1408dcbc0:m.wq(x,vt);m.finish(x)
 elif a==0x1401ed630:
  count=m.si(panel+0x6f8);m.wq(tabmap+count*8,y);m.wi(rowmap+count*4,z);m.wi(panel+0x6f8,count+1);row_titles.append(None);m.finish()
 elif a==0x1401fb890:
  if x==panel+0x628:help_state['title']=y&0xffffffff
  elif x==panel+0x220:help_state['description']=y&0xffffffff
  elif row_titles:row_titles[-1]=y&0xffffffff
  m.finish()
 elif a==0x1401eb800:enabled[hex(x-panel)]=bool(y);m.finish()
 elif a==0x140198c60:
  found=(y&0xffffffff)not in case.get('missingText',[])
  if found:string(z,'Text'+str(y&0xffffffff))
  m.finish(int(found))
 elif a==0x14081b220:help_state['title']=int(cstring(y).removeprefix('Text'));m.finish()
 elif a==m.stop+0x20:help_state['description']=int(cstring(y).removeprefix('Text'));m.finish()
 elif a==0x1401fc440:codes.append(y&0xffffffff);m.finish()
 elif a==0x1407fa7c0:byte(stats+0x25f,z);m.finish()
 elif a==0x1407f9c40:byte(stats+0x260,z);m.finish()
 elif a==0x1407f9cb0:byte(stats+0x261,z);m.finish()
 elif a==0x1407f3cc0:m.finish(int(u.mem_read(stats+0x260,1)[0]))
 elif a==0x1407f3d30:m.finish(int(u.mem_read(stats+0x261,1)[0]))
 elif a==0x1402a3ba0:m.finish(0)
 elif a in [0x1407eb040,0x1407eb300,0x1407eb630]:calls.append([hex(a),value(y)]);m.finish(0)
 elif a==0x140235000:string(y,'OriginalAssociateName');m.finish(y)
 elif a==0x1404f3a40:
  m.wq(x,allocate(y*17));m.wi(x+12,y);m.finish()
 elif a==0x1409c3040:custom=x;m.wq(x,vt);m.finish(x)
 elif a==0x1401fbe40:activated.append(x==custom);m.finish()
 elif not any(lo<=a<=hi for lo,hi in ranges):raise AssertionError(f'Unmapped original Package dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v&0xffffffffffffffff)
 u.emu_start(address,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def snapshot():
 return dict(selected=m.si(panel+0x6e8),ids=[m.si(rowmap+i*4)for i in range(m.si(panel+0x6f8))],titles=row_titles.copy(),help=help_state.copy(),ok=enabled.get('0xd40',False),package=m.si(stats+0x6c),gold=m.si(creature+0x1b8),school=int(u.mem_read(stats+0x25f,1)[0]),domains=list(u.mem_read(stats+0x260,2)),equipment=[cstring(m.q(stats+0xc18)+i*17)for i in range(m.si(stats+0xc20))],codes=codes.copy(),calls=calls.copy(),customActivated=bool(activated),callbackTransferred=bool(custom and m.q(custom+0x80)==0x123456 and m.q(custom+0x88)==0x234567))
def run(c):
 global case,bump,tables,row_titles,help_state,enabled,codes,calls,custom,activated
 case=c;bump=0x60000;tables={};row_titles=[];help_state={'title':483,'description':487};enabled={};codes=[];calls=[];custom=0;activated=[]
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules);m.wq(0x1412df968,tlk);m.wq(rules+0x110,classes);m.wq(creature+0x3b0,stats)
 m.wq(vt,m.stop+0x10);m.wq(vt+0xd0,m.stop+0x20);m.wq(gui,vt);m.wq(panel,vt);m.wq(panel+0x230,gui);m.wi(panel+0x6e8,-1);m.wq(panel+0xa78,rowmap);m.wq(panel+0x6f0,tabmap);m.wq(panel+0x80,0x123456);m.wq(panel+0x88,0x234567)
 m.wi(stats+0x6c,777);m.wi(creature+0x1b8,999);byte(stats+0x69,1);byte(stats+0x6a,0);byte(stats+0x25f,7);byte(stats+0x260,8);byte(stats+0x261,9)
 cls=classes+(c['classId']&255)*0x530;m.wi(cls+0x4e4,c['default']);m.wi(cls+0x4f4,c.get('pickDomains',0));m.wi(cls+0x4f8,c.get('pickSchool',0));m.wi(cls+0x500,c.get('arcane',0));byte(cls+0x524,c.get('minAssociate',0))
 call(0x1408e96b0,[panel]);initial=snapshot();results=[]
 for operation in c['operations']:
  kind=operation['kind']
  if kind=='select':call(0x1401eff30,[panel+0x6d8,operation['index']]);call(0x1408e69d0,[panel,operation['index']])
  else:call({'title':0x1408e7d90,'recommend':0x1408e66f0,'cancel':0x1408e11d0,'escape':0x1408e3420,'ok':0x1408e4620,'configure':0x1408e1ec0}[kind],[panel])
  results.append(dict(operation=operation,state=snapshot()))
 return dict(case=c,initial=initial,results=results)
if __name__=='__main__':
 out=m.root/'backups/animations/native-creation-package-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 rng=random.Random(89696);cases=[]
 for index in range(72):
  class_id=[0,3,10][index%3];size=[0,1,8,260][index%4];rows=[]
  for i in range(size):
   row={'ClassID':class_id if i%3!=1 else class_id+1,'PlayerClass':1 if i%4 else 0,'Name':1000+i,'Description':2000+i,'Gold':100+i,'Equip2DA':'eq','School':2,'Domain1':3,'Domain2':5,'FeatPref2DA':'fp','SkillPref2DA':'sk'}
   if i%7==1:row.pop('ClassID')
   rows.append(row)
  if size>0:rows[0]={'ClassID':class_id,'PlayerClass':1,'Name':1000,'Description':2000,'Gold':123,'Equip2DA':'eq','School':2,'Domain1':3,'Domain2':5}
  ids=[i for i,row in enumerate(rows)if i!=255 and row.get('ClassID')==class_id and row.get('PlayerClass',0)!=0]
  operations=[{'kind':'title'},{'kind':'recommend'}]
  if len(ids)>1:operations.append({'kind':'select','index':len(ids)-1})
  operations.append({'kind':['ok','configure','cancel','escape'][index//4%4]})
  cases.append(dict(classId=class_id,default=0,tables={'packages':{'orderedRows':rows},'eq':{'orderedRows':[{'Label':'nw_test_a'},{'Label':'nw_test_b'}]}},missingText=[1000]if index%5==0 else [],operations=operations,pickSchool=index%2,pickDomains=index//2%2,minAssociate=0))
 rows=[run(c)for c in cases]
 out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,procedures=[hex(a)for a,b in ranges],rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows),operations=sum(len(r['results'])for r in rows))))
