"""Complete CreateReferenceObjects08db90, deleting destructor08acf0 and
reference InternalControl0524d0 with the base controller captured.
Synthetic physical trees; NewCAurObject/attachment/name/cast and Part dtor/free
captured lower boundaries. No child resource decoding or renderer equivalence.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
owner=m.heap+0x1000;vt=m.heap+0x2000;model=m.heap+0x3000;partbase=m.heap+0x10000
def label(ptr):return (ptr-partbase)//0x400
def text(ptr):return bytes(u.mem_read(ptr,64)).split(b'\0')[0].decode('ascii')
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop+0x10:
  if c['mode']=='control':calls.append(['asReference'])
  m.finish(x if flags[label(x)] else 0)
 elif a==m.stop+0x20:m.finish(x+0x240)
 elif a==m.stop+0x30:calls.append(['attach',text(z),w&0xffffffff]);m.finish()
 elif a==m.stop+0x40:calls.append(['destroy',y&0xffffffff]);m.finish()
 elif a==0x1400931f0:calls.append(['create',text(x),y,z]);m.finish(model)
 elif a==0x140089d20:calls.append(['destroyPart']);m.finish()
 elif a in [0x140c4f024,0x140c10360]:calls.append(['free',y&0xffffffff]);m.finish()
 elif a==0x140051c50:calls.append(['control',m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(u.reg_read(UC_X86_REG_RSP)+0x28)]);m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14008db90,0x14008dc5a),(0x14008acf0,0x14008ad50),(0x1400524d0,0x14005251e)]):raise AssertionError(f'Unexpected reference dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,flags
 c=case;calls=[];flags=case.get('flags',[1,0,1,1]);u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(model,vt);m.wq(vt+0x98,m.stop+0x30);m.wq(vt,m.stop+0x40)
 edges=case.get('children',[[1,2],[3],[],[]])
 for i,ref in enumerate(flags):
  p=partbase+i*0x400;m.wq(p,p+0x300);m.wq(p+0x300+0x70,m.stop+0x10);m.wq(p+0x300+8,m.stop+0x20);m.wq(p+8,p+0x100);m.wi(p+0x100+0x98,0x11);u.mem_write(p+0x1a0,f'model{i}\0'.encode());u.mem_write(p+0x240,f'part{i}\0'.encode());m.wq(p+0x38,p+0x280);m.wi(p+0x40,len(edges[i]));m.wq(p+0x68,model if case.get('present',False) else 0)
  for j,child in enumerate(edges[i]):m.wq(p+0x280+j*8,partbase+child*0x400)
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,owner if case['mode'] in ['create','control'] else partbase);u.reg_write(UC_X86_REG_RDX,partbase if case['mode'] in ['create','control'] else case['deleteFlags'])
 if case['mode']=='control':
  import struct
  for r,v in [(UC_X86_REG_XMM2,case['previous']),(UC_X86_REG_XMM3,case['time'])]:u.reg_write(r,int.from_bytes(struct.pack('<f',v),'little'))
  m.wf(rsp+0x28,case['weight'])
 try:u.emu_start(dict(create=0x14008db90,destroy=0x14008acf0,control=0x1400524d0)[case['mode']],m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=case,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=case,calls=calls,owned=[bool(m.q(partbase+i*0x400+0x68))for i in range(len(flags))])
rows=[run(dict(mode='create',flags=list(flags),children=children))for flags,children in itertools.product(itertools.product([0,1],repeat=4),[[[1,2],[3],[],[]],[[1],[2],[3],[]],[[],[],[],[]]])]
rows += [run(dict(mode='destroy',deleteFlags=f,present=p))for f,p in itertools.product([0,1,2,3,255,256,-1],[False,True])]
controls=[run(dict(mode='control',flags=[cast,0,0,0],previous=p,time=t,weight=w))for cast,p,t,w in itertools.product([0,1],[0,.2],[0,.7],[0,.5,1,2])]
out=m.root/'backups/animations/native-model-reference-owner-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,controls=controls))+'\n');print(json.dumps(dict(output=str(out),rows=len(rows),controls=len(controls))))
