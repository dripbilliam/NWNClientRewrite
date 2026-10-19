"""Original variable hash byte routine and native hash _Insert/find bodies.
Node allocation/unlinking and _Init's bucket storage are captured successful
heap boundaries. Initial layout is from CNWSObject48b760: load1, eight buckets.
No original install writes or native-process injection.
"""
import importlib,sys,json,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
h=Uc(UC_ARCH_X86,UC_MODE_64);h.mem_map(0x14016c000,0x2000);h.mem_write(0x14016c000,bytes(u.mem_read(0x14016c000,0x2000)))
hmem,hstack,hstop=0x500000000,0x600000000,0x700000000
for p in [hmem,hstack,hstop]:h.mem_map(p,0x10000)
def nativeHash(data):
 h.mem_write(hmem,bytes(data)+b'\0');rsp=hstack+0xff08;h.mem_write(rsp,hstop.to_bytes(8,'little'));h.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[hmem,len(data),0]):h.reg_write(reg,v)
 h.emu_start(0x14016ca80,hstop,count=50000);assert h.reg_read(UC_X86_REG_RIP)==hstop;return h.reg_read(UC_X86_REG_RAX)&0xffffffff
empty=nativeHash(b'')
ranges=[]
for name in ['object-var-native-insert','object-var-hash-find']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
table,head,out,key=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000,m.heap+0x4000
def alloc(n):
 global cursor
 p=m.heap+0x10000+cursor;cursor+=(n+15)&~15;assert cursor<0xe0000;return p
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')
def exo(p,name):
 b=name.encode('ascii');ptr=alloc(len(b)+1);u.mem_write(ptr,b+b'\0');m.wq(p,ptr);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def initialize(count):
 ptr=alloc(count*16);u.mem_write(ptr,head.to_bytes(8,'little')*(count*2));m.wq(table+0x18,ptr);m.wq(table+0x20,ptr+count*16);m.wq(table+0x28,ptr+count*16);m.wq(table+0x30,count-1);m.wq(table+0x38,count)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y=u.reg_read(UC_X86_REG_RCX),u.reg_read(UC_X86_REG_RDX)
 if a==0x14016b780:m.finish(nativeHash(bytes(u.mem_read(m.q(x),m.si(x+8))))^empty);return
 if a==0x140368c30:assert x==table;initialize(y);m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured native variable container dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(entry,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 u.emu_start(entry,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop,hex(u.reg_read(UC_X86_REG_RIP))
def find(name):
 exo(key,name);invoke(0x140508c40,[table,out,key]);return m.q(out)
def nodes():
 result=[];p=m.q(head)
 while p!=head:assert p not in result;result.append(p);p=m.q(p)
 return result
def run(operations):
 global cursor
 cursor=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wf(table,1);m.wq(table+8,head);m.wq(head,head);m.wq(head+8,head);initialize(8);results=[]
 for kind,name in operations:
  matched=find(name)
  if kind=='set'and matched==head:
   p=alloc(0x90);exo(p+0x10,name);first=m.q(head);m.wq(p,first);m.wq(p+8,head);m.wq(first+8,p);m.wq(head,p);m.wq(table+0x10,m.q(table+0x10)+1)
   invoke(0x14048b0d0,[table,out,p+0x10,p]);matched=m.q(out)
  elif kind=='delete'and matched!=head:
   m.wq(m.q(matched+8),m.q(matched));m.wq(m.q(matched)+8,m.q(matched+8));m.wq(table+0x10,m.q(table+0x10)-1)
   # Captured successful unlink: re-establish endpoint pointers without
   # reordering remaining nodes or shrinking the native bucket allocation.
   count=m.q(table+0x38);ptr=m.q(table+0x18);u.mem_write(ptr,head.to_bytes(8,'little')*(count*2))
   for p in nodes():
    bucket=(nativeHash(bytes(u.mem_read(m.q(p+0x10),m.si(p+0x18))))^empty)&(count-1)
    if m.q(ptr+bucket*16)==head:m.wq(ptr+bucket*16,p)
    m.wq(ptr+bucket*16+8,p)
  results.append(dict(operation=[kind,name],match=None if matched==head else text(matched+0x10),order=[text(p+0x10)for p in nodes()],buckets=m.q(table+0x38)))
 return dict(operations=operations,results=results)
rng=random.Random(5080);scenarios=[]
scenarios.append([['set',''],['set','A'],['set','a'],['set','a\0xx'],['set','a\0yy'],['set','a\0zz'],['get','a\0xx'],['delete','A'],['set','A']])
scenarios.append([['set','variable_'+str(i)]for i in range(540)]+[['get','variable_'+str(i)]for i in [0,8,64,512,539]])
for i in range(12):
 names=[''.join(rng.choice('abcXYZ012_')for _ in range(rng.randrange(1,50)))for _ in range(80)]
 scenarios.append([[rng.choice(['set','set','get','delete']),rng.choice(names)]for _ in range(150)])
hashes=[dict(bytes=list(data),value=nativeHash(data))for data in [bytes(rng.randrange(256)for _ in range(n))for n in list(range(65))+[127,128,255,256,1024]]]
observations=[run(ops)for ops in scenarios]
output=m.root/'backups/animations/native-script-variable-order-observations.json';output.write_text(json.dumps(dict(target=m.digest,emptyHash=empty,hashes=hashes,scenarios=observations),indent=2)+'\n');print(json.dumps(dict(hashes=len(hashes),operations=sum(len(x)for x in scenarios),scenarios=len(scenarios))))
