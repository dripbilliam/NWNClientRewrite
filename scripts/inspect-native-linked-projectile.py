"""Complete original initialize987f10 kinds7/12 with actual vector/random
math and the model graph services captured. Synthetic target/model/scene views;
this proves graph call order and arguments, not model resource availability or
the original outer model cache and scene schedule. Kind12 CRT math uses SSE0.
Destructor9835c0 also executes, with arrays/list/base/model services captured;
its auxiliary detach/scene/delete/clear ordering is retained separately.
"""
import importlib,itertools,json,struct,math
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,node,obj,ovt,model,mvt,app,argument,aux,avt,scene=[m.heap+n*0x1000 for n in range(1,12)]
ranges=[(0x140987f10,0x140988d59),(0x140230920,0x1402309f6),(0x1402303d0,0x14023040d),(0x140c79a38,0x140c79c87),(0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f),(0x140c79d30,0x140c7a2aa),(0x140c92d20,0x140c93360)]
r=json.loads((m.root/'backups/animations/rea-client-projectile-special-distance-round.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges.extend((int(e['start'],16),int(e['end'],16)+1)for e in r['ranges'])
def read(p,n=3):return[m.rf(p+i*4)for i in range(n)]
def write(p,v):
 for i,x in enumerate(v):m.wf(p+i*4,x)
def text(p):return bytes(u.mem_read(p,32)).split(b'\0')[0].decode('ascii')
def who(p):return'actor'if p==actor else'target'if p==obj else'model'if p==model else'aux'
def hook(u,a,n,_):
 global seed,actorModelSeen
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406abb70:
  if actorModelSeen and c['kind']==7:calls.append(['clientArray'])
  m.finish(app if c['array']else 0)
 elif a==0x140296470:calls.append(['getObject',y&0xffffffff]);m.wq(z,obj);m.finish(c['lookup'])
 elif a==m.stop+0x10:
  calls.append(['model',who(x)]);actorModelSeen|=x==actor;m.finish(model if(c['ownModel']if x==actor else c['targetModel'])else 0)
 elif a==m.stop+0x20:
  calls.append(['nodePose',text(y)])
  if c['pose']:write(z,[10,11,12])
  m.finish(c['pose'])
 elif a==0x1400931f0:calls.append(['newRef',text(x),text(y)]);m.finish(aux if c['aux']else 0)
 elif a==m.stop+0x30:calls.append(['reattach',who(y),text(z)]);m.finish()
 elif a==m.stop+0x40:
  if c.get('mode')=='destroy':calls.append(['clearMain']);m.finish()
  else:calls.append(['modelPosition']);write(y,read(model+0xa8));m.finish(y)
 elif a==m.stop+0x50:calls.append(['setModelPosition',who(x),read(z)]);write(x+0xa8,read(z));write(y,read(z));m.finish(y)
 elif a==m.stop+0x60:calls.append(['modelOrientation']);write(y,read(model+0xb4,4));m.finish(y)
 elif a==m.stop+0x70:calls.append(['setModelOrientation',who(x),read(z,4)]);write(x+0xb4,read(z,4));write(y,read(z,4));m.finish(y)
 elif a==m.stop+0x80:calls.append(['modelScene']);m.finish(scene)
 elif a==m.stop+0x90:calls.append(['setModelScene',who(x)]);m.finish()
 elif a==m.stop+0xa0:calls.append(['detachAuxiliary',y,z,w&0xffffffff]);m.finish()
 elif a==m.stop+0xb0:calls.append(['destroyAuxiliary',y&0xffffffff]);m.finish()
 elif a==m.stop+0xc0:calls.append(['destroyMain',y&0xffffffff]);m.finish()
 elif a in [0x140296360,0x140168dc0,0x140c10360,0x140c10370,0x140761a70]:m.finish()
 elif a==0x140c7ed00:seed=(seed*214013+2531011)&0xffffffff;m.finish((seed>>16)&32767)
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif a==0x140cae8e0:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in ranges+[(0x1409835c0,0x140983820)]):raise AssertionError(f'Unexpected linked initializer dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,seed,actorModelSeen
 c=dict(kind=7,targetId=0x80000063,lookup=0,pose=1,array=True,ownModel=True,targetModel=True,aux=True,seed=77)|case;calls=[];seed=c['seed'];actorModelSeen=False;u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wi(0x1415d8224,0);m.wi(0x141428e7c,0);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 for p in [actor,obj]:m.wq(p,ovt)
 m.wq(ovt+0x140,m.stop+0x10);m.wq(model,mvt);m.wq(aux,avt);m.wq(mvt+0x138,m.stop+0x20);m.wq(mvt+0x150,m.stop+0x30);m.wq(mvt+0xc0,m.stop+0x40);m.wq(mvt+0xb0,m.stop+0x50);m.wq(avt+0xb0,m.stop+0x50);m.wq(mvt+0xc8,m.stop+0x60);m.wq(avt+0xb8,m.stop+0x70);m.wq(mvt+0x218,m.stop+0x80);m.wq(avt+0x90,m.stop+0x90)
 write(actor+0x38,[1.25,-2,3.5]);write(actor+0x44,[.5,.25,.75]);write(actor+0x188,[8,9,10]);write(actor+0x204,[2,3,4]);write(actor+0x210,[5,6,7]);m.wi(actor+0x194,1000);m.wi(actor+0x198,c['targetId']);m.wq(actor+0x228,node);u.mem_write(node+0x2d,bytes([c['kind']]));write(node,[4,5,6]);u.mem_write(obj+0xc,b'\x05');write(obj+0x38,[21,22,23]);m.wq(actor+0x1a0,m.heap+0xc000);u.mem_write(m.heap+0xc000,b'impact\0');write(model+0xa8,[2,3,4]);write(model+0xb4,[.5,.5,.5,.5]);write(argument,[.5,.25,.75])
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,argument)
 try:u.emu_start(0x140987f10,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,auxiliary=bool(m.q(actor+0x230)),modelPosition=read(model+0xa8),auxPosition=read(aux+0xa8),auxOrientation=read(aux+0xb4,4),velocity=read(actor+0x204),acceleration=read(actor+0x210))
rows=[run(dict(kind=kind,targetId=id,lookup=lookup,pose=pose,ownModel=own,targetModel=target,aux=a))for kind,id,lookup,pose,own,target,a in itertools.product([7,12],[0x7f000000,0x80000063],[0,1],[0,1],[False,True],[False,True],[False,True])if kind==7 or own]
rows += [run(dict(targetId=0x7f000000,array=False))]
def deletion(present,main):
 global c,calls,actorModelSeen
 c=dict(mode='destroy',kind=0,array=True);calls=[];actorModelSeen=False;u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(actor+0x220,node);m.wq(actor+0x230,aux if present else 0);m.wq(actor+0x78,model if main else 0);m.wq(aux,avt);m.wq(avt+0x98,m.stop+0xa0);m.wq(avt+0x90,m.stop+0x90);m.wq(avt,m.stop+0xb0);m.wq(model,mvt);m.wq(mvt+0xc0,m.stop+0x40);m.wq(mvt,m.stop+0xc0)
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.emu_start(0x1409835c0,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(present=present,main=main,calls=calls,auxiliary=bool(m.q(actor+0x230)))
deletions=[deletion(present,main)for present,main in itertools.product([False,True],[False,True])]
out=m.root/'backups/animations/native-linked-projectile-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,deletions=deletions))+'\n');print(json.dumps(dict(output=str(out),rows=len(rows),deletions=len(deletions))))
