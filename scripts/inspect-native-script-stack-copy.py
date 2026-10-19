"""Original CopyFromStack with captured fresh clear/heap/string/engine clones.
Valid storage and native clamp edges only; no corrupt/out-of-range memory claims.
"""
import importlib,sys,json,struct,random,copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);u.mem_map(m.heap+0x100000,0xf00000)
src,dst,vm,impl,vtable=[m.heap+n*0x1000 for n in range(1,6)];fake=m.stop+0x100
def alloc(n):
 global cursor
 assert 0<=n<0xc00000;p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xf00000;return p
def exo(p,value):
 b=value.encode('ascii');a=alloc(len(b)+1);u.mem_write(a,b+b'\0');m.wq(p,a);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def text(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('ascii')if m.q(p)else''
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x14027fb50:
  assert x==dst;u.mem_write(dst,bytes(24));m.finish();return
 if a==0x140c10368:m.finish(alloc(x));return
 if a==0x140c11414:u.mem_write(x,bytes(y*z));m.finish();return
 if a==0x14003d8c0:
  b=bytes(u.mem_read(y,z&0xffffffff));exo(x,''if not b or b[0]==0 else b.decode('ascii'));m.finish();return
 if a==fake:
  value=tokens[z];calls.append([y,value]);p=alloc(8);tokens[p]=dict(copied=value,kind=y);m.finish(p);return
 if not 0x14027fd60<=a<=0x140280019:raise RuntimeError(f'Uncaptured stack-copy dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def writeCell(p,cell):
 t,v=cell['type'],cell['value'];u.mem_write(p+16,bytes([t]))
 if t==4:m.wf(p,v)
 elif t==5:exo(p,v)
 elif 16<=t<=25:ptr=alloc(8);tokens[ptr]=v;m.wq(p,ptr)
 else:m.wi(p,v)
def snapshotCell(p):
 t=u.mem_read(p+16,1)[0];v=text(p)if t==5 else m.rf(p)if t==4 else m.si(p)&0xffffffff if t==6 else tokens[m.q(p)]if 16<=t<=25 else m.si(p)
 return dict(type=t,value=v)
def run(case):
 global cursor,tokens,calls
 cursor=0x10000;tokens={};calls=[];u.mem_write(m.heap,bytes(0x1000000));u.mem_write(m.stack,bytes(0x20000));ptr=alloc(len(case['cells'])*24);m.wq(src+16,ptr);m.wi(src,len(case['cells']));m.wi(src+4,case['basePointer']);m.wi(src+8,len(case['cells'])+16);m.wq(dst+24,vm);m.wq(vm+0x858,impl);m.wq(impl,vtable);m.wq(vtable+0x48,fake)
 for i,c in enumerate(case['cells']):writeCell(ptr+i*24,c)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[dst,src,case['topBytes']&0xffffffff,case['baseBytes']&0xffffffff]):u.reg_write(reg,v)
 try:u.emu_start(0x14027fd60,m.stop,count=30000000)
 except Exception:print(json.dumps(dict(name=case['name'],rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 out=dict(basePointer=m.si(dst+4),stackPointer=m.si(dst),totalSize=m.si(dst+8),cells=[snapshotCell(m.q(dst+16)+i*24)for i in range(m.si(dst))]);return dict(case=case,output=out,calls=calls)
def case(name,cells,bp,top,base):return dict(name=name,cells=cells,basePointer=bp,topBytes=top,baseBytes=base)
cells=[dict(type=t,value=v)for t,v in [(3,-7),(4,1.25),(5,'text\0tail'),(6,0xffffffff),(16,101),(17,102),(18,103),(19,104),(20,105),(21,106),(22,107),(23,108),(24,109),(25,110),(0,0xabcdef),(5,'\0tail')]]
cases=[case('empty',[],0,0,0),case('all-default',cells,6,0,0),case('top-only',cells,6,12,0),case('base-only',cells,6,0,12),case('overlapping',cells,6,64,24),case('negative',cells,6,-1,-1),case('unaligned',cells,6,7,11)]
rng=random.Random(27)
for i in range(100):
 n=rng.randrange(1,30);values=[dict(type=3,value=j*13-i)for j in range(n)];bp=rng.randrange(n+1);top=rng.randrange(n+1)*4+rng.randrange(4);base=rng.randrange(n+5)*4+rng.randrange(4);cases.append(case('random-'+str(i),values,bp,top,base))
for name,sp,bp,top,base in [('clamp-base',65540,65540,0,400000),('clamp-top',65540,0,400000,0),('clamp-both',65540,65540,400000,400000)]:cases.append(case(name,[dict(type=3,value=i)for i in range(sp)],bp,top,base))
out=m.root/'backups/animations/native-script-stack-copy-observations.json';out.write_text(json.dumps(dict(target=m.digest,cases=[run(c)for c in cases]),separators=(',',':'))+'\n');print(json.dumps(dict(cases=len(cases),output=str(out))))
