"""Read-only original automap storage/bit owners and UpdateAutoMap/ExploreArea.
Allocation, canonical lookups and DFS are captured helper boundaries. PostProcess
executes only its verified automap block, not the rest of character processing.
This fixture does not establish visibility DFS, save transport or UI parity.
"""
from pathlib import Path
import sys,json,itertools,hashlib
sys.path.insert(0,str(Path(__file__).resolve().parent))
import importlib
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,target,module,area,global_,server,oldids,oldouter,moduleids,inids,inouter,tiles=[m.heap+i*0x1000 for i in range(12)]
ranges=[(0x140387b40,0x140387bec),(0x14039dbc0,0x14039ddad),(0x1403a2d50,0x1403a2f31),(0x140393270,0x140393337),(0x1403a4330,0x1403a4404),(0x1403a2ac0,0x1403a2baa),(0x1403a7390,0x1403a76ab),(0x14036bb40,0x14036bc8a),(0x14039b897,0x14039b9e6),(0x140397400,0x1403975d3)]
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=max(16,(size+15)&~15);assert cursor<0xf0000
 u.mem_write(ptr,bytes([0xa5])*max(size,1));return ptr
def view(ptr):return [m.si(m.q(ptr)+4*i)&0xffffffff for i in range(m.si(ptr+8))]
def index(ptr,id):
 try:return view(ptr).index(id&0xffffffff)
 except ValueError:return -1
