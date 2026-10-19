"""Whole original SaveScriptSituation_Internal; captured GFF/heap/string and
opaque engine save. Captures actual fifth engine-save destination argument.
"""
import importlib,sys,json,struct,random,copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
vm,script,gff,root,stack,impl,vtable=[m.heap+n*0x1000 for n in range(1,8)];fake=m.stop+0x100
def alloc(n):
 global cursor
 assert n>=0;p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xf0000;return p
def exo(p,s):
 b=s.encode('ascii');a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def string(p):
 b=bytearray()
 while u.mem_read(p,1)[0]:b.append(u.mem_read(p,1)[0]);p+=1
 return b.decode('ascii')
def node(t):nodes.append(dict(type=t,fields={}));return len(nodes)-1
def put(n,name,t,v):nodes[n]['fields'][name[:16]]=dict(type=t,value=v)
types={0x1401a2e20:1,0x1401a31d0:4,0x1401a3350:8,0x1401a34f0:5,0x1401a2d30:10}
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in types:
  t=types[a];v=text(z)if t==10 else struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM2)&0xffffffff))[0]if t==8 else(z&255)-256 if t==1 and z&128 else z&255 if t==1 else z&0xffffffff if t==4 else(z&0xffffffff)-0x100000000 if z&0x80000000 else z&0xffffffff
  put(m.si(y),string(w),t,v);m.finish(1);return
 if a==0x1401a3630:
  size=w&0xffffffff;put(m.si(y),string(m.q(rsp+0x28)),13,list(u.mem_read(z,size)));m.finish(1);return
 if a==0x14019f4f0:
  idx=node(m.si(rsp+0x28)&0xffffffff);put(m.si(z),string(w),14,nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==0x14019f1e0:
  rows=[];lists.append(rows);put(m.si(z),string(w),15,rows);m.wi(y,len(lists)-1);m.finish(1);return
 if a==0x14019f2b0:
  idx=node(w&0xffffffff);lists[m.si(z)].append(nodes[idx]);m.wi(y,idx);m.finish(1);return
 if a==fake:
  kind=(y&0xffffffff)-0x100000000 if y&0x80000000 else y;value=tokens[z];calls.append([kind,value]);put(m.si(m.q(rsp+0x28)),'EngineMarker',5,value);m.finish(0);return
 if a==0x140c10368:m.finish(alloc(x));return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if a==0x140c10370:m.finish();return
 if not 0x140284d00<=a<=0x1402851c2:raise RuntimeError(f'Uncaptured situation-save dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def blob(p,data):
 view=alloc(8);block=alloc(24);body=alloc(len(data)+1);u.mem_write(body,bytes(data)+b'\0');m.wq(block,body);m.wq(block+8,len(data));m.wq(view,block);m.wq(p,view)
def run(case):
 global cursor,nodes,lists,tokens,calls
 cursor=0x10000;nodes=[];lists=[];tokens={};calls=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));node(0xffffffff);m.wi(root,0);m.wq(script,stack);blob(script+0x28,case['code'])
 if case['ndb']is not None:blob(script+0x38,case['ndb'])
 for off,key in [(8,'stackSize'),(12,'instructionPtr'),(16,'secondaryPtr'),(0x48,'scriptEventId')]:m.wi(script+off,case[key])
 exo(script+0x18,case['name']);exo(script+0x90,case['scriptChunk']);s=case['stack'];m.wi(stack,s['stackPointer']);m.wi(stack+4,s['basePointer']);m.wi(stack+8,s['totalSize']);m.wq(stack+24,vm);m.wq(vm+0x858,impl);m.wq(impl,vtable);m.wq(vtable+0x50,fake);ptr=alloc(len(s['cells'])*24);m.wq(stack+16,ptr)
 for i,c in enumerate(s['cells']):
  p=ptr+i*24;t=c['type']&255;u.mem_write(p+16,bytes([t]));v=c['value']
  if t==5:exo(p,v)
  elif t==4:m.wf(p,v)
  elif t in [3,6]:m.wi(p,v)
  else:a=alloc(8);tokens[a]=v;m.wq(p,a)
 head=alloc(16);m.wq(head,head);m.wq(head+8,head);m.wq(script+0x58,head);previous=head
 for e in case['jumps']:
  p=alloc(0x48);m.wq(previous,p);m.wq(p+8,previous);m.wq(p,head);previous=p;b=e['label'].encode('ascii');m.wq(p+0x20,len(b))
  if len(b)<=15:u.mem_write(p+0x10,b+b'\0');m.wq(p+0x28,15)
  else:a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p+0x10,a);m.wq(p+0x28,len(b))
  for off,key in [(0x38,'vmInstPtr'),(0x3c,'instPtr'),(0x40,'stackPtr'),(0x44,'instPtrLevel'),(0x34,'retVal')]:m.wi(p+off,e[key])
  u.mem_write(p+0x30,bytes([e['fromJmp']&255]))
 m.wq(head+8,previous);rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[vm,script,gff,root]):u.reg_write(reg,v)
 try:u.emu_start(0x140284d00,m.stop,count=100000)
 except Exception:print(json.dumps(dict(name=case['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=case,output=nodes[0],calls=calls,status=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
def base():return dict(code=[0x20,0],ndb=None,instructionPtr=0,secondaryPtr=0,name='situation',stackSize=0,stack=dict(basePointer=0,stackPointer=0,totalSize=0,cells=[]),jumps=[],scriptChunk='',scriptEventId=0)
cases=[base()]
for capacity in [0,16,32,-1]:
 c=base();c['stack']['totalSize']=capacity;c['name']='empty-capacity-'+str(capacity);cases.append(c)
c=base();c['name']='all-cell-types';c['code']=list(range(256));c['ndb']=[0,1,2,255];c['instructionPtr']=-1;c['secondaryPtr']=17;c['stackSize']=93;c['stack']=dict(basePointer=2,stackPointer=14,totalSize=30,cells=[dict(type=t,value=v)for t,v in [(3,-1),(4,1.25),(5,'text\0tail'),(6,0xffffffff),(16,10),(17,11),(18,12),(19,13),(20,14),(21,15),(22,16),(23,17),(0,18),(255,19)]]);c['jumps']=[dict(label='a\0tail',vmInstPtr=-1,instPtr=2,stackPtr=3,instPtrLevel=4,fromJmp=255,retVal=-5),dict(label='long-label-over-fifteen',vmInstPtr=11,instPtr=22,stackPtr=33,instPtrLevel=44,fromJmp=1,retVal=55)];c['scriptChunk']='chunk\0tail';c['scriptEventId']=-1;cases.append(c)
rng=random.Random(284)
for i in range(70):
 c=base();c['name']='random-'+str(i);c['code']=[rng.randrange(256)for _ in range(rng.randrange(50))];c['ndb']=rng.choice([None,[],[1,2,0,3]]);c['instructionPtr']=rng.randrange(-1,200);c['secondaryPtr']=rng.randrange(-1,200);c['stackSize']=rng.randrange(100);cells=[]
 for j in range(rng.randrange(14)):
  t=rng.choice([3,4,5,6,16,17,18,19,20,21,22,23,24,25]);v=rng.choice(['','text','nul\0tail'])if t==5 else rng.choice([-2.5,0,1.25])if t==4 else rng.getrandbits(32)if t==6 else rng.randrange(-1000,1000);cells.append(dict(type=t,value=v))
 c['stack']=dict(basePointer=rng.randrange(len(cells)+1),stackPointer=len(cells),totalSize=len(cells)+16,cells=cells);c['jumps']=[dict(label=rng.choice(['','a\0b','fifteen-letters!','more-than-fifteen-letters']),vmInstPtr=j,instPtr=-j,stackPtr=rng.randrange(10),instPtrLevel=rng.randrange(3),fromJmp=rng.randrange(256),retVal=rng.randrange(-5,5))for j in range(rng.randrange(4))];c['scriptEventId']=rng.randrange(-1,100);cases.append(c)
path=m.root/'backups/animations/native-script-situation-save-observations.json';path.write_text(json.dumps(dict(target=m.digest,cases=[run(c)for c in cases]),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(path))))
