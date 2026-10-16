"""Read-only original collector14098f550/class page14098fbf0/leaf1409957a0,
variant creator140991230 and selection140998520. Metadata, ownership/remaining,
allocation/string/icon/menu presentation and outbound target/input calls are
captured boundaries. No native GUI rendering, packets or server simulation.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
context,actor,stats,rules,manager,vector,classbase,classrows,featbase,spellbase,domains,childids=[m.heap+n for n in [0x1000,0x2000,0x3000,0x4000,0x5000,0x6000,0x10000,0x20000,0x30000,0x40000,0x50000,0x60000]]
ranges=[(0x14098f550,0x14098f7bc),(0x14098fbf0,0x1409904ae),(0x1409957a0,0x140995f0b),(0x140991230,0x1409914a2),(0x140998520,0x1409987c9),(0x1402af850,0x1402af8c2)]
def alloc(size):
 global allocation
 ptr=m.heap+0x70000+allocation;allocation+=(size+31)&~15;assert allocation<0x80000;return ptr
def cstring(ptr):
 if not ptr:return ''
 return bytes(u.mem_read(ptr,100)).split(b'\0')[0].decode('ascii')
def ref(ptr,value):u.mem_write(ptr,value.encode().ljust(17,b'\0')[:17])
def featptr(id):
 id&=65535
 if id in c.get('missingFeats',[]):return 0
 key=str(id);info=c.get('feats',{}).get(key,{})
 if id not in featmap:featmap[id]=featbase+len(featmap)*0x100
 ptr=featmap[id];m.wi(ptr,id+1000);ref(ptr+0x10,'');m.wi(ptr+0x2c,info.get('targetSelf',c.get('targetSelf',0)));m.wi(ptr+0x54,info.get('successor',-1));m.wi(ptr+0x60,info.get('spellId',c.get('spellId',10)));return ptr
def spellptr(id):
 id=id if id<0x80000000 else id-0x100000000
 if id<0 or id in c.get('missingSpells',[]):return 0
 if id not in spellmap:spellmap[id]=spellbase+len(spellmap)*0x200
 ptr=spellmap[id];m.wi(ptr+0x10,id+2000);ref(ptr+0x18,f'spell{id}');m.wi(ptr+0x198,c.get('childFeats',{}).get(str(id),id)<<16)
 if id==10:
  children=c.get('children',[]);m.wq(ptr+0x168,childids);u.mem_write(ptr+0x170,bytes([len(children)&255]))
  for n,value in enumerate(children):m.wi(childids+n*4,value)
 return ptr
def entry(slot,**value):entries.append(dict(slot=slot&0xffffffff,**value))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1406ac1a0:m.finish(actor if c.get('controlled',True) else 0)
 elif a==0x1406ac1c0:m.finish(99)
 elif a==0x1406abf90:m.finish(0)
 elif a==0x1406ab9e0:m.finish(m.heap+0x61000 if c.get('familiar') else 0)
 elif a==0x1407f0f60:m.finish(c.get('classes',[3])[y&255])
 elif a in [0x1407f3cc0,0x1407f3d30]:m.finish(c.get('classDomains',[0,1])[int(a==0x1407f3d30)])
 elif a==0x1402a3ba0:
  index=y&65535;d=c.get('domains',[None,None])[index] if index<2 else None
  if d is not None:ptr=domains+index*0x50;m.wi(ptr+0x4c,d.get('castable',0));u.mem_write(ptr+0x44,struct.pack('<H',d.get('featId',257)&65535));m.finish(ptr)
  else:m.finish(0)
 elif a==0x1402997f0:
  type=(x-classbase)//0x530;values=c.get('classFeats',{}).get(str(type),[]);index=y&65535
  m.finish(classrows+type*0x400+index*16 if index<len(values) and values[index] is not None else 0)
 elif a==0x140296910:m.finish(int(y&65535 in c.get('bonus',[]) if x==stats+0x128 else y&65535 in c.get('owned',[257])))
 elif a==0x140998960:m.finish(int(len(c.get('classes',[3]))>3 or c.get('grouped',False)))
 elif a==0x1402a3bd0:m.finish(featptr(y))
 elif a==0x1402af4a0:m.finish(spellptr(y&0xffffffff))
 elif a==0x1407f3df0:m.finish(c.get('remaining',5))
 elif a==0x14098de60:
  if not m.q(x):m.wq(x,alloc(2048));m.wq(x+8,m.q(x));m.wq(x+16,m.q(x)+2048)
  end=m.q(x+8);u.mem_write(end,bytes(u.mem_read(z,8)));m.wq(x+8,end+8);m.finish()
 elif a==0x140c4f038:
  ptr=alloc(y)
  if x:u.mem_write(ptr,bytes(u.mem_read(x,min(y,1024))))
  m.finish(ptr)
 elif a in [0x140c10324,0x140c10368]:m.finish(alloc(x))
 elif a in [0x1401f7950,0x140702800]:m.finish(x)
 elif a in [0x14018dea0,0x14018ded0]:ref(x,cstring(m.q(y)) if a==0x14018dea0 else cstring(y));m.finish(x)
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif a==0x1401e2f00:icons[x]=cstring(y);m.finish(x)
 elif a==0x14016c810:texts[x]=y&0xffffffff;m.finish(x)
 elif a==0x1401e4720:counts[x]=texts.get(y);m.finish()
 elif a==0x1401994d0:
  ptr=alloc(32);ref(ptr,f'label{z&0xffffffff}');m.wq(y,ptr);m.finish(y)
 elif a==0x1401fa170:
  packed=m.q(rsp+0x38)&0xffffffff;entry(y,featId=packed&65535,auxiliary=packed>>16,labelRef=int(cstring(w)[5:]),icon=icons[z],uses=counts.get(z),disabled=False,action='associate.possessFamiliar' if m.q(rsp+0x30)==0x1409980c0 else 'feat.use');m.finish()
 elif a in [0x1401fa010,0x1401fa3a0]:
  packed=m.q(rsp+0x38)&0xffffffff;entry(y,featId=packed&65535,auxiliary=packed>>16,labelRef=w&0xffffffff,icon=icons.get(z,cstring(z)),uses=counts.get(z),disabled=False,action='feat.use');m.finish()
 elif a==0x1401faa40:
  packed=m.q(rsp+0x38)&0xffffffff
  if kind=='leaf':entry(y,featId=packed&65535,auxiliary=packed>>16,submenu=True)
  else:entry(y,next=packed>>3,classIndex=packed&7)
  m.finish()
 elif a==0x1409957a0 and kind=='page':entry(w,featId=y&65535,classIndex=int.from_bytes(u.mem_read(rsp+0x30,1),'little'));m.finish()
 elif a==0x1401f8b30:next(e for e in reversed(entries) if e['slot']==y)['disabled']=True;m.finish()
 elif a==0x140115890:warnings.append('invalid');m.finish()
 elif a==0x140867070:calls.append(dict(mode='assign',packed=y&0xffffffff));m.finish()
 elif a==0x1408055c0:calls.append(dict(mode='mode',modeId=y&255));m.finish()
 elif a==0x140805310:calls.append(dict(mode='use',featId=y&65535,auxiliary=(y>>16)&65535));m.finish()
 elif a==0x140702c30:calls.append(dict(mode='target',featId=z&65535,auxiliary=(z>>16)&65535));m.finish()
 elif a in [0x140c10370,0x140c4f024]:m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured feat radial dependency {a:x} kind={kind} case={c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,owner):
 global c,kind,allocation,featmap,spellmap,entries,calls,icons,texts,counts,warnings
 c=case;kind=owner;allocation=0;featmap={};spellmap={};entries=[];calls=[];icons={};texts={};counts={};warnings=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,manager);m.wq(manager,manager);m.wq(0x1412df8f8,rules);m.wq(rules+0xd0,rules);m.wq(rules+0x110,classbase);m.wq(actor+0x3b0,stats);m.wi(actor+8,99);m.wq(context+0x828,1 if c.get('assignment') else 0);m.wi(context+0x7f8,99 if c.get('self',True) else c.get('targetId',100));m.wi(actor+0x268,c.get('defensiveStance',0));m.wi(m.heap+0x61008,(c.get('familiar') or {}).get('id',101))
 classes=c.get('classes',[3]);u.mem_write(stats+0x69,bytes([len(classes)&255]))
 for type in classes:
  values=c.get('classFeats',{}).get(str(type),[]);u.mem_write(classbase+type*0x530+0x2b8,struct.pack('<H',len(values)))
  for index,value in enumerate(values):
   if value:ptr=classrows+type*0x400+index*16;u.mem_write(ptr,struct.pack('<H',value['id']&65535));m.wi(ptr+12,value.get('onMenu',1))
 rsp=m.stack+0x1fc08;m.wq(rsp,m.stop);m.wq(rsp+0x28,m.heap+0x62000);m.wq(rsp+0x30,255);m.wq(m.heap+0x62000,0x140998520)
 u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,context);u.reg_write(UC_X86_REG_RDX,vector if owner=='collector' else ((c.get('start',0)&65535)<<3)|(c.get('index',0)&7) if owner=='page' else c.get('packed',257));u.reg_write(UC_X86_REG_R8,m.heap+0x63000);u.reg_write(UC_X86_REG_R9,2)
 addr={'collector':0x14098f550,'page':0x14098fbf0,'leaf':0x1409957a0,'variants':0x140991230,'selection':0x140998520}[owner]
 u.emu_start(addr,m.stop,count=500000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 if owner=='collector':
  for ptr in range(m.q(vector),m.q(vector+8),8):entries.append(dict(group=m.si(ptr),classIndex=int.from_bytes(u.mem_read(ptr+4,1),'little'),firstFeat=int.from_bytes(u.mem_read(ptr+6,2),'little')))
 if owner=='page':
  for e in entries:
   if 'labelRef' in e:
    e['domain']=True
    for key in ['auxiliary','labelRef','icon','action']:e.pop(key,None)
 return dict(case=c,entries=entries,calls=calls,warnings=warnings)
rows={}
lists=[[],[dict(id=257)],[dict(id=257),dict(id=258)],[dict(id=1089)],[dict(id=257,onMenu=2),dict(id=258)], [dict(id=257),None,dict(id=258)],[dict(id=65535),dict(id=257)], [dict(id=0),dict(id=257)], [dict(id=i+250) for i in range(20)]]
cases=[dict(classes=classes,classFeats={str(t):values for t in classes},owned=owned,bonus=bonus,grouped=g) for classes,values,owned,bonus,g in itertools.product([[3],[2],[3,2,4,5]],lists,[[],[257],[257,258,1089],list(range(250,270))],[[],[258]],[False,True])]
cases+=[dict(classes=[2],classFeats={'2':values},domains=d,owned=[257,258],grouped=g) for values,d,g in itertools.product(lists,[[None,None],[dict(castable=1,featId=257),None],[dict(castable=0),dict(castable=-1,featId=258)]],[False,True])]
rows['collector']=[run(c,'collector') for c in cases]
pagecases=[dict(classes=[type],classFeats={str(type):values},owned=owned,start=start,grouped=g,domains=domains) for type,values,owned,start,g,domains in itertools.product([2,3],lists,[[],[257,258,1089],list(range(250,270))],[0,1,7,8,14],[False,True],[[None,None],[dict(castable=1,featId=257),dict(castable=1,featId=258)]])]
pagecases += [dict(classFeats={'3':[dict(id=257),dict(id=258),dict(id=260)]},owned=owned,feats={'257':dict(successor=258),'258':dict(successor=259),'260':dict(successor=0)},start=0) for owned in [[257,258],[257,259],[257,258,259,260]]]
rows['page']=[run(c,'page') for c in pagecases]
leafcases=[dict(packed=id|(aux<<16),owned=[id],remaining=uses,targetSelf=self,self=target,assignment=assign,children=children) for id,aux,uses,self,target,assign,children in itertools.product([257,5,303,947],[0,65000,65001],[0,5,100,255],[0,1,-1],[False,True],[False,True],[[],[11,12]])]
leafcases += [dict(packed=id,owned=owned,feats={'257':dict(successor=258),'258':dict(successor=259)},defensiveStance=stance,familiar=familiar,self=False,targetId=target) for id,owned,stance,familiar,target in itertools.product([257,303,947],[[257],[257,259],[257,258,259],[303,947]],[0,1],[None,dict(id=101)],[100,101])]
leafcases += [dict(packed=257,missingFeats=[257]),dict(packed=257,controlled=False)]
leafcases += [dict(packed=257|(aux<<16),owned=[257,258],feats={'257':dict(successor=next)},children=children) for next,aux,children in itertools.product([65536+258,0x7fff0102,-2147483390],[0,2,65000],[[],[11,12]])]
rows['leaf']=[run(c,'leaf') for c in leafcases]
rows['variants']=[run(dict(children=children,remaining=uses,targetSelf=self,self=target,assignment=assign,missingSpells=missing,childFeats={'11':65000,'12':65535}),'variants') for children,uses,self,target,assign,missing in itertools.product([[],[11,12],[11,12,13]],[0,5,100],[0,1,-1],[False,True],[False,True],[[],[12]])]
rows['selection']=[run(dict(packed=id|(aux<<16),targetSelf=self,self=target,assignment=assign),'selection') for id,aux,self,target,assign in itertools.product([28,19,30,204,899,866,389,390,425,947,257,5,1072,1073],[0,1,65000],[0,1,-1],[False,True],[False,True])]
out=m.root/'backups/animations/native-feat-radial-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,**rows))+'\n');print(json.dumps(dict(counts={k:len(v) for k,v in rows.items()},output=str(out))))
