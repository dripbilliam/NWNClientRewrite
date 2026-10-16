"""Complete original InitializeItemUseEntries1409a71a0, property page1409a6450
and variant creator1409a5fe0. Client item/property/spell/table, icon/string/TLK,
allocator/menu presentation and controlled-class boundaries are captured. Actual
entry slots, physical property/variant payloads, disabling, pages, stack warnings
and scroll learning decisions execute original instructions. No network/GUI claim.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
context,item,props,base,app,rules,actor,stats,classes,menu=[m.heap+n*0x1000 for n in range(1,11)]
spells=m.heap+0x20000
q,si,wi,wq,finish=[getattr(m,n) for n in ['q','si','wi','wq','finish']]
def string(ptr):
 out=b''
 while ptr and len(out)<512:
  b=bytes(u.mem_read(ptr+len(out),1))
  if b==b'\0':break
  out+=b
 return out.decode('ascii')
def strval(ptr):return string(q(ptr))
def alloc(n):
 global allocation
 ptr=allocation;allocation+=(n+15)&~15;assert allocation<m.heap+0xff000;return ptr
def setstr(ptr,text):
 value=text.encode('ascii');buf=alloc(len(value)+1);u.mem_write(buf,value+b'\0');wq(ptr,buf);wi(ptr+8,len(value));wi(ptr+12,len(value)+1)
def getspell(id):return spells+id*0x200 if 100<=id<116 or 201<=id<209 else 0
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14029ca00:finish(0 if c.get('missingBase') else base)
 elif a==0x1406abc80:finish(0 if c.get('missingItem') else item)
 elif a==0x14083d580:
  index=y&0xffffffff;finish(props+index*48 if index<len(properties) else 0)
 elif a==0x14083d6d0:finish(100+(y&0xffff))
 elif a==0x1401a7010:
  col=strval(z);wi(w,(100 if col=='SpellIndex' else 10000)+(y&65535));finish(1)
 elif a==0x1402af4a0:
  id=y&0xffffffff;finish(0 if id in c.get('missingSpells',[]) else getspell(id))
 elif a==0x1402af850:finish(201+(y&255))
 elif a==0x140c10324:finish(alloc(x))
 elif a==0x140c10368:finish(alloc(x))
 elif a==0x140c10370:finish()
 elif a==0x140c10410:finish(u.reg_read(UC_X86_REG_RAX))
 elif a==0x1401f7950:finish(menu)
 elif a==0x1409aaf70:
  name=string(y);icons[x]={'icon':name,'uses':None};finish(0 if name in c.get('missingIcons',[]) else x)
 elif a==0x1401e4720:icons[x]['uses']=strval(y);finish()
 elif a==0x140198c60:setstr(z,f'#{y&0xffffffff}');finish()
 elif a==0x14003d8c0:setstr(x,string(y)[:z]);finish(x)
 elif a==0x14016ab00:setstr(y,strval(x)+strval(z));finish(y)
 elif a==0x14016c810:setstr(x,str(y&65535));finish(x)
 elif a in [0x1401fa170,0x1401fa250,0x1401fa950,0x1401faa40]:
  callback=q(rsp+0x30);payload=q(rsp+0x38);name=icons[z]['icon'] if z in icons else string(z);badge=icons[z]['uses'] if z in icons else None
  kind='more' if callback==0x1409a6450 else 'variants' if callback==0x1409a5fe0 else 'learn' if callback==0x1409a81e0 else 'use'
  row=dict(slot=y&0xffffffff,kind=kind,icon=name,uses=badge,label=f'#{w&0xffffffff}' if a==0x1401faa40 else string(w),payload=payload&0xffffffff,disabled=False)
  entries[row['slot']]=row;finish()
 elif a==0x1401f8b30:entries[y&0xffffffff]['disabled']=True;finish()
 elif a==0x140115890:warnings.append('Stackable items are only allowed to have single or infinite use properties on them.');finish()
 elif a==0x1406ac1a0:finish(actor if c.get('actor',True) else 0)
 elif a==0x1407f0f60:finish(1)
 elif not any(lo<=a<hi for lo,hi in [(0x1409a71a0,0x1409a7ee0),(0x1409a6450,0x1409a6a55),(0x1409a5fe0,0x1409a6449),(0x1409a6a60,0x1409a6a74)]):raise AssertionError(f'Uncaptured item menu dependency {a:x} {kind} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,which):
 global c,kind,allocation,icons,entries,properties,warnings
 c=case;kind=which;allocation=m.heap+0x70000;icons={};entries={};warnings=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));wq(0x1412df970,app);wq(app,app);wq(0x1412df8f8,rules);wq(rules+0x20,rules);wq(rules+0x130,rules);wq(rules+0x148,rules);wq(rules+0xd0,rules);wq(rules+0x110,classes)
 wq(0x1412df968,app);wq(context+0x800,actor if c.get('assignment') else 0);wi(context+0x7f8,55);wi(item+0x40,c.get('baseItem',50));u.mem_write(base+0x24,struct.pack('<H',c.get('stacking',1)));wq(actor+0x3b0,stats);u.mem_write(stats+0x69,b'\1');wi(classes+0x530+0x4fc,c.get('learn',0))
 properties=c.get('properties',[dict(type=15,costValue=c.get('cost',1),remaining=c.get('remaining',1),subtype=i) for i in range(c.get('count',1))]);wi(item+0x1f4,len(properties))
 for i,p in enumerate(properties):u.mem_write(props+i*48,struct.pack('<HHHH',p['type'],p.get('subtype',i),0,p['costValue']));wi(props+i*48+12,p['remaining'])
 for i in range(8):u.mem_write(item+0x26c+i*2,struct.pack('<H',c.get('cachedUses',33)+i))
 for id in [*range(100,116),*range(201,209)]:
  ptr=getspell(id);wi(ptr+0x10,id);u.mem_write(ptr+0x18,f'icon{id}'.encode()+b'\0');u.mem_write(ptr+0x170,bytes([c.get('variants',0) if id==100 else 0]))
 rsp=m.stack+0x1fc08;wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,context);u.reg_write(UC_X86_REG_RDX,item if which=='root' else c.get('start',0) if which=='page' else c.get('index',0))
 try:u.emu_start({'root':0x1409a71a0,'page':0x1409a6450,'variants':0x1409a5fe0}[which],m.stop,count=100000)
 except Exception as error:raise AssertionError(f'Item menu {which} {c} RIP{u.reg_read(UC_X86_REG_RIP):x} RAX{u.reg_read(UC_X86_REG_RAX):x} RCX{u.reg_read(UC_X86_REG_RCX):x}') from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,entries=list(entries.values()),warnings=warnings)
rootcases=[dict(baseItem=b,count=count,cost=cost,remaining=ready,assignment=assignment,variants=variants) for b,count,cost,ready,assignment,variants in itertools.product([49,50,54,75,104],[0,1,2,3,4,10],[1,2,7,13],[0,1],[False,True],[0,2])]
rootcases += [dict(stacking=20,count=count,cost=cost) for count,cost in itertools.product([1,2,4],[1,2,7,13])]
rootcases += [dict(properties=[dict(type=t,costValue=1,remaining=0,subtype=i) for i,t in enumerate(types)]) for types in [[70],[55],[80],[1],[1,15,1,15,15,1,15],[15,1,15,15,15]]]
rootcases += [dict(baseItem=75,learn=learn,actor=actor) for learn,actor in itertools.product([0,1],[False,True])]+[dict(missingBase=True),dict(missingIcons=['icon100']),dict(count=3,missingSpells=[101]),dict(variants=2,missingSpells=[201])]
pages=[dict(count=count,start=start,cost=cost,assignment=assignment,remaining=ready,variants=2) for count,start,cost,assignment,ready in itertools.product([1,8,10,12],[0,1,2,7],[2,7],[False,True],[0,1])]
variants=[dict(count=1,index=index,variants=n,baseItem=base,assignment=assignment,cost=cost,remaining=ready) for index,n,base,assignment,cost,ready in itertools.product([0,1],[0,1,3],[49,50],[False,True],[2,7],[0,1])]
out=m.root/'backups/animations/native-item-radial-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,root=[run(c,'root') for c in rootcases],pages=[run(c,'page') for c in pages],variants=[run(c,'variants') for c in variants]))+'\n');print(json.dumps(dict(root=len(rootcases),pages=len(pages),variants=len(variants),output=str(out))))
