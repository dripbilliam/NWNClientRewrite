"""Original complete combat-information copy2a2120, assignment2a2cd0,
destructor2a2930, equality2a2fd0 and inequality2a31c0 (including node inequality),
plus Polymorph saved-cache replacement block39a02b..39a081. Heap allocation,
free/realloc/memmove and CExoString initialization are captured boundaries.
Synthetic initialized inputs and null nodes only where native permits them.
Unwritten destination padding is recorded but not claimed as defined state.
No heap failure, whole character loader, complete spell or campaign parity.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
source,target,actor,stats=[m.heap+n*0x1000 for n in range(4)]
entry={'copy':0x1402a2120,'assign':0x1402a2cd0,'dispose':0x1402a2930,'equal':0x1402a2fd0,'different':0x1402a31c0,'snapshot':0x14039a02b}
ranges=[(0x1402a2120,0x1402a22af),(0x1402a2cd0,0x1402a2f8a),(0x1402a2930,0x1402a2a36),(0x1402a2fd0,0x1402a317c),(0x1402a31c0,0x1402a33a9),(0x1402a33b0,0x1402a33ed),(0x14039a02b,0x14039a082)]
def alloc(size,label=None):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~31;assert cursor<0xf0000;u.mem_write(ptr,bytes([0xcd])*size);names[ptr]=label or 'new'+str(len(allocations));sizes[ptr]=size;allocations.append(size);return ptr
def name(ptr):return names.get(ptr,'null' if ptr==0 else hex(ptr))
def string(ptr,index):
 p=m.q(ptr+0x48+index*16);return bytes(u.mem_read(p,m.si(ptr+0x50+index*16))).decode('latin1')if p else''
def hook(u,a,n,_):
 if a in [m.stop,0x14039a082]:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a in [0x140c10324,0x140c10368]:calls.append(['allocate',x]);m.finish(alloc(x))
 elif a in [0x140c10360,0x140c10370,0x140c4f024]:calls.append(['free',name(x)]);m.finish()
 elif a==0x140c4f038:
  calls.append(['realloc',name(x),y]);ptr=alloc(y)
  if x:u.mem_write(ptr,bytes(u.mem_read(x,min(y,sizes[x]))))
  m.finish(ptr)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x14003d8c0:
  value=bytes(u.mem_read(y,z)) if z else b'';calls.append(['string',value.decode('latin1')]);ptr=alloc(z+1) if z else 0
  if ptr:u.mem_write(ptr,value+b'\0')
  m.wq(x,ptr);m.wq(x+8,z);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unmapped combat cache lifecycle dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def seed(ptr,data,label,shared=None):
 u.mem_write(ptr,bytes([0xa5])*0x70);u.mem_write(ptr,bytes(data['scalars']));u.mem_write(ptr+0x68,struct.pack('<H',data['flags']&65535))
 for i,value in enumerate(data['weaponIds']):m.wi(ptr+0x40+i*4,value)
 for kind,offset in [('attack',0x20),('damage',0x30)]:
  nodes=data[kind+'Nodes'];array=alloc(max(1,data[kind+'Capacity'])*8,label+kind+'Array') if nodes else 0;m.wq(ptr+offset,array);m.wi(ptr+offset+8,len(nodes));m.wi(ptr+offset+12,data[kind+'Capacity'])
  for index,value in enumerate(nodes):
   node=0 if value is None else m.q(m.q(shared+offset)+index*8) if shared else alloc(6,label+kind+str(index))
   if value is not None and not shared:u.mem_write(node,bytes(value))
   m.wq(array+index*8,node)
 for index,value in enumerate(data['text']):
  encoded=value.encode('latin1');buf=alloc(len(encoded)+1,label+'text'+str(index))if value else 0
  if buf:u.mem_write(buf,encoded+b'\0')
  m.wq(ptr+0x48+index*16,buf);m.wq(ptr+0x50+index*16,len(encoded))
def snapshot(ptr):
 result=dict(scalars=list(u.mem_read(ptr,32)),weaponIds=[m.si(ptr+0x40+i*4)&0xffffffff for i in range(2)],flags=int.from_bytes(u.mem_read(ptr+0x68,2),'little'),text=[string(ptr,i)for i in range(2)])
 for kind,offset in [('attack',0x20),('damage',0x30)]:
  count=m.si(ptr+offset+8);assert 0<=count<=256
  nodes=[m.q(m.q(ptr+offset)+i*8)for i in range(count)];result[kind+'Nodes']=[list(u.mem_read(p,6))if p else None for p in nodes];result[kind+'Identity']=[name(p)for p in nodes];result[kind+'Capacity']=m.si(ptr+offset+12)
 return result
def run(case):
 global c,calls,cursor,names,sizes,allocations
 c=case;calls=[];cursor=0x10000;names={source:'source',target:'target'};sizes={};allocations=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));seed(source,c['source'],'source')
 if c['mode']=='copy':u.mem_write(target,bytes([0xcd])*0x70)
 else:seed(target,c['target'],'target',source if c.get('shareNodes') else None)
 if c['mode']=='snapshot':m.wq(actor+0xad0,stats);m.wq(stats+0xd70,source);m.wq(actor+0xa48,target if c.get('oldSnapshot',True) else 0);u.reg_write(UC_X86_REG_RDI,actor);u.reg_write(UC_X86_REG_R15,0)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,source if c.get('self') else target);u.reg_write(UC_X86_REG_RDX,source);allocations=[]
 try:u.emu_start(entry[c['mode']],m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x14039a082]
 result=dict(case=c,calls=calls,source=snapshot(source),allocations=allocations)
 if c['mode'] in ['equal','different']:result['value']=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 else:result['target']=snapshot(m.q(actor+0xa48) if c['mode']=='snapshot' else source if c.get('self') else target)
 return result
def data(counts=(0,0),bias=0):
 return dict(scalars=[(i*7+bias)&255 for i in range(32)],weaponIds=[0xf0000001+bias,0x7f000000],flags=(0x1234+bias)&65535,text=['source\0first'+str(bias),'second'+str(bias)],attackNodes=[[(i+j+bias)&255 for j in range(6)]for i in range(counts[0])],damageNodes=[[(i*3+j+bias)&255 for j in range(6)]for i in range(counts[1])],attackCapacity=max(16,counts[0]*3),damageCapacity=max(16,counts[1]*3))
cases=[]
for mode,counts,old in itertools.product(['copy','assign','dispose','snapshot'],[(0,0),(1,0),(0,2),(3,4),(16,17),(33,40)],[False,True]):
 cases.append(dict(mode=mode,source=data(counts),target=data((2,3),15),oldSnapshot=old))
for counts in [(0,0),(1,2),(17,33)]:cases.append(dict(mode='assign',source=data(counts),target=data(),self=True))
for mode,share in itertools.product(['equal','different'],[False,True]):
 for counts in [(0,0),(1,0),(0,1),(2,3),(17,19)]:
  src=data(counts);base=dict(mode=mode,source=src,target=data(counts),shareNodes=share);cases.append(base)
  for index in range(32):
   dst=data(counts);dst['scalars'][index]^=1;cases.append(base|dict(target=dst))
  for field in ['flags','text','weaponIds']:
   dst=data(counts)
   if field=='flags':dst[field]^=1
   elif field=='text':dst[field]=['different','other']
   else:dst[field][0]^=1
   cases.append(base|dict(target=dst))
  if not share:
   for kind in ['attack','damage']:
    for index in range(6):
     dst=data(counts)
     if not dst[kind+'Nodes']:continue
     dst[kind+'Nodes'][0][index]^=1;cases.append(base|dict(target=dst))
cases.extend([dict(mode='dispose',source=data(),target=data()|dict(attackNodes=[None,[1,2,3,4,5,6]],damageNodes=[None])),dict(mode='equal',source=data()|dict(attackNodes=[None]),target=data()|dict(attackNodes=[None]))])
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-combat-cache-lifecycle-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),modes={mode:sum(r['case']['mode']==mode for r in rows)for mode in entry})))
