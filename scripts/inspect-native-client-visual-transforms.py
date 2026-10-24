"""Original scoped-model adapter968190 and curve interpolation2e9a80.

Model lookup and Gob assignment are captured with synthetic scoped models.
Tree iteration, root/identity admission, BYTE scope conversion and stale-scope
reset execute unchanged. Interpolation captures Progress and host float math;
this checks native branch arithmetic, not original CRT transcendental bits.
"""
import sys,importlib,json,struct,itertools,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
ctx,tree,head,table,gobTable,lookup,assign,curve=[m.heap+n*0x1000 for n in range(1,9)]
cursor=0x20000
def alloc(n):
 global cursor
 p=m.heap+cursor;cursor+=(n+15)&~15;assert cursor<0xf0000;u.mem_write(p,bytes(n));return p
def float_result(value):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
def hook(u,a,n,data):
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop:u.emu_stop();return
 if a==lookup:
  trace.append(['lookup',y&255]);m.finish(models.get(y&255,0));return
 if a==assign:
  trace.append(['assign',next(k for k,v in models.items()if v==x),m.rf(y+4)if m.heap<=y<m.heap+0x100000 else 'identity']);m.finish();return
 if a==0x140c4f038:
  p=alloc(y)
  if x:u.mem_write(p,bytes(u.mem_read(x,min(y,0x1000))))
  m.finish(p);return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x140c4f024:m.finish();return
 if a==0x1402e9cd0:float_result(progress);return
 if a in [0x140c7a2b0,0x140c7ac70,0x140c7a9a8]:
  value=m.xmm(UC_X86_REG_XMM0);float_result(({0x140c7a2b0:math.sin,0x140c7ac70:math.cos,0x140c7a9a8:math.asin}[a])(value));return
 if not (0x140968190<=a<=0x1409684ef or 0x1402e9a80<=a<=0x1402e9ccf):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def call(entry,x):
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,x);u.reg_write(UC_X86_REG_RDX,tree)
 u.emu_start(entry,m.stop,count=50000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def run(keys,previous,available):
 global cursor,models,trace
 cursor=0x20000;trace=[];u.mem_write(m.heap,bytes(0x100000));m.wq(ctx,table);m.wq(table+0x10,lookup);m.wq(gobTable+0xd8,assign)
 models={k:alloc(16)for k in available}
 for p in models.values():m.wq(p,gobTable)
 m.wq(ctx+0xc8,models[255]);m.wq(tree,head);u.mem_write(head+25,b'\x01')
 nodes=[]
 for key in sorted(set(keys)):
  p=alloc(680);m.wi(p+32,key);m.wf(p+44,key+1000);nodes.append(p)
 def build(lo,hi,parent):
  if lo>=hi:return head
  mid=(lo+hi)//2;p=nodes[mid];m.wq(p+8,parent);m.wq(p,build(lo,mid,p));m.wq(p+16,build(mid+1,hi,p));return p
 m.wq(head+8,build(0,len(nodes),head));m.wq(head,nodes[0]if nodes else head);m.wq(head+16,nodes[-1]if nodes else head)
 old=alloc(max(1,len(previous))*4)
 for i,k in enumerate(previous):m.wi(old+i*4,k)
 m.wq(ctx+0x108,old);m.wi(ctx+0x110,len(previous));m.wi(ctx+0x114,len(previous))
 call(0x140968190,ctx);count=m.si(ctx+0x110);ptr=m.q(ctx+0x108)
 return dict(keys=keys,previous=previous,available=available,trace=trace,scopes=[m.si(ptr+i*4)for i in range(count)])
rows=[]
for keys,previous,available in itertools.product([[],[0],[255],[0,255],[0,18,254],[-257,-2,-1,0,18,244,256],[0,1,2,243,252,253,254,255]],[[0],[0,255],[0,18,254],[0,244,255]],[[255],[18,254,255],[18,244,254,255]]):rows.append(run(keys,previous,available))
for previous in [[],[0,255],[0,18,254,255]]:rows.append(run(list(range(25)),previous,list(range(25))+[255]))
curves=[]
for kind,progress,source,target in itertools.product(range(10),[0,.1,.25,.5,.75,.9,1],[-3.25,0,2.5],[0,1,7.75]):
 u.mem_write(curve,bytes(64));m.wi(curve+12,kind);m.wf(curve+4,target);m.wf(curve+8,source);call(0x1402e9a80,curve)
 curves.append(dict(kind=kind,progress=progress,source=source,target=target,bits=u.reg_read(UC_X86_REG_XMM0)&0xffffffff))
out=m.root/'backups/animations/native-client-visual-transforms-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,scopes=rows,curves=curves),indent=2)+'\n');print(json.dumps(dict(scopes=len(rows),curves=len(curves))))
