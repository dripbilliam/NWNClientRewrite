"""Original item button140867760, count14086bef0, client wield1407fdb10 and
relative size1408012d0. Registry/base/spell/property/2DA lookups, cached eligibility,
GUI clear/icon allocation/destruction/text/enable/animation/notification are captured
boundaries. No original GUI allocation/layout, sound, network or campaign claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
button,actor,other,app,rules,stats,appearance,vt,manager=[m.heap+n*0x1000 for n in range(1,10)]
items=[m.heap+0x10000+n*0x3000 for n in range(2)];bases=[v+0x1000 for v in items];props=[v+0x2000 for v in items];spells=m.heap+0x30000;temp=m.heap+0x40000
q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
def string(ptr):
 out=b''
 while ptr and len(out)<512:
  b=bytes(u.mem_read(ptr+len(out),1))
  if b==b'\0':break
  out+=b
 return out.decode('ascii')
def setstr(ptr,text):
 global allocation
 b=text.encode();buf=allocation;allocation+=len(b)+1;u.mem_write(buf,b+b'\0');wq(ptr,buf);wi(ptr+8,len(b));wi(ptr+12,len(b)+1)
def itemindex(ptr):return items.index(ptr)
def itemid(ptr):return si(ptr+8)&0xffffffff
def getspell(id):return spells+(id-100)*0x200 if 100<=id<116 and id not in c.get('missingSpells',[]) else 0
def icon(ptr):return icons.get(ptr,'null' if ptr==0 else f'unknown{ptr:x}')
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406ac1a0:finish(0 if c.get('missingActor') else actor)
 elif a==0x1406ac1c0:finish(10)
 elif a==0x1406abc80:finish(next((ptr for ptr in items if itemid(ptr)==(y&0xffffffff) and itemid(ptr) not in c.get('missingItems',[])),0))
 elif a==0x14029ca00:finish(next((bases[i] for i,ptr in enumerate(items) if si(ptr+0x40)==(y&0xffffffff) and not records[i].get('missingBase')),0))
 elif a==0x14083d6d0:
  i=itemindex(x);index=y&0xffffffff;p=records[i]['properties'];finish(100+index if index<len(p) and p[index]['type']==15 else -1)
 elif a==0x14083d580:
  i=itemindex(x);index=y&0xffffffff;finish(props[i]+index*48 if index<len(records[i]['properties']) else 0)
 elif a==0x1402af4a0:finish(getspell(y&0xffffffff))
 elif a==0x1402af850:finish(110+(y&255) if (y&255)<c.get('variants',0) else -1)
 elif a==0x1401a7010:assert string(q(z))=='SIZECATEGORY';wi(w,c.get('size',3));finish(c.get('sizeStatus',1))
 elif a in [0x140c10324,0x140c10368]:ptr=allocation;allocation+=(x+15)&~15;finish(ptr)
 elif a==0x140c10370:finish()
 elif a==0x140c10410:finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x14085fb50:
  calls.append(['clear']);u.mem_write(button+0x140,b'\0');wi(button+0xec,0x7f000000);wi(button+0x118,0);wq(button+0x130,0);finish()
 elif a==0x1401e2f60:icons[x]=string(y);calls.append(['createSpellIcon',icons[x]]);finish(x)
 elif a==0x1401e3140:calls.append(['releaseSpellIcon',icon(x)]);finish()
 elif a==0x14086baa0:calls.append(['icons',icon(y),icon(z)]);wq(button+0x130,temp);icons[temp]='copiedIcon';finish()
 elif a==0x14083d7e0:finish(actor if si(x+0x25c)==10 else other if si(x+0x25c)==11 else 0)
 elif a==0x1401e5a00:calls.append(['animation',string(y) if y else None]);finish()
 elif a==0x1406abbc0:finish(manager)
 elif a==0x1408602a0:calls.append(['notify']);finish()
 elif a==0x1406aaf90:calls.append(['feedback',y&0xffffffff]);finish()
 elif a==0x14086b710:calls.append(['text',string(q(y))]);finish()
 elif a==0x14016c810:setstr(x,str(y&65535));finish(x)
 elif a==m.stop+0x100:calls.append(['enable',y&0xffffffff]);finish()
 elif a==m.stop+0x110:calls.append(['destroyIcon']);wq(button+0x130,0);finish()
 elif a==0x14086bef0:
  if kind=='config':calls.append(['refreshCount'])
 elif not any(lo<=a<hi for lo,hi in [(0x140867760,0x140867d02),(0x14086bef0,0x14086c100),(0x1407fdb10,0x1407fdc98),(0x1408012d0,0x1408013d0)]):raise AssertionError(f'Uncaptured quickbar dependency {a:x} {kind} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,which='config'):
 global c,kind,calls,allocation,icons,records
 c=case;kind=which;calls=[];allocation=m.heap+0x60000;icons={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 wq(0x1412df970,app);wq(app,app);wq(0x1412df8f8,rules);wq(rules+0x20,rules);wq(rules+0xd0,rules);wq(rules+0x130,rules);wq(rules+0x100,appearance);wq(actor+0x300,stats);wi(actor+8,10);wi(other+8,11);wq(manager+0x60,manager)
 records=[dict(baseItem=50,identified=1,canUse=1,container=0,equipableSlots=0,qbBehaviour=1,stacking=1,weaponType=0,weaponWield=0,weaponSize=3,stackSize=3,owner=0x7f000000,properties=[dict(type=15,costValue=2)])|c.get('item',{}),dict(baseItem=51,identified=1,canUse=1,container=0,equipableSlots=16,qbBehaviour=0,stacking=1,weaponType=1,weaponWield=0,weaponSize=3,stackSize=1,owner=0x7f000000,properties=[])|c.get('old',{})]
 for i,d in enumerate(records):
  ptr=items[i];base=bases[i];wi(ptr+8,20+i);wi(ptr+0x40,d['baseItem']);wi(ptr+0x1c0,d['identified']);wi(ptr+0x288,d['canUse']);wi(ptr+0x1f4,len(d['properties']));wi(ptr+0x284,d['stackSize']);wi(ptr+0x25c,d['owner']);wi(base+4,d['equipableSlots']);wi(base+0x80,d['container']);u.mem_write(base+0xad,bytes([d['qbBehaviour']&255]));u.mem_write(base+0x24,struct.pack('<H',d['stacking']&65535))
  for off,k in [(9,'weaponType'),(0x18,'weaponWield'),(0x19,'weaponSize')]:u.mem_write(base+off,bytes([d[k]&255]))
  for n,p in enumerate(d['properties']):u.mem_write(props[i]+n*48,struct.pack('<HHHH',p['type'],n,0,p['costValue']))
  for n in range(8):u.mem_write(ptr+0x26c+n*2,struct.pack('<H',(c.get('cachedUses',33)+n)&65535))
  ptrIcon=ptr+0x900;wq(ptr+0x238,ptrIcon);icons[ptrIcon]=f'item{20+i}'
 for id in range(100,116):
  ptr=spells+(id-100)*0x200;u.mem_write(ptr+0x18,f'icon{id}'.encode()+b'\0');u.mem_write(ptr+0x170,bytes([c.get('variants',0) if id==100 else 0]))
 initial=dict(type=0,itemId=21,secondaryItemId=0x7f000000,intParam=0xff00ff)|c.get('button',{});u.mem_write(button+0x140,bytes([initial['type']]));wi(button+0xec,initial['itemId']);wi(button+0xf0,initial['secondaryItemId']);wi(button+0x118,initial['intParam']);wq(button,vt);wq(vt+0x100,m.stop+0x100)
 if c.get('oldIcon'):wq(button+0x130,temp);wq(temp,vt+0x200);wq(vt+0x200,m.stop+0x110);icons[temp]='oldIcon'
 rsp=m.stack+0x1fc08;wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 args=[button,c.get('id',20),c.get('packed',0xff00ff),c.get('force',0)] if which=='config' else [actor,items[0],0,0] if which in ['wield','size'] else [button,0,0,0]
 if which=='count':wi(button+0xec,20);wi(button+0x118,c.get('packed',0))
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 try:u.emu_start(dict(config=0x140867760,count=0x14086bef0,wield=0x1407fdb10,size=0x1408012d0)[which],m.stop,count=100000)
 except Exception as error:raise AssertionError(f'Quickbar {which} {c} RIP{u.reg_read(UC_X86_REG_RIP):x} calls{calls}') from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&(255 if which=='wield' else 0xffffffff)
 return dict(case=c,calls=calls,button=dict(type=u.mem_read(button+0x140,1)[0],itemId=si(button+0xec)&0xffffffff,secondaryItemId=si(button+0xf0)&0xffffffff,intParam=si(button+0x118)),**(dict(result=result) if which in ['wield','size'] else {}))
config=[dict(item=dict(baseItem=b,qbBehaviour=qb,equipableSlots=slots),packed=packed,variants=v) for b,qb,slots,packed,v in itertools.product([49,50,54,75,104],[0,1,2,3],[0,16],[0xff00ff,0xff0000,0,0x10000,0x100ff,0x1ff], [0,2])]
config += [dict(item=dict(properties=[dict(type=t,costValue=2) for t in types],qbBehaviour=qb),missingSpells=missing) for types,qb,missing in itertools.product([[],[1],[1,15],[15,15],[1,1,15]],[0,1,2], [[],[100],[100,101,102]])]
config += [dict(item=dict(identified=ident,canUse=can),force=force,button=dict(type=2,intParam=17)) for ident,can,force in itertools.product([0,1],[0,1],[0,1])]
config += [dict(missingActor=True),dict(missingItems=[20]),dict(item=dict(missingBase=True)),dict(item=dict(properties=[])),dict(item=dict(properties=[],container=1))]
config += [dict(button=dict(type=1),oldIcon=icon,old=dict(baseItem=oldBase,equipableSlots=oldSlots,weaponWield=oldWield,owner=own),item=dict(baseItem=newBase,equipableSlots=newSlots,weaponType=1,weaponWield=newWield,owner=own)) for oldBase,newBase,oldSlots,newSlots,oldWield,newWield,own,icon in itertools.product([51,14],[50,14],[16,32],[16,32],[0,1],[0,1],[0x7f000000,10,11],[False,True])]
config += [dict(button=dict(type=1),old=dict(missingBase=True)),dict(button=dict(type=1),missingItems=[21]),dict(button=dict(type=1,secondaryItemId=22)),dict(button=dict(type=1,intParam=0x1ff)),dict(button=dict(type=1),id=21)]
counts=[dict(item=dict(properties=[dict(type=t,costValue=cost) for _ in range(10)],stacking=maximum,equipableSlots=slot,stackSize=stack),packed=index,cachedUses=uses) for t,cost,maximum,slot,stack,index,uses in itertools.product([1,15,55,70,80],[1,2,7,13],[1,20],[0,16],[-1,0,3,65536],[0,8,11],[0,33])]
wields=[dict(item=dict(baseItem=b,weaponType=t,weaponWield=w,weaponSize=ws),size=s,sizeStatus=status) for b,t,w,ws,s,status in itertools.product([6,7,8,11,14,15,50,56,57,111],[0,1],[0,1],[1,3,8],[1,3,5],[0,1])]+[dict(item=dict(missingBase=True))]
sizes=[dict(item=dict(baseItem=b,weaponSize=w),size=s,sizeStatus=status) for b,w,s,status in itertools.product([50,111],[0,3,255],[-100,0,3,300],[0,1])]
out=m.root/'backups/animations/native-item-quickbar-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,config=[run(c) for c in config],count=[run(c,'count') for c in counts],wield=[run(c,'wield') for c in wields],size=[run(c,'size') for c in sizes]))+'\n');print(json.dumps(dict(config=len(config),count=len(counts),wield=len(wields),size=len(sizes),output=str(out))))
