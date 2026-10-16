"""Original complete Store::LoadFromGff1404fbbf0..1404fc749.
GFF/string/tag/localized operations, allocation/array lifetime, item constructor,
LoadFromGff, base-info, pricing, possession, acquisition and UUID/tag insertion
are captured lower boundaries. Proves caller flow/order/field writes and
temporary item sorting, not these lower owners, OOM or C++ unwinding.
"""
import importlib.util,itertools,json,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,gffPtr,rootPtr,tagPtr,appPtr,basePtr,modulePtr,vtablePtr,baseInfoPtr=[m.heap+n*0x1000 for n in range(1,10)]
empty=dict(strRef=0xffffffff,entries=[]);offsets=[0x378,0x37c,0x380,0x384,0x38c,0x390,0x394]
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr
def ctext(ptr):
 raw=bytearray()
 while ptr and len(raw)<4096:
  b=u.mem_read(ptr+len(raw),1)[0]
  if not b:break
  raw.append(b)
 return raw.decode('cp1252')
def owning(ptr,text):
 raw=text.encode('cp1252');target=alloc(len(raw)+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)
def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''
def loc(ptr,value):
 token=alloc(16);localized[token]=value;m.wq(ptr,token);m.wi(ptr+8,value['strRef'])
def locvalue(ptr):return localized.get(m.q(ptr),empty)
def node(ptr):return nodes[m.si(ptr)]
def label(row):return names[id(row)]
def field(row,kind,key,fallback):
 calls.append(['read',label(row),kind,key,fallback]);return row.get('fields',{}).get(key,dict(status=0,value=fallback))
def register(row,path):
 token=len(nodes)+1;nodes[token]=row;names[id(row)]=path
 for name,l in row.get('lists',{}).items():
  listToken=len(nodes)+1;nodes[listToken]=l;names[id(l)]=path+'/'+name
  for i,r in enumerate(l.get('rows',[])):register(r,path+'/'+name+'['+str(i)+']')
 return token
