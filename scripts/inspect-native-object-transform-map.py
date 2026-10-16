"""Full LoadVisualTransform497bb0, SetVisualTransform49c020, default-map
496290/4961c0/496170 and equality48aef0. Map node construction/copy/clear/free,
GFF reads, value loader48f8c0, virtual item cast and equipment lookups are
captured boundaries. Synthetic valid BSTs preserve native iterator ordering;
this does not reimplement or validate the STL red-black allocator algorithms.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,gffPtr,rootPtr,incomingPtr,currentPtr,creaturePtr,equipmentPtr,appPtr,vtPtr,itemPtr=[m.heap+n*0x1000 for n in range(1,11)]
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;assert cursor<0x100000;return ptr
def number(value):return dict(nan=float('nan'),inf=float('inf'),negativeInf=-float('inf')).get(value,value)if isinstance(value,str)else value
def value(entry):
 raw=bytearray([entry.get('seed',0)])*640
 for offset,val in entry.get('ints',{}).items():struct.pack_into('<I',raw,int(offset),val&0xffffffff)
 for offset,val in entry.get('floats',{}).items():struct.pack_into('<f',raw,int(offset),number(val))
 return bytes(raw)
def head(ptr):return m.q(ptr)
def construct(ptr,name):
 h=alloc(0x2a8);m.wq(ptr,h);m.wq(ptr+8,0);m.wq(h,h);m.wq(h+8,h);m.wq(h+0x10,h);u.mem_write(h+0x19,b'\1');mapNames[ptr]=name;return h
def insert(ptr,node):
 h=head(ptr);key=m.si(node+0x20);m.wq(node,h);m.wq(node+0x10,h);m.wq(node+8,h);u.mem_write(node+0x19,b'\0')
 if m.q(ptr+8)==0:m.wq(h+8,node);m.wq(h,node);m.wq(h+0x10,node)
 else:
  parent=m.q(h+8)
  while True:
   slot=parent+(0 if key<m.si(parent+0x20)else 0x10);child=m.q(slot)
   if child==h:m.wq(slot,node);m.wq(node+8,parent);break
   parent=child
  if key<m.si(m.q(h)+0x20):m.wq(h,node)
  if key>m.si(m.q(h+0x10)+0x20):m.wq(h+0x10,node)
 m.wq(ptr+8,m.q(ptr+8)+1)
def add(ptr,key,raw):
 node=alloc(0x2a8);m.wi(node+0x20,key);u.mem_write(node+0x28,raw);insert(ptr,node);return node
def snapshot(ptr):
 result=[];h=head(ptr)
 def walk(node):
  if node==h:return
  walk(m.q(node));result.append([m.si(node+0x20),bytes(u.mem_read(node+0x28,640)).hex()]);walk(m.q(node+0x10))
 walk(m.q(h+8));return result
def clear(ptr):
 h=head(ptr);m.wq(h,h);m.wq(h+8,h);m.wq(h+0x10,h);m.wq(ptr+8,0)
def copy(dst,src):
 entries=snapshot(src);clear(dst)
 for key,raw in entries:add(dst,key,bytes.fromhex(raw))
def ctext(ptr):return bytes(u.mem_read(ptr,256)).split(b'\0')[0].decode('ascii')
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x140368530:
  name='owned'if m.q(rsp)==0x14049c0b7 else'temporary';calls.append(['construct',name]);m.finish(construct(x,name));return
 if at==0x140359470:
  node=alloc(0x2a8);m.wi(node+0x20,m.si(m.q(z)));m.finish(node);return
 if at==0x140359b60:node=m.q(rsp+0x28);insert(x,node);m.wq(y,node);m.finish(y);return
 if at==0x140425890:
  for key,raw in snapshot(x):
   if key==(y&0xffffffff):raise AssertionError('Legacy lookup should only insert its empty scope0')
  node=add(x,y&0xffffffff,bytes(640));m.finish(node+0x28);return
 if at==0x140369220:calls.append(['clear',mapNames[x]]);clear(x);m.finish();return
 if at==0x14048ae40:calls.append(['copy',mapNames[x],mapNames[y],snapshot(y)]);copy(x,y);m.finish(x);return
 if at==0x140369860:calls.append(['release',mapNames[x],snapshot(x)]);clear(x);m.finish();return
 if at==0x14037bae0:
  offset=x-creaturePtr;calls.append(['hand',offset,snapshot(y)]);copy(x,y);m.finish(x);return
 if at==m.stop+0x100:calls.append(['asItem']);m.finish(itemPtr if c.get('item')else 0);return
 if at==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(creaturePtr if c.get('creature',True)else 0);return
 if at==0x140462c10:assert x==equipmentPtr and y==itemPtr;calls.append(['slot']);m.finish(c.get('slot',0));return
 if at==0x1401a02c0:
  assert ctext(w)=='VisTransformList';calls.append(['list','VisTransformList']);status=c.get('listStatus',0)
  if status:descriptors[y]='list'
  m.finish(status);return
 if at==0x1401a0370:calls.append(['count']);m.finish(len(c.get('rows',[])));return
 if at==0x1401a03f0:
  index=w&0xffffffff;calls.append(['element',index]);status=c['rows'][index].get('status',1)
  if status:descriptors[y]=index
  m.finish(status);return
 if at==0x1401a04e0:
  assert ctext(w)=='VisualTransform';calls.append(['struct','VisualTransform']);status=c.get('legacyStatus',0)
  if status:descriptors[y]='legacy'
  m.finish(status);return
 if at==0x1401a1770:
  index=descriptors[y];assert ctext(z)=='Scope';calls.append(['scope',index,m.si(rsp+0x28)]);entry=c['rows'][index].get('scope',dict(status=0,value=0));m.wi(w,entry['status']);m.finish(entry['value']);return
 if at==0x14048f8c0:
  index=descriptors[y];calls.append(['load',index]);entry=c.get('legacy',{})if index=='legacy'else c['rows'][index].get('value',{});u.mem_write(z,value(entry));m.finish();return
 if at==0x140115890:
  calls.append(['assert',ctext(z),m.si(rsp+0x28),ctext(m.q(rsp+0x38))]);m.finish();return
 if at==0x140c10324:m.finish(alloc(x));return
 if at in [0x140c10360,0x140c10370]:m.finish();return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=at<hi for lo,hi in[(0x140497bb0,0x140497ded),(0x14049c020,0x14049c164),(0x140496290,0x1404963e3),(0x1404961c0,0x140496289),(0x140496170,0x1404961c0),(0x14048aef0,0x14048b0ba)]):raise AssertionError(f'Uncaptured transform map dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,mapNames,descriptors
 c=case;calls=[];cursor=0x10000;mapNames={};descriptors={rootPtr:'root'};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(objectPtr,vtPtr);m.wq(vtPtr+0x70,m.stop+0x100);m.wi(itemPtr+0x3c8,c.get('possessor',123));m.wi(objectPtr+0x3c8,0x7f000000);m.wq(creaturePtr+0x950,equipmentPtr)
 construct(incomingPtr,'incoming')
 for entry in c.get('incoming',[]):add(incomingPtr,entry.get('scope',0),value(entry))
 if c.get('current')is not None:
  construct(currentPtr,'current');m.wq(objectPtr+0x2b0,currentPtr)
  for entry in c['current']:add(currentPtr,entry.get('scope',0),value(entry))
 for offset in [0xab0,0xac0]:construct(creaturePtr+offset,f'hand{offset:x}')
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 mode=c.get('mode','assign');argument=currentPtr if c.get('alias')else incomingPtr;args=[objectPtr,argument];address=0x14049c020
 if mode=='load':args=[objectPtr,gffPtr,rootPtr];address=0x140497bb0
 elif mode=='zero':args=[incomingPtr];address=0x140496290
 elif mode=='equal':args=[m.q(head(currentPtr)),head(currentPtr),m.q(head(argument))];address=0x14048aef0
 for reg,val in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,val)
 try:u.emu_start(address,m.stop,count=1000000)
 except Exception:print(json.dumps(dict(case=c,calls=calls[-12:],rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop;ptr=m.q(objectPtr+0x2b0)
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&255 if mode in ['zero','equal']else None,current=snapshot(ptr)if ptr else None,currentLabel=mapNames.get(ptr),hands={str(offset):snapshot(creaturePtr+offset)for offset in[0xab0,0xac0]})
rows=[]
unit=dict(floats={'4':1,'68':1,'132':1,'580':1});zero={}
for current,incoming in itertools.product([None,[],[zero],[unit]], [[],[zero],[unit]]):rows.append(run(dict(current=current,incoming=incoming)))
for offset in range(0,640,4):
 patch=dict(ints={str(offset):1});rows.append(run(dict(mode='equal',current=[zero],incoming=[patch])));rows.append(run(dict(mode='zero',incoming=[patch])))
for kind,val in itertools.product(['floats'],['nan','inf',-0.0]):rows.append(run(dict(mode='equal',current=[zero],incoming=[dict(floats={'4':val})])));rows.append(run(dict(mode='zero',incoming=[dict(floats={'4':val})])))
for item,possessor,creature,slot in itertools.product([False,True],[0x7f000000,123],[False,True],[0,16,32,8]):rows.append(run(dict(incoming=[unit],item=item,possessor=possessor,creature=creature,slot=slot)))
for listStatus,legacyStatus in itertools.product([0,1,2],[0,1,2]):rows.append(run(dict(mode='load',current=[unit],listStatus=listStatus,legacyStatus=legacyStatus,legacy=unit)))
for scopes in [[0],[2,-1,0],[5,5,-2],[-2147483648,2147483647,0]]:
 rows.append(run(dict(mode='load',listStatus=1,rows=[dict(scope=dict(status=1,value=scope),value=dict(floats={'4':i+10}))for i,scope in enumerate(scopes)])))
for index in [0,1,2]:rows.append(run(dict(mode='load',current=[unit],listStatus=1,rows=[dict(status=0 if i==index else 1,scope=dict(status=1,value=i),value=unit)for i in range(3)])))
rows.append(run(dict(mode='load',listStatus=2,rows=[dict(scope=dict(status=0,value=0),value=unit),dict(scope=dict(status=2,value=-1),value=dict(floats={'4':4}))])))
base=[dict(scope=-3,floats={'4':1}),dict(scope=4,floats={'4':2}),dict(scope=0,floats={'4':3})]
for incoming in [list(reversed(base)),[dict(scope=e['scope'],floats={**e['floats'],'8':9})for e in base],[dict(scope=e['scope']+1,floats=e['floats'])for e in base],[dict(scope=e['scope'],floats={'4':7})for e in base]]:
 for mode in ['assign','equal']:rows.append(run(dict(mode=mode,current=base,incoming=incoming)))
for mode in ['assign','equal']:rows.append(run(dict(mode=mode,current=[dict(floats={'4':'nan'})],incoming=[],alias=True)))
for slot in [16,32]:rows.append(run(dict(current=[dict(floats={'4':'nan'})],alias=True,item=True,slot=slot)))
out=m.root/'backups/animations/native-object-transform-map-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
