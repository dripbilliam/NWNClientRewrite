"""Original Store::AddItemToInventory1404fa1b0..1404fa53f. Synthetic
canonical repository nodes; item lookup, base-info, pricing, GetPrev, Remove,
repository AddItem and warning/allocation are captured lower boundaries.
Checks full caller direction, mutation, branch/order and ignored coordinates;
not lower repository fit/merge or price implementations.
"""
import importlib.util,itertools,json,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
storePtr,refPtr,repoPtr,listPtr,basePtr,infoPtr=[m.heap+n*0x1000 for n in range(1,7)]
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr
def itemLabel(ptr):return items[ptr]['label'] if ptr else None
def links():
 m.wq(listPtr,order[0] if order else 0);m.wq(listPtr+8,order[-1] if order else 0)
 for i,node in enumerate(order):m.wq(node,order[i-1] if i else 0);m.wq(node+8,order[i+1] if i+1<len(order)else 0)
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x14029ca00:
  ptr=byBase[y&0xffffffff];calls.append(['baseInfo',itemLabel(ptr)]);u.mem_write(infoPtr+0x34,bytes([items[ptr].get('sort',0)&255]));m.finish(infoPtr);return
 if at==0x140468710:calls.append(['price',itemLabel(x),y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish(items[x].get('price',0));return
 if at==0x1404693e0:assert x==repoPtr;calls.append(['item',nodeNames[y]]);m.finish(nodeItems[y]);return
 if at==0x140169180:
  before=m.q(y);calls.append(['previous',nodeNames[before]]);m.wq(y,m.q(before));m.finish();return
 if at==0x1401691f0:
  calls.append(['remove',nodeNames[y]]);order.remove(y);links();m.finish();return
 if at==0x140464200:
  item=m.q(y);calls.append(['add',itemLabel(item),z&255,w&255,m.si(rsp+0x28),m.si(rsp+0x30)]);node=alloc(32);nodeItems[node]=item;nodeNames[node]='added:'+itemLabel(item);order.insert(0,node);links()
  if c.get('mutation') and item==incomingPtr:m.wq(y,next(ptr for ptr in items if itemLabel(ptr)==c['mutation']))
  m.finish(c.get('addResult',1));return
 if at==0x140115890:
  # Warning site determines which assertion is emitted.
  returnAddress=m.q(rsp);text='Invalid item in store inventory!' if returnAddress==0x1404fa303 else 'This item is already in the store!?';calls.append(['warning',text]);m.finish();return
 if at==0x140c4f038:
  target=alloc(y)
  if x:u.mem_write(target,bytes(u.mem_read(x,min(y,0x1000))))
  m.finish(target);return
 if at in [0x140c10360,0x140c4f024]:m.finish();return
 if not 0x1404fa1b0<=at<0x1404fa540:raise AssertionError(f'Uncaptured store acquisition dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,items,byBase,nodeItems,nodeNames,order,incomingPtr
 c=case;calls=[];cursor=0x20000;items={};byBase={};nodeItems={};nodeNames={};order=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8f8,basePtr);m.wq(basePtr+0x20,basePtr)
 allItems=[dict(label='incoming',**c.get('incoming',{}))]+[dict(label='item'+str(i),**entry)for i,entry in enumerate(c.get('items',[]))]
 for i,entry in enumerate(allItems):
  ptr=m.heap+0x10000+i*0x500;items[ptr]=entry;byBase[i]=ptr;m.wi(ptr+0x40,i);m.wi(ptr+0x50,entry.get('id',100+i))
 incomingPtr=next(iter(items));m.wq(refPtr,incomingPtr);m.wq(repoPtr+0x10,listPtr);m.wq(storePtr+0x328+(c.get('panel',0)&255)*8,repoPtr)
 for i,entry in enumerate(c.get('items',[])):
  node=alloc(32);nodeNames[node]='node'+str(i);nodeItems[node]=0 if entry.get('missing')else m.heap+0x10000+(i+1)*0x500;order.append(node)
 links();rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);m.wi(rsp+0x28,3);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[storePtr,refPtr,c.get('panel',0),2]):u.reg_write(reg,value)
 try:u.emu_start(0x1404fa1b0,m.stop,count=250000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,ref=itemLabel(m.q(refPtr)),order=[itemLabel(nodeItems[node])for node in order])
rows=[]
for priority,price,addResult,panel in itertools.product([0,1,2],[0,1,2,0xffffffff],[0,1,2],[0,4,260]):rows.append(run(dict(incoming=dict(sort=priority,price=price),items=[dict(sort=2,price=10),dict(sort=1,price=5),dict(sort=0,price=1)],addResult=addResult,panel=panel)))
for missing,duplicate in itertools.product([0,1,2],[False,True]):
 entries=[dict(sort=2,price=10),dict(sort=1,price=5),dict(sort=0,price=1)];entries[missing]['missing']=True
 if duplicate:entries[1]['id']=100
 rows.append(run(dict(incoming=dict(sort=0,price=0),items=entries)))
rows.append(run(dict(items=[])));rows.append(run(dict(incoming=dict(sort=0,price=0),items=[dict(sort=2,price=1)],mutation='item0')))
out=m.root/'backups/animations/native-store-acquisition-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
