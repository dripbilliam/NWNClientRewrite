"""Original BroadcastSpellData48f550 and ordinary SpellCastAndImpact49c4b0,
including release message construction and projectile dispatch/suppression.
Registry/virtual casts, DM, visibility/client/list lookups, message storage,
inventory membership, transport, projectile broadcast and scheduler are captured
boundaries. Does not execute native client receivers/renderer/transport or scripts.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,viewer,viewer2,owner,associate,item,container,area,app,spell,rules,vt,areaIds,point,stats,node,client,client2,allocated,message=[m.heap+n*0x2000 for n in range(1,21)]
objects={99:actor,100:viewer,101:viewer2,102:owner,103:associate};items={200:item,201:container}
def snapshot(data):return json.loads(json.dumps(messages.get(data,{'objects':{},'integers':{}})))
def hook(u,a,n,_):
 global allocation
 if a==m.stop or a in [0x14037abcc,0x14037a457]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(actor if c.get('actorType',5)==5 else 0)
 elif a==m.stop+0x20:m.finish(area if c.get('areaCast',True) else 0)
 elif a==0x14055b850:m.finish(app)
 elif a==0x140296470:calls.append(['object',y&0xffffffff]);m.wq(z,area if c.get('areaObject',True) else 0);m.finish(0)
 elif a==0x14055b3d0:
  oid=y&0xffffffff;calls.append(['creature',oid]);m.finish(0 if (oid==99 and c.get('actorType',5)!=5) or (oid==103 and not c.get('targetExists',True)) else objects.get(oid,0))
 elif a==0x14055b6c0:
  oid=y&0xffffffff;calls.append(['item',oid]);m.finish(0 if (oid==200 and c.get('itemMissing',False)) else items.get(oid,0))
 elif a==0x140402f80:
  oid=99+(x-stats)//0x200;calls.append(['dm',oid]);m.finish(c.get('casterDM',0) if oid==99 else c.get('ownerDM',0))
 elif a==0x140494e80:calls.append(['area']);m.finish(area if c.get('area',True) else 0)
 elif a==0x1402da730 or a==0x1402da770:messages.setdefault(x,{'objects':{},'integers':{}})['integers' if a==0x1402da730 else 'objects'][str(y&0xffffffff)]=z&0xffffffff;m.finish()
 elif a==0x1402d57f0:m.finish(messages[x]['objects'].get(str(y&0xffffffff),0x7f000000))
 elif a==0x1403d5850:calls.append(['node',m.si(x+8)&0xffffffff,y&0xffffffff]);m.finish(node if c.get('visibility',1) is not None else 0)
 elif a==0x14055b390:calls.append(['client',y&0xffffffff]);m.finish((client if y==100 else client2) if c.get('clients',True) else 0)
 elif a==0x140175070:calls.append(['identified',y&0xffffffff]);m.finish(c.get('identified',1))
 elif a==0x1403d0db0:calls.append(['selfNode',y&0xffffffff,z,w,int.from_bytes(u.mem_read(rsp+0x28,1),'little'),m.si(rsp+0x30)]);m.finish()
 elif a==0x14055b810:m.finish(app)
 elif a==0x1404cf090:calls.append(['send',y-401,z&255,snapshot(w)]);m.finish(0)
 elif a==0x1402af4a0:m.finish(spell)
 elif a==0x140c10324:allocation+=1;m.finish(allocated+allocation*0x100)
 elif a in [0x140c10370,0x14037bd50,0x14003d8c0]:m.finish()
 elif a==0x14048f550 and c['mode']!='broadcast':calls.append(['broadcast',snapshot(z)]);m.finish()
 elif a==0x14022b180:
  for i in range(3):m.wf(x+i*4,m.rf(x+i*4)+m.rf(y+i*4))
  m.finish(x)
 elif a==0x140462b40:calls.append(['equipped',200]);m.finish(c.get('equipped',0))
 elif a==0x140468bd0:calls.append(['repository',200,z]);m.finish(c.get('repository',0))
 elif a==0x14048f270:
  calls.append(['projectile',dict(sourceId=y&0xffffffff,targetId=z&0xffffffff,from_=list(struct.unpack('<3f',u.mem_read(w,12))),to=list(struct.unpack('<3f',u.mem_read(m.q(rsp+0x28),12))),duration=m.si(rsp+0x30)&0xffffffff,appearance=int.from_bytes(u.mem_read(rsp+0x38,1),'little'),flags=m.si(rsp+0x40),result=int.from_bytes(u.mem_read(rsp+0x48,1),'little'),deflection=int.from_bytes(u.mem_read(rsp+0x50,1),'little'))]);m.finish()
 elif a==0x14055b960:m.finish(app)
 elif a==0x1405570b0:
  ptr=m.q(rsp+0x38);calls.append(['event',dict(spellId=m.si(ptr),featId=int.from_bytes(u.mem_read(ptr+4,2),'little'),casterId=m.si(ptr+8)&0xffffffff,targetId=m.si(ptr+12)&0xffffffff,itemId=m.si(ptr+16)&0xffffffff,position=list(struct.unpack('<3f',u.mem_read(ptr+20,12))),areaId=m.si(ptr+48)&0xffffffff)]);m.finish()
 elif not (0x14048f550<=a<0x14048f8b5 or 0x14049c4b0<=a<0x14049ca5c or 0x14037abb1<=a<0x14037abcc or 0x14037a449<=a<0x14037a457):raise AssertionError(f'Uncaptured spell release presentation dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,messages,allocation
 c=case;calls=[];messages={};allocation=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,spell)
 for oid,ptr in objects.items():m.wi(ptr+8,oid);m.wq(ptr,vt);m.wq(ptr+0xad0,stats+(oid-99)*0x200);u.mem_write(ptr+0xa4,struct.pack('<3f',*(c.get('position',[30,0,0]) if oid in [100,101] else [1,2,3])));m.wi(ptr+0x8fc,c.get('master',99))
 u.mem_write(actor+0xa4,struct.pack('<3f',0,0,0));u.mem_write(actor+0xb0,struct.pack('<3f',1.25,-.5,2));u.mem_write(actor+0x208,struct.pack('<3f',7,8,9));m.wi(actor+0xa0,88);m.wi(actor+0xd8,c.get('animation',0));m.wi(actor+0x220,150);m.wi(actor+0x224,0);u.mem_write(actor+0x23c,struct.pack('<H',65535))
 m.wq(vt+0x50,m.stop+0x20);m.wq(vt+0x60,m.stop+0x10);m.wq(area,vt);m.wi(area+0x140,88);m.wq(area+0x228,areaIds);ids=c.get('ids',[100,999,101]);m.wi(area+0x230,len(ids))
 for i,oid in enumerate(ids):m.wi(areaIds+i*4,oid)
 u.mem_write(node+4,bytes([c.get('visibility',1) or 0]));m.wi(client+0x48,501);m.wi(client2+0x48,502)
 for oid,ptr in items.items():m.wi(ptr+8,oid);m.wi(ptr+0x40,c.get('base',24));m.wi(ptr+0x3c8,c.get('owner',99) if oid==200 else c.get('containerOwner',99))
 m.wi(spell+0x19c,c.get('hasProjectile',1));u.mem_write(point,struct.pack('<3f',1.25,-2,3));messages[message]={'objects':{'0':99,'1':c.get('item',0x7f000000)},'integers':{'0':1,'1':11,'2':12,'3':13}}
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x500,bytes(0x600));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c['mode'] in ['ctorSelf','ctorCache']:
  regs=[actor,0,0,0];start=0x14037abb1 if c['mode']=='ctorSelf' else 0x14037a449
  for reg,v in zip([UC_X86_REG_R14,UC_X86_REG_R12,UC_X86_REG_RSI,UC_X86_REG_RBX],[actor,1,0,0]):u.reg_write(reg,v)
  u.mem_write(actor+0x808,bytes([0xa5])*16)
 elif c['mode']=='broadcast':regs=[actor,spell,message,0];start=0x14048f550
 else:
  regs=[actor,1,point,c.get('target',103)];start=0x14049c4b0
  for off,value in [(0x28,0),(0x30,c.get('item',0x7f000000)),(0x38,0),(0x40,0),(0x48,c.get('path',0)),(0x50,c.get('instant',0))]:m.wi(rsp+off,value)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,value)
 u.emu_start(start,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x14037abcc,0x14037a457]
 return dict(case=c,calls=calls,message=snapshot(message),impact=m.si(actor+0x224),identifiedStorage=bytes(u.mem_read(actor+0x808,16)).hex())

rows=[run(dict(mode='broadcast',visibility=vis,position=pos,clients=clients,identified=identified,item=itemId,owner=ownerId))for vis,pos,clients,identified,itemId,ownerId in itertools.product([None,0,1,2,3,255],[[0,0,0],[30,0,0],[30.000001907348633,0,0],[3,4,29.5]],[False,True],[0,1,2],[0x7f000000,200,299],[99,102,103,201,999])]
rows += [run(dict(mode='broadcast',actorType=kind,areaObject=obj,areaCast=cast,casterDM=dm,ownerDM=ownerDM,item=200,owner=102))for kind,obj,cast,dm,ownerDM in itertools.product([5,9],[False,True],[False,True],[0,1],[0,1])]
rows += [run(dict(mode='release',actorType=kind,animation=animation,target=targetId,base=base,master=master,equipped=equipped,repository=repo,path=path,instant=instant,item=200))for kind,animation,targetId,base,master,equipped,repo,path,instant in itertools.product([5,9],[0,10],[103,200,0x7f000000],[24,49,104],[99,102],[0,1],[0,1],[0,1,256],[0,1])]
rows += [run(dict(mode=mode))for mode in ['ctorSelf','ctorCache']]
out=m.root/'backups/animations/native-spell-release-presentation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
