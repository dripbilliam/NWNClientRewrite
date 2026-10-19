"""Complete original Gob::ReattachReference093b50 with actual RotationArc,
Vector::Normalize and quaternion multiplication. Synthetic physical trees;
part queries, attachment, child position and allocator/memmove/free are captured
lower boundaries. IEEE sqrtf is supplied by the host. No native scene/culling or
actual asset-attachment equivalence is claimed by these numerical cases.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
owner,target,vt,modelvt,names=[m.heap+n*0x1000 for n in range(1,6)];parts=m.heap+0x10000;models=m.heap+0x40000
ranges=[(0x140093b50,0x140093e27),(0x14022ab00,0x14022ac34),(0x14022e1c0,0x14022e2ed),(0x14022db30,0x14022dbf2)]
def read(a,n=3):return[m.rf(a+i*4)for i in range(n)]
def vector(a,v):
 for i,x in enumerate(v):m.wf(a+i*4,x)
def label(p):return (p-parts)//0x400
def text(p):return bytes(u.mem_read(p,64)).split(b'\0')[0].decode('ascii')
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:m.finish(x if c['references'][label(x)] else 0)
 elif a==m.stop+0x20:m.finish(x+0x240)
 elif a==m.stop+0x30:calls.append(['attach',(x-models)//0x400,'target'if y==target else 'owner',text(z),w&0xffffffff]);m.finish()
 elif a==m.stop+0x40:
  i=(x-models)//0x400;calls.append(['position',i,read(owner+0xb4,4)]);vector(y,c['childPositions'][i]);m.finish(y)
 elif a==0x140c4f038:
  p=m.heap+0x80000+allocation*0x400;allocation+=1
  if x:u.mem_write(p,bytes(u.mem_read(x,min(y,0x400))))
  m.finish(p)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x140c4f024:m.finish()
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unexpected reference reattach dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation
 c=case;calls=[];allocation=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(owner+0x90,parts);vector(owner+0xa8,c['position']);vector(owner+0xb4,c['quaternion']);m.wq(modelvt+0x98,m.stop+0x30);m.wq(modelvt+0xc0,m.stop+0x40);u.mem_write(names,b'impact\0')
 for i,ref in enumerate(c['references']):
  p=parts+i*0x400;model=models+i*0x400;children=m.heap+0x60000+i*0x400;m.wq(p,p+0x300);m.wq(p+0x300+0x70,m.stop+0x10);m.wq(p+0x300+8,m.stop+0x20);m.wq(p+8,p+0x100);m.wi(p+0x100+0x98,c['flags'][i]);m.wi(p+0x100+0xe0,c['reattachable'][i]);m.wq(p+0x68,model if c['present'][i]else 0);m.wq(model,modelvt);u.mem_write(p+0x240,f'part{i}\0'.encode());m.wq(p+0x38,children);m.wi(p+0x40,len(c['children'][i]))
  for j,child in enumerate(c['children'][i]):m.wq(children+j*8,parts+child*0x400)
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,owner);u.reg_write(UC_X86_REG_RDX,target if c['target']else 0);u.reg_write(UC_X86_REG_R8,names)
 try:u.emu_start(0x140093b50,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,quaternion=read(owner+0xb4,4))
def make(**kw):return dict(references=[1]*4,flags=[0x11]*4,reattachable=[1]*4,present=[True]*4,children=[[1,2],[3],[],[]],childPositions=[[1,2,3],[-3,1,2],[2,-2,-1],[0,0,0]],position=[0,0,0],quaternion=[1,0,0,0],target=True)|kw
qs=[[1,0,0,0],[0,1,0,0],[.5,.5,.5,.5],[2,.2,.3,-.4],[0,0,0,0],[math.cos(.3),0,math.sin(.3),0]]
rows=[run(make(references=[(mask>>i)&1 for i in range(4)],target=t,reattachable=[r]*4,quaternion=q))for mask,t,r,q in itertools.product(range(16),[False,True],[0,1,-1,2],qs)]
rows += [run(make(flags=[flag]*4,present=[present]*4,position=[2,-3,4]))for flag,present in itertools.product([0,1,0x10,0x11,0x31,0x111],[False,True])]
for count in [1,17,33]:
 rows.append(run(make(references=[1]*count,flags=[0x11]*count,reattachable=[1]*count,present=[True]*count,children=[list(range(1,count))]+[[]for _ in range(count-1)],childPositions=[[i+1,i%3-1,i%5+2]for i in range(count)])))
out=m.root/'backups/animations/native-reference-reattach-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