def hook(u,a,n,_):
 global saved
 if a==m.stop or a==0x14039b9e6:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b6e0:calls.append(['module']);m.finish(module)
 elif a==0x14055b2e0:calls.append(['areaById',y&0xffffffff]);m.finish(area if c.get('area',True) and y&0xffffffff==88 else 0)
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish(server if c.get('client',False) else 0)
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(target if c.get('target',True) else 0)
 elif a==0x140494e80:calls.append(['area',99]);m.finish(area if c.get('area',True) else 0)
 elif a==0x1403d54d0:calls.append(['possessed',99]);m.finish(c.get('possessed',0))
 elif a==0x1400b3ed0:m.finish(index(x,y))
 elif a==0x140175070:m.finish(int(index(x,y)>=0))
 elif a in [0x140c10368,0x140c10324]:m.finish(alloc(x))
 elif a in [0x140c10370,0x140c10360,0x140c4f024]:m.finish()
 elif a==0x140c4f038:
  ptr=alloc(y)
  if x:u.mem_write(ptr,bytes(u.mem_read(x,min(y,alloc_sizes.get(x,y)))))
  alloc_sizes[ptr]=y;m.finish(ptr)
 elif a==0x14007c830:
  # Independently verified CExoArrayList SetSize helper boundary.
  if y>m.si(x+12):
   ptr=alloc(y*4);old=m.q(x)
   if old:u.mem_write(ptr,bytes(u.mem_read(old,m.si(x+8)*4)))
   m.wq(x,ptr);m.wi(x+12,y)
  m.wi(x+8,y);m.finish()
 elif a==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x)
 elif a==0x140c42060:
  if z:u.mem_write(x,bytes([y&255])*z)
  m.finish(x)
 elif a==0x140c41f60:m.finish(int(bytes(u.mem_read(x,z))!=bytes(u.mem_read(y,z))))
 elif a==0x1401a1770:m.wi(w,1);m.finish(len(c['saved']))
 elif a==0x1401a02c0:m.finish(int(c['list']!='absent'))
 elif a==0x1401a0370:m.finish(0 if c['list']=='empty' else len(c['saved']))
 elif a==0x1401a03f0:m.wi(y,w);m.finish(1)
 elif a==0x1401a1870:
  if w==128:
   i=m.si(y);u.mem_write(z,bytes(((i*17+j+111)&255) for j in range(128)))
  else:
   for i,id in enumerate(c['saved']):m.wi(z+i*4,id)
  m.wi(m.q(rsp+0x30),1);m.finish(z)
 elif a==0x1401a0f60:m.wi(w,1);m.finish(int((c.get('auto',1)&255)!=0))
 elif a==0x140c10410:
  saved=u.reg_read(UC_X86_REG_RAX);m.finish(saved)
 elif a==0x1403a7390 and c['operation']=='all':calls.append(['update',99,y&0xffffffff]);m.finish()
 elif a==0x14036bb40 and c['operation']=='update':calls.append(['explore',88,100,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.finish(1)
 elif a==0x14036ce60:
  calls.append(['dfs',88,m.struct.unpack('<i',m.struct.pack('<I',z&0xffffffff))[0],m.struct.unpack('<i',m.struct.pack('<I',w&0xffffffff))[0],m.si(rsp+0x28),m.rf(rsp+0x30),m.rf(rsp+0x38)])
  u.mem_write(y,bytes(c['visited']));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Unmapped automap dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cursor,alloc_sizes
 c=case;calls=[];cursor=0x20000;alloc_sizes={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,global_);m.wq(global_+8,server);m.wi(actor+8,99);m.wi(target+8,100)
 m.wq(module+0x50,moduleids);m.wi(module+0x58,len(c['next']))
 for i,id in enumerate(c['next']):m.wi(moduleids+i*4,id)
 own=target if c['operation'] in ['update','explore'] else actor
 m.wq(own+0x6c8,oldids if c['old'] else 0);m.wi(own+0x6d0,len(c['old']));m.wi(own+0x6d4,c.get('capacity',len(c['old'])))
 oldmaps=[]
 for i,id in enumerate(c['old']):
  m.wi(oldids+i*4,id);ptr=alloc(128);u.mem_write(ptr,bytes(((i*31+j+c.get('seed',7))&255) for j in range(128)));oldmaps.append(ptr);m.wq(oldouter+i*8,ptr)
 m.wq(own+0x6d8,0 if c.get('null',False) else oldouter)
 m.wi(actor+0x6e0,c.get('enabled',1));m.wi(actor+0x6e4,0x12345678);m.wi(actor+0x6e8,0x76543210);m.wi(actor+0x89c,c.get('pc',1))
 m.wi(area+8,c.get('flags',0));m.wi(area+12,c.get('width',4));m.wi(area+16,c.get('height',3));m.wi(area+0x140,88);u.mem_write(area+0x348,bytes([c.get('bytes',2)]));m.wq(area+0x1c8,tiles)
 for i,v in enumerate(c.get('position',[15,15,2])):m.wf(actor+0xa4+i*4,v);m.wf(target+0xa4+i*4,v)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r in [UC_X86_REG_RBX,UC_X86_REG_RBP,UC_X86_REG_RSI,UC_X86_REG_RDI,UC_X86_REG_R12,UC_X86_REG_R13,UC_X86_REG_R14,UC_X86_REG_R15]:u.reg_write(r,0)
 args=[actor,88,c.get('x',1),c.get('y',1)];op=c['operation']
 address={'clear':0x140387b40,'reconcile':0x14039dbc0,'set':0x1403a2d50,'get':0x140393270,'bit':0x1403a4330,'all':0x1403a2ac0,'update':0x1403a7390,'explore':0x14036bb40,'post':0x14039b897,'load':0x140397400}[op]
 if op=='set':
  incoming=c['incoming'];args=[actor,len(incoming),inids,inouter]
  for i,id in enumerate(incoming):m.wi(inids+i*4,id);ptr=alloc(128);u.mem_write(ptr,bytes(((i*17+j+111)&255) for j in range(128)));m.wq(inouter+i*8,ptr)
 if op=='bit':m.wi(rsp+0x28,c['value'])
 if op=='all':args[2]=c['value']
 if op=='update':args[1]=100
 if op=='explore':args=[area,target,c.get('x',1),c.get('y',1)];m.wi(rsp+0x28,c.get('range',8))
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,v&0xffffffffffffffff)
 if op=='post':u.reg_write(UC_X86_REG_RSI,actor);u.reg_write(UC_X86_REG_R12,0xffffffffffffffff)
 try:u.emu_start(address,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x14039b9e6]
 ptr=m.q(own+0x6d8);finalids=view(own+0x6c8);maps=[];owners=[]
 for i in range(len(finalids)):
  p=m.q(ptr+i*8) if ptr else 0;maps.append(hashlib.sha256(bytes(u.mem_read(p,128))).hexdigest() if p else None);owners.append(oldmaps.index(p) if p in oldmaps else None)
 return dict(case=c,calls=calls,ids=finalids,capacity=m.si(own+0x6d4),outer=bool(ptr),maps=maps,owners=owners,enabled=m.si(actor+0x6e0),cache=[m.si(actor+0x6e4),m.si(actor+0x6e8)],**(dict(result=u.reg_read(UC_X86_REG_RAX)&0xffffffff) if op in ['get','explore'] else {}))
if __name__=='__main__':
 default=dict(old=[88,89],next=[88,89]);rows=[]
 vectors=[[],[88],[88,89],[89,88],[90,88],[88,88],[0x7f000000,88,90]]
 for op,old,next_,null in itertools.product(['clear','reconcile'],vectors,vectors,[False,True]):rows.append(run(default|dict(operation=op,old=old,next=next_,null=null)))
 for old,next_,incoming in itertools.product(vectors,vectors,vectors):rows.append(run(default|dict(operation='set',old=old,next=next_,incoming=incoming)))
 for op,old,next_,area_,point in itertools.product(['get','bit'],[[88,89],[89]],[[],[88,89]],[False,True],[[-1,0],[0,0],[7,0],[8,0],[1,1],[15,2]]):
  rows.append(run(default|dict(operation=op,old=old,next=next_,area=area_,x=point[0],y=point[1],value=-2)))
 for old,next_,value,bytecount,client in itertools.product([[88,89],[89]],[[],[88,89]],[0,1,-1],[0,1,2,128],[False,True]):rows.append(run(default|dict(operation='all',old=old,next=next_,value=value,bytes=bytecount,client=client)))
 for pc,possessed,old,next_,null in itertools.product([0,1],[0,1],vectors,vectors,[False,True]):rows.append(run(default|dict(operation='post',pc=pc,possessed=possessed,old=old,next=next_,null=null)))
 for old,saved,list_,auto in itertools.product(vectors,vectors,['absent','empty','present'],[0,1,2]):rows.append(run(default|dict(operation='load',old=old,saved=saved,list=list_,auto=auto,enabled=7)))
 for enabled,area_,target_,flags,point,seed in itertools.product([0,1,-2],[False,True],[False,True],[0,1,2,3,4],[[-.5,-.5,0],[-10,15,0],[0,0,0],[15,15,0],[40,15,0]],[0,7]):rows.append(run(default|dict(operation='update',enabled=enabled,area=area_,target=target_,flags=flags,position=point,seed=seed)))
 for old,xy,range_,visited in itertools.product([[88,89],[89]],[[1,1],[-1,0]],[0,1,8],[[0]*12,[1]*12,[0,2,0,0,4,0,0,255,0,1,0,0]]):rows.append(run(default|dict(operation='explore',old=old,x=xy[0],y=xy[1],range=range_,visited=visited)))
 out=m.root/'backups/animations/native-automap-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