def token(row):return next(i for i,v in nodes.items()if v is row)
def itemName(ptr):return label(allocated[ptr]) if ptr else None
def hook(u,at,n,_):
 global currentRow
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at in [0x140169560,0x1401695b0,0x140169600]:
  if at==0x140169560:loc(x,empty)
  elif at==0x140169600:
   value=locvalue(y);loc(x,value)
   if x==objectPtr+0x360:calls.append(['localized',0x360,value])
  m.finish(x);return
 if at in [0x1401a1130,0x1401a0f80,0x1401a12d0]:
  kind={0x1401a1130:'string',0x1401a0f80:'localized',0x1401a12d0:'resref'}[at];fallback=empty if kind=='localized' else '';entry=field(node(z),kind,ctext(w),fallback)
  if kind=='localized':loc(y,entry['value'])
  elif kind=='string':owning(y,entry['value'])
  else:u.mem_write(y,entry['value'].split('\0')[0].encode('cp1252')[:16].ljust(17,b'\0'))
  m.wi(m.q(rsp+0x28),entry['status']);m.finish(y);return
 if at in [0x1401a0f60,0x1401a1770,0x1401a1510]:
  kind={0x1401a0f60:'bool',0x1401a1770:'int',0x1401a1510:'dword'}[at];fallback=u.mem_read(rsp+0x28,1)[0] if kind=='bool' else m.si(rsp+0x28) if kind=='int' else m.si(rsp+0x28)&0xffffffff
  entry=field(node(y),kind,ctext(z),fallback);m.wi(w,entry['status']);m.finish(entry['value']);return
 if at==0x14018ded0:u.mem_write(x,ctext(y).encode('cp1252')[:16].ljust(17,b'\0'));m.finish(x);return
 if at==0x14003d8c0:
  value=bytes(u.mem_read(y,z&0xffffffff)).decode('cp1252');value='' if value.startswith('\0') else value;owning(x,value)
  if x in [objectPtr+0x308,objectPtr+0x318,objectPtr+0x30]:calls.append(['string',x-objectPtr,value])
  m.finish(x);return
 if at==0x14016ac40:value=stored(x);calls.append(['asTag',value]);owning(y,value);m.finish(y);return
 if at==0x14045df80:value=stored(y);calls.append(['tag',value]);owning(objectPtr+0x20,value);m.finish();return
 if at==0x1401a02c0:
  row=node(z);key=ctext(w);calls.append(['list',label(row),key]);value=row.get('lists',{}).get(key);status=value.get('status',1) if value else 0;m.wi(y,token(value) if value else 0);m.finish(status);return
 if at==0x1401a0370:
  value=nodes.get(m.si(y));calls.append(['count',label(value) if value else None]);m.finish(len(value.get('rows',[])) if value else 0);return
 if at==0x1401a03f0:
  value=node(z);i=w&0xffffffff;currentRow=value['rows'][i];calls.append(['element',label(value),i]);m.wi(y,token(currentRow));m.finish(currentRow.get('elementStatus',1));return
 if at==0x14004bcf0:
  offset=x-objectPtr;calls.append(['appendType',offset,y&0xffffffff]);types[offset].append(y&0xffffffff);m.wi(x+8,len(types[offset]));m.finish();return
 if at==0x140c11414:u.mem_write(x,bytes(z*y));m.finish();return
 if at==0x140c10434:m.finish();return
 if at==0x14055b4c0:calls.append(['existing',y&0xffffffff]);m.finish(int(currentRow.get('existing',False)));return
 if at==0x140c10324:calls.append(['newItem',label(currentRow),u.reg_read(UC_X86_REG_RBX)&0xffffffff]);m.finish(0 if currentRow.get('allocationFail') else alloc(x));return
 if at==0x140462e90:
  allocated[x]=currentRow;index=token(currentRow);m.wq(x,vtablePtr);m.wi(x+0x40,index);m.wi(x+0x50,1000+index);m.wi(x+0x444,7);m.finish(x);return
 if at==0x14046a9d0:calls.append(['loadItem',itemName(x),label(node(z)),w&0xffffffff,m.si(rsp+0x28)]);m.finish(allocated[x].get('loadResult',1));return
 if at==m.stop+0x100:calls.append(['destroyItem',itemName(x),y&0xffffffff]);m.finish();return
 if at==0x14046c420:calls.append(['identified',itemName(x),y&0xffffffff]);m.finish();return
 if at==0x14029ca00:
  row=nodes[y&0xffffffff];calls.append(['baseInfo',label(row)]);u.mem_write(baseInfoPtr+0x33,bytes([row.get('panel',0)&255,row.get('sort',0)&255]));m.finish(baseInfoPtr);return
 if at==0x140468710:calls.append(['price',itemName(x),y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish(allocated[x].get('price',0));return
 if at==0x14046c520:calls.append(['possessor',itemName(x),y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish();return
 if at==0x1404fa1b0:
  item=m.q(y);row=allocated[item];calls.append(['acquire',itemName(item),z&255,w&255,u.mem_read(rsp+0x28,1)[0]])
  mutation=row.get('acquireMutation');replacement=next((ptr for ptr,r in allocated.items()if label(r)==mutation),None)
  if replacement:m.wq(y,replacement)
  m.finish(row.get('acquireResult',1));return
 if at==0x140115890:calls.append(['warning','Base item on unknown store panel']);m.finish();return
 if at==0x14055b6e0:m.finish(modulePtr);return
 if at==0x14047a930:calls.append(['addTag',stored(y),z&0xffffffff]);m.finish();return
 if at==0x140505710:assert x==objectPtr+0x2e8;calls.append(['uuid']);m.finish(c.get('uuidResult',0));return
 if at==0x140c10368:m.finish(alloc(x));return
 if at in [0x140c10360,0x140c10370]:m.finish();return
 if at==0x140c4f038:
  target=alloc(y)
  if x:u.mem_write(target,bytes(u.mem_read(x,min(y,0x1000))))
  m.finish(target);return
 if at==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not 0x1404fbbf0<=at<0x1404fc74a:raise AssertionError(f'Uncaptured store dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,cursor,calls,localized,nodes,names,allocated,currentRow,types
 c=case;cursor=0x10000;calls=[];localized={};nodes={};names={};allocated={};currentRow=None;types={0x398:c.get('initialNot',[]).copy(),0x3a8:c.get('initialOnly',[]).copy()};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(0x1412df8f8,basePtr);m.wq(basePtr+0x20,basePtr)
 m.wq(objectPtr,vtablePtr);m.wq(vtablePtr,m.stop+0x100);m.wi(objectPtr+8,99);m.wi(objectPtr+0x3a0,len(types[0x398]));m.wi(objectPtr+0x3b0,len(types[0x3a8]));m.wi(rootPtr,register(c,'root'))
 if c.get('tag') is not None:owning(tagPtr,c['tag'])
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x900,bytes(0xa00));m.wq(rsp,m.stop);m.wq(rsp+0x28,tagPtr if c.get('tag') is not None else 0);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[objectPtr,gffPtr,rootPtr,c.get('loading',0)]):u.reg_write(reg,value)
 try:u.emu_start(0x1404fbbf0,m.stop,count=1000000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,fields={str(offset):m.si(objectPtr+offset)for offset in offsets},types={str(k):v for k,v in types.items()},infinite={itemName(ptr):m.si(ptr+0x444)for ptr in allocated})
def entry(value,status=1):return dict(status=status,value=value)
def inventory(items,**rest):return dict(lists=dict(StoreList=dict(status=1,rows=[dict(lists=dict(ItemList=dict(status=1,rows=items)))])),**rest)
rows=[run({})]
for tag in [None,'','override','a\0tail','\0tail']:
 rows.append(run(dict(tag=tag,fields=dict(Tag=entry('Authored'),LocName=entry(dict(strRef=17,entries=[dict(languageId=0,text='Store')])),OnOpenStore=entry('open'),OnStoreClosed=entry('close'),ResRef=entry('origin')))))
for initialNot,initialOnly,notStatus,onlyStatus in itertools.product([[],[4]],[[],[7]],[0,1,2],[0,1,-1]):
 rows.append(run(dict(initialNot=initialNot,initialOnly=initialOnly,lists=dict(WillNotBuy=dict(status=notStatus,rows=[dict(fields=dict(BaseItem=entry(3))),dict(fields=dict(BaseItem=entry(-1))),dict(fields=dict(BaseItem=entry(8,0))),dict(elementStatus=0,fields=dict(BaseItem=entry(6)))]),WillOnlyBuy=dict(status=onlyStatus,rows=[dict(fields=dict(BaseItem=entry(5))),dict(fields=dict(BaseItem=entry(5)))])))))
for loading,loadResult,existing,allocationFail,acquireResult in itertools.product([0,1,2],[0,1,2,-1],[False,True],[False,True],[0,1,2]):
 rows.append(run(inventory([dict(fields=dict(ObjectId=entry(123),Infinite=entry(1)),loadResult=loadResult,existing=existing,allocationFail=allocationFail,acquireResult=acquireResult)],loading=loading)))
rng=random.Random(20261016)
for i in range(100):
 items=[dict(panel=rng.randrange(7),sort=rng.randrange(4),price=rng.choice([0,1,2,0xffffffff]),fields=dict(Infinite=entry(rng.randrange(2))))for _ in range(rng.randrange(2,9))]
 rows.append(run(inventory(items)))
for tail in [dict(allocationFail=True),dict(existing=True),dict(loadResult=0),dict(loadResult=2)]:rows.append(run(inventory([dict(sort=2,price=7),tail])))
rows.append(run(inventory([dict(sort=0,price=1),dict(sort=1,price=2,acquireMutation='root/StoreList[0]/ItemList[0]')])))
out=m.root/'backups/animations/native-store-template-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
