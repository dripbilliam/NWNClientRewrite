"""Complete CopyItem VM wrapper, container AcquireItem and store AcquireItem.
Original optional typed-pop gates, pointer mutation/result, acquisition routing,
fallback placement, rejection and side-effect order execute. Capture allocation,
item copy, casts/lookups, repository, possession/removal/identification and store
sorting/tag/compare boundaries; those lower owners are independently validated.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
command,vm,app,src,dst,target,vt,area,repo,ref,old,bag,existing,info,info2=[m.heap+i*0x1000 for i in range(15)]
ranges=[(0x140512600,0x1405128e6),(0x140463e80,0x1404640d9),(0x1404f9ea0,0x1404fa04a)]

def ident(p):return 0 if not p else m.si(p+(0x50 if p in[src,dst,existing,bag]else 8))&0xffffffff
def mutation(p):
 if c.get('mutation')=='existing':m.wq(p,existing)
 elif c.get('mutation')=='null':m.wq(p,0)
def hook(u,a,n,_):
 global popIndex,output
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in[0x140286160,0x140286110]:
  trace.append(['pop','object'if a==0x140286160 else'int']);ok=popIndex!=c.get('failPop',-1)
  if ok:m.wi(y,args[popIndex])
  popIndex+=1;m.finish(int(ok))
 elif a==0x140286470:output=y&0xffffffff;trace.append(['push',output]);m.finish(c.get('push',1))
 elif a==0x14055b6c0:
  trace.append(['item',y&0xffffffff]);m.finish((src if c.get('source',True)else 0)if c['mode']=='wrapper'else(existing if c.get('existing',False)else 0)if c['mode']=='store'else(bag if c.get('bag',False)else 0))
 elif a==0x14055b4c0:trace.append(['object',y&0xffffffff]);m.finish(target if c.get('target',True)else 0)if c['mode']=='wrapper'else m.finish(old if c.get('old',0)else 0)
 elif a==0x14055b3d0:trace.append(['creature',y&0xffffffff]);m.finish(target if c.get('parent',False)else 0)
 elif m.stop+0x20<=a<=m.stop+0x60:
  cast={m.stop+0x20:'world',m.stop+0x30:'creature',m.stop+0x40:'placeable',m.stop+0x50:'item',m.stop+0x60:'store'}[a];trace.append(['cast',cast]);kind=c.get('kind',5)if c['mode']=='wrapper'else c.get('old',0)
  m.finish(x if(cast=='world'and c.get('world',True)or kind=={'world':-1,'creature':5,'placeable':9,'item':6,'store':14}[cast])else 0)
 elif a==m.stop+0x10:trace.append(['destroy',ident(x),y&0xffffffff]);m.finish()
 elif a==0x140c10324:trace.append(['allocate',x]);m.finish(dst)
 elif a==0x140462e90:trace.append(['construct',y&0xffffffff]);m.finish(dst)
 elif a==0x140466910:trace.append(['copy',z&0xffffffff]);m.finish(c.get('copy',1))
 elif a==0x14046c520:trace.append(['possessor',ident(x),y&0xffffffff,z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)]);m.wi(x+0x3c8,y);m.finish()
 elif a==0x140494e80:trace.append(['area','source'if x==src+0x48 else'target']);m.finish(area if c.get('area',True)else 0)
 elif a==0x140464bb0:trace.append(['addArea',ident(x),int(y!=0),m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28),m.si(rsp+0x30)]);m.finish()
 elif a in[0x1403cff30,0x1404b11d0,0x140463e80,0x1404f9ea0]and c['mode']=='wrapper':
  kind={0x1403cff30:5,0x1404b11d0:9,0x140463e80:6,0x1404f9ea0:14}[a]
  extra=[z&0xffffffff,w&0xffffffff,m.si(rsp+0x28)&255,m.si(rsp+0x30)&255,m.si(rsp+0x38),m.si(rsp+0x40)]if kind==5 else[z&0xffffffff,w&255,m.si(rsp+0x28)&255,m.si(rsp+0x30)]if kind!=14 else[z&0xffffffff,w&255,m.si(rsp+0x28)&255]
  trace.append(['acquire',kind,*extra]);
  if kind!=14:mutation(y)
  m.finish(c.get('acquire',1))
 elif a==0x1404681d0:trace.append(['find',m.si(rsp+0x28)]);u.mem_write(z,bytes([1]));u.mem_write(w,bytes([2]));m.finish(c.get('find',1))
 elif a==0x140465c10:trace.append(['fit',z&255,w&255]);m.finish(c.get('fit',1))
 elif a==0x1403d7490:trace.append(['removeCreature',ident(x),ident(y),z&0xffffffff,w&0xffffffff,m.si(rsp+0x28),m.si(rsp+0x30)]);m.finish()
 elif a==0x1404b69d0:trace.append(['removePlaceable',ident(y),z&0xffffffff]);m.finish()
 elif a==0x14046b250:trace.append(['removeRepo',ident(y)]);m.finish()
 elif a==0x14029ca00:trace.append(['base',y&0xffffffff]);m.finish(info if y==49 else info2)
 elif a==0x140464200:trace.append(['add',z&255,w&255,m.si(rsp+0x28),m.si(rsp+0x30)]);mutation(y);m.finish(c.get('add',1))
 elif a==0x14046b1d0:trace.append(['removeArea',ident(x)]);m.finish()
 elif a==0x14046c420:trace.append(['identified',y&0xffffffff]);m.wi(x+0x360,y);m.finish()
 elif a==0x1404fb590:trace.append(['panel',y&0xffffffff]);m.finish(c.get('panel',2))
 elif a==0x1404680a0:trace.append(['findTag']);m.finish(44)
 elif a==0x140466220:trace.append(['compare']);m.finish(c.get('compare',1))
 elif a==0x1404fa1b0:trace.append(['storeAdd',z&255,w&255,m.si(rsp+0x28)&255]);mutation(y);m.finish(c.get('add',1))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unmapped copy acquisition dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,trace,popIndex,args,output
 c=case;trace=[];popIndex=0;output=None;u.mem_write(m.heap,bytes(0x30000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df910,vm);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,app)
 for p,id in[(src,42),(dst,c.get('id',43)),(existing,44),(target,101),(old,102),(bag,103)]:
  m.wq(p,vt);m.wi(p+8,id);m.wi(p+0x50,id);m.wi(p+0x40,49 if p==src else 50);m.wi(p+0x3c8,0x7f000000)
 for offset,address in[(0,m.stop+0x10),(0x20,m.stop+0x20),(0x60,m.stop+0x30),(0x98,m.stop+0x40),(0x70,m.stop+0x50),(0xd0,m.stop+0x60)]:m.wq(vt+offset,address)
 m.wi(src+0x3c8,c.get('possessor',0x7f000000));m.wi(bag+0x3c8,c.get('bagParent',0x7f000000));m.wi(src+0x144,c.get('plot',0));m.wi(existing+0x444,c.get('infinite',0));u.mem_write(old+12,bytes([c.get('old',0)]));m.wq(old+0x3d0,repo if c.get('oldRepo',True)else 0)
 m.wq(src+0x3d0,repo if c.get('incomingRepo',False)else 0);m.wq(target+0x3d0,repo if c.get('repo',True)else 0);m.wq(ref,src);m.wi(info+0x80,c.get('container',0));m.wi(info2+0x80,c.get('bagContainer',0))
 for i,value in enumerate([1.25,-2.5,3.75]):m.wf(src+0xec+i*4,value);m.wf(target+0xa4+i*4,value*2)
 for i in range(5):m.wq(target+0x328+i*8,repo)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c['mode']=='wrapper':entry=0x140512600;args=[42,c.get('targetId',101),c.get('variables',1)];registers=[command,0,c.get('argc',3),0];extra=[]
 elif c['mode']=='container':entry=0x140463e80;registers=[target,ref,c.get('sourceId',0x7f000000),c.get('x',255)&255];extra=[c.get('y',255)&255,c.get('feedback',1)]
 else:entry=0x1404f9ea0;registers=[target,0 if c.get('null',False)else src,c.get('flag',0),3];extra=[4]
 for i,value in enumerate(extra):m.wq(rsp+0x28+i*8,value&0xffffffffffffffff)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],registers):u.reg_write(r,v&0xffffffffffffffff)
 try:u.emu_start(entry,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 pointer=m.q(ref);return dict(case=c,trace=trace,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,itemId=ident(pointer),possessor=m.si(pointer+0x3c8)&0xffffffff if pointer else None)
cases=[dict(mode='wrapper',argc=n,kind=k,acquire=a,mutation=mu,variables=v)for n,k,a,mu,v in itertools.product([1,2,3],[5,9,6,14,10],[0,1,-1],['keep','existing','null'],[0,-1])]
cases +=[dict(mode='wrapper',**d)for d in[dict(source=False),dict(copy=0),dict(target=False),dict(world=False),dict(targetId=0x7f000000),dict(argc=1),dict(argc=1,possessor=101),dict(area=False,acquire=0),dict(push=0),dict(id=0x80000042),*[dict(failPop=n)for n in range(3)]]]
cases +=[dict(mode='container',repo=r,incomingRepo=inc,find=f,fit=fit,add=a,mutation=mu,x=x,y=y)for r,inc,f,fit,a,mu,x,y in itertools.product([False,True],[False,True],[0,1],[0,1],[0,1,2],['keep','existing','null'],[255,3],[255,4])]
cases +=[dict(mode='container',possessor=103,bag=b,bagParent=parent,old=oldKind,container=ct,bagContainer=bct)for b,parent,oldKind,ct,bct in itertools.product([False,True],[0x7f000000,99],[0,5,9,6,10],[0,1],[0,1])]
cases +=[dict(mode='store',old=o,parent=p,existing=e,infinite=i,compare=cmp,add=a)for o,p,e,i,cmp,a in itertools.product([0,5,6,9],[False,True],[False,True],[0,1],[0,1],[0,1,2])]
cases +=[dict(mode='store',**d)for d in[dict(null=True),dict(plot=1),dict(plot=-1),dict(panel=5),dict(flag=-1),dict(mutation='null'),dict(mutation='existing')]]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-script-item-copy-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
