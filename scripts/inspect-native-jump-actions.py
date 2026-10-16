"""Read-only original JumpToObject1403c1a60 and JumpToPoint1403c2a90.
Normalization executes unchanged. Registry/cast, geometry/safe placement,
client, subarea, area-transfer and action-list allocation are captured lower
boundaries; these observations do not prove their internals or wire behavior.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,node,path,app,server,target,area,otherArea,vtable,associates,ids,associate=[m.heap+n*0x2000 for n in range(1,13)]
def vec(a):return [m.rf(a+i*4) for i in range(3)]
def writevec(a,v):
 for i,n in enumerate(v):m.wf(a+i*4,n)
def label(a):return {actor:99,target:77,associate:100,area:88,otherArea:89,0:None}[a]
def actorArea():return 0 if not c.get('actorArea',True) else area
def targetArea():return 0 if not c.get('targetArea',True) else otherArea if c.get('cross') else area
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404953b0:calls.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x140495620:calls.append(['dying']);m.finish(c.get('dying',0))
 elif a in [0x14055b390,0x14055f720]:calls.append(['client' if a==0x14055b390 else 'internalClient',y&0xffffffff]);m.finish(server if c.get('client') else 0)
 elif a==0x140494e80:calls.append(['area',label(x)]);m.finish(actorArea() if x==actor else targetArea())
 elif a==0x14055b6e0:m.finish(server)
 elif a==0x14047e400:calls.append(['inLimbo',y&0xffffffff]);m.finish(c.get('limbo',0))
 elif a==0x140484b60:calls.append(['removeLimbo',y&0xffffffff]);m.finish()
 elif a==0x14055b850:m.finish(server)
 elif a==0x140296470:calls.append(['lookup',y&0xffffffff]);m.wq(z,otherArea if c.get('cross') else area);m.finish(0 if c.get('exists',True) else 1)
 elif a==0x14055b4c0:calls.append(['object',y&0xffffffff]);m.finish(target if c.get('exists',True) else 0)
 elif a in [m.stop+0x10,m.stop+0x20,m.stop+0x30,m.stop+0x40]:
  name={m.stop+0x10:'asObject',m.stop+0x20:'asDoor',m.stop+0x30:'asCreature',m.stop+0x40:'asArea'}[a];calls.append([name,label(x)])
  m.finish(0 if (name=='asObject' and c.get('noObject')) or (name=='asCreature' and c.get('targetType',12)!=5) else x)
 elif a==m.stop+0x50:calls.append(['animation',y&0xffffffff]);m.finish()
 elif a==0x140420360:calls.append(['doorPoint',vec(z),w&0xffffffff]);writevec(y,c.get('doorPoint',[8,9,2]));m.finish(y)
 elif a==0x1404207f0:calls.append(['openState']);m.finish(c.get('open',0))
 elif a==0x14055b2e0:calls.append(['areaById',y&0xffffffff]);m.finish(otherArea if c.get('pendingArea',True) else 0)
 elif a in [0x140294980,0x140294460,0x140294750]:calls.append([{0x140294980:'resetInterTile',0x140294460:'resetGrid',0x140294750:'resetInterArea'}[a]]);m.finish()
 elif a==0x14036aa90:
  calls.append(['safe',label(x),vec(y),m.xmm(UC_X86_REG_XMM2),m.si(path+0x24),m.si(rsp+0x28)]);writevec(m.q(rsp+0x30),c.get('safePoint',[5,6,7]));m.finish(c.get('safe',1))
 elif a==0x140382920:calls.append(['closePanels',y&0xffffffff]);m.finish()
 elif a==0x14038a500:calls.append(['cutPath']);m.finish()
 elif a==0x14049b910:calls.append(['orientation',vec(y)]);writevec(actor+0xb0,vec(y));m.finish()
 elif a==0x14049bb40:calls.append(['position',vec(y),z&0xffffffff]);m.finish()
 elif a==0x1403db4a0:calls.append(['subareas',vec(y),z&0xffffffff]);m.finish()
 elif a==0x140380470:calls.append(['addArea',label(y),m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.rf(rsp+0x28),m.si(rsp+0x30),m.si(rsp+0x38)]);m.finish()
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish(associate if (y&0xffffffff)==100 else 0)
 elif a==0x14048d3f0:
  params=[];kind=w&0xffffffff;ptr=m.q(rsp+0x28);offset=0
  while kind:
   params.append([kind,m.si(ptr)]);kind=m.si(rsp+0x30+offset*16);ptr=m.q(rsp+0x38+offset*16);offset+=1
  calls.append(['front',label(x),y&0xffffffff,z&65535,params]);m.finish()
 elif a==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x1403c1a60,0x1403c2a8b),(0x1403c2a90,0x1403c37da),(0x140230920,0x1402309f5)]):raise AssertionError(f'Uncaptured jump dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,server);m.wq(server+8,server)
 for obj,kind,id in [(actor,5,99),(target,c.get('targetType',12),77),(associate,5,100),(area,c.get('areaType',4),88),(otherArea,c.get('areaType',4),89)]:
  m.wq(obj,vtable);m.wi(obj+8,id);u.mem_write(obj+0xc,bytes([kind]));writevec(obj+0xa4,[3,4,5]);writevec(obj+0xb0,c.get('orientation',[3,4,2]));m.wi(obj+0x4f4,89);writevec(obj+0x4f8,[11,12,13])
 for off,addr in [(0x20,m.stop+0x10),(0x30,m.stop+0x20),(0x60,m.stop+0x30),(0x50,m.stop+0x40),(0x100,m.stop+0x50)]:m.wq(vtable+off,addr)
 m.wi(area+0x140,88);m.wi(otherArea+0x140,89)
 m.wq(actor+0x530,path if c.get('path',True) else 0);m.wi(actor+0x4f4,c.get('lastArea',0x7f000000));m.wf(path+8,c.get('radius',.6));m.wi(path+0x24,0)
 m.wq(actor+0x900,associates);m.wq(associates,ids);m.wi(associates+8,len(c.get('associates',[100,101])))
 for i,id in enumerate(c.get('associates',[100,101])):m.wi(ids+i*4,id)
 m.wi(node+0x98,(c.get('count',8)<<16)|42)
 if c['operation']=='point':
  for i,v in enumerate([1,2,3]):m.wf(node+0x38+i*8,v)
  m.wi(node+0x50,89 if c.get('cross') else 88);m.wi(node+0x58,c.get('straight',1));m.wf(node+0x60,c.get('range',1));m.wf(node+0x68,c.get('facing',[0,2])[0]);m.wf(node+0x70,c.get('facing',[0,2])[1])
 else:m.wi(node+0x38,77);m.wi(node+0x40,c.get('straight',1))
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x900,bytes(0xa00));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,node)
 try:u.emu_start(0x1403c2a90 if c['operation']=='point' else 0x1403c1a60,m.stop,count=20000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,field8f8=m.si(actor+0x8f8),pathOwner=m.si(path+0x24))
if __name__=='__main__':
 rows=[run(dict(operation=op,dead=dead,dying=dying,path=path)) for op,dead,dying,path in itertools.product(['point','object'],[0,1,2],[0,1,2],[False,True])]
 rows += [run(dict(operation=op,actorArea=area,client=client,lastArea=last,limbo=limbo)) for op,area,client,last,limbo in itertools.product(['point','object'],[False,True],[False,True],[88,0x7f000000],[0,1])]
 rows += [run(dict(operation='point',count=count,straight=straight,range=range,safe=safe,cross=cross,client=client)) for count,straight,range,safe,cross,client in itertools.product([4,5,6,7,8],[0,1,-7],[.1,20],[0,1,2],[False,True],[False,True])]
 rows += [run(dict(operation='object',count=count,targetType=kind,targetArea=area,pendingArea=pending,straight=straight,safe=safe,cross=cross,client=client,open=open)) for count,kind,area,pending,straight,safe,cross,client,open in itertools.product([1,2],[5,9,10,12],[False,True],[False,True],[0,1,-7],[0,1],[False,True],[False,True],[0,1])]
 rows += [run(dict(operation=op,exists=exists,noObject=noObject,areaType=kind)) for op,exists,noObject,kind in itertools.product(['point','object'],[False,True],[False,True],[4,5])]
 out=m.root/'backups/animations/native-jump-action-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(output=str(out),rows=len(rows))))
