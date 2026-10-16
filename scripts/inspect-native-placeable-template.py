"""Full LoadPlaceable1404b4900..1404b6702, original unmodified EE binary.
Typed GFF readers, SetTag/AsTAG, string/localized assignments, table queries,
virtual setters, inventory owners, visual owners, UUID and module tag insertion
are explicit captured boundaries. This validates the caller, not these lowers.
No original game data is copied; fixtures are synthetic.
"""
import importlib.util,itertools,json,struct,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,gffPtr,rootPtr,tagPtr,modulePtr,appPtr,basePtr,rulesPtr,vtablePtr=[m.heap+n*0x1000 for n in range(1,10)]
empty=dict(strRef=0xffffffff,entries=[])
widths={0x3a8:1,0x3b8:1,0x3b0:1,0x3d0:1,0x32c:2,0x370:1,0x4e0:1,0x4e1:1,0x4e2:1,0x3a9:1,0x59c:1}
offsets=[0x3a4,0x350,0xfc,0x3a8,0x3bc,0x3c0,0x3b8,0x3b0,0x3b4,0x3c4,0x3d0,0x3c8,0x3d4,0x3d8,0x3ac,0x510,0x514,0x264,0x5a4,0x5a0,0x32c,0xe4,0xe0,0x370,0x4e0,0x4e1,0x4e2,0x500,0x378,0x4f8,0x3a0,0x3a9,0x59c,0x504,0x368,0x594,0x598,0xcc,0xd0]
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr
def ctext(ptr):return bytes(u.mem_read(ptr,256)).split(b'\0')[0].decode('cp1252') if ptr else ''
def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''
def owning(ptr,text):
 raw=text.encode('cp1252');target=alloc(len(raw)+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)
def loc(ptr,value):
 token=alloc(16);localized[token]=value;m.wq(ptr,token);m.wi(ptr+8,value['strRef'])
def locvalue(ptr):return localized.get(m.q(ptr),empty)
def field(offset):return int.from_bytes(u.mem_read(objectPtr+offset,widths.get(offset,4)),'little',signed=widths.get(offset,4)==4)
def read(kind,key,fallback):
 calls.append(['read',kind,key,fallback]);return c.get('fields',{}).get(key,dict(value=fallback,status=0))
def hook(u,at,n,_):
 global currentRow
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at in [0x140169560,0x1401695b0,0x140169600]:
  if at==0x140169560:loc(x,empty)
  elif at==0x140169600:
   value=locvalue(y);loc(x,value)
   if objectPtr<=x<objectPtr+0x600:calls.append(['localized',x-objectPtr,value])
  m.finish(x);return
 if at in [0x1401a1130,0x1401a0f80,0x1401a12d0]:
  kind={0x1401a1130:'string',0x1401a0f80:'localized',0x1401a12d0:'resref'}[at];fallback=empty if kind=='localized' else '';entry=read(kind,ctext(w),fallback)
  if kind=='localized':loc(y,entry['value'])
  elif kind=='string':owning(y,entry['value'])
  else:u.mem_write(y,entry['value'].encode('cp1252')[:16].ljust(17,b'\0'))
  m.wi(m.q(rsp+0x28),entry['status']);m.finish(y);return
 if at in [0x1401a0f60,0x1401a0ee0,0x1401a1510,0x1401a1770,0x1401a17f0,0x1401a1950]:
  kind={0x1401a0f60:'bool',0x1401a0ee0:'byte',0x1401a1510:'dword',0x1401a1770:'int',0x1401a17f0:'short',0x1401a1950:'word'}[at];width=1 if kind in ['byte','bool'] else 2 if kind in ['short','word'] else 4
  fallback=int.from_bytes(u.mem_read(rsp+0x28,width),'little',signed=kind in ['short','int']);key=ctext(z)
  if y==rootPtr:entry=read(kind,key,fallback)
  else:
   row=rowsByPtr[y];calls.append(['readItem',row,kind,key,fallback]);entry=c['items'][row].get('fields',{}).get(key,dict(value=fallback,status=0))
  m.wi(w,entry['status']);m.finish(entry['value']);return
 if at in [0x14018ded0,0x14018de80]:
  u.mem_write(x,bytes(u.mem_read(y,17)) if at==0x14018de80 else ctext(y).encode('cp1252')[:16].ljust(17,b'\0'))
  if objectPtr<=x<objectPtr+0x600:calls.append(['resref',x-objectPtr,ctext(x)])
  m.finish(x);return
 if at==0x1404b4c2f:calls.append(['string',0x318,stored(objectPtr+0x318)])
 if at==0x14003d8c0:
  value=ctext(y) if z&0xffffffff==0xffffffff else bytes(u.mem_read(y,z&0xffffffff)).decode('cp1252');value='' if value.startswith('\0') else value;owning(x,value)
  if objectPtr<=x<objectPtr+0x600:calls.append(['template' if x==objectPtr+0x30 else 'string',value] if x==objectPtr+0x30 else ['string',x-objectPtr,value])
  m.finish(x);return
 if at==0x14016ac40:
  value=stored(x);calls.append(['asTag',value]);owning(y,value);m.finish(y);return
 if at==0x14045df80:value=stored(y);calls.append(['tag',value]);owning(objectPtr+0x20,value);m.finish();return
 if at==m.stop+0x100:
  calls.append(['getScript',y&0xffffffff]);m.finish(0 if c.get('scriptNull') else objectPtr+0x480);return
 if at in [m.stop+0x110,m.stop+0x120,m.stop+0x130]:
  calls.append(['portrait',ctext(y)] if at==m.stop+0x110 else ['portraitId',y&65535] if at==m.stop+0x120 else ['animation',y&0xffffffff if y&0x80000000==0 else (y&0xffffffff)-0x100000000]);m.finish();return
 if at==0x1404b3e40:calls.append(['light']);m.finish(c.get('lightResult',field(0x594)));return
 if at==0x1401a7010:calls.append(['lightColor',y&0xffffffff,stored(z)]);m.wi(w,c.get('lightColor',{}).get('value',0));m.finish(c.get('lightColor',{}).get('status',0));return
 if at==0x1401a68f0:calls.append(['trapScript',y&0xffffffff,stored(z)]);owning(w,c.get('trapScript',''));m.finish(c.get('trapStatus',0));return
 if at==0x1401a02c0:
  assert ctext(w)=='ItemList';calls.append(['list','ItemList']);m.wq(y,1);m.finish(c.get('listStatus',0));return
 if at==0x1401a0370:calls.append(['count']);m.finish(len(c.get('items',[])));return
 if at==0x1401a03f0:
  i=w&0xffffffff;currentRow=i;calls.append(['element',i]);rowsByPtr[y]=i;m.finish(c['items'][i].get('elementResult',1));return
 if at==0x140c10324:
  calls.append(['newItem',u.reg_read(UC_X86_REG_RDI)&0xffffffff]);m.finish(alloc(x) if not c['items'][currentRow].get('allocationFail') else 0);return
 if at==0x140462e90:
  allocated[x]=currentRow;m.wq(x,vtablePtr);m.finish(x);return
 if at==0x14046a9d0:
  i=allocated[x];calls.append(['loadItem',i,rowsByPtr[z],w&0xffffffff,m.si(rsp+0x28)]);m.finish(c['items'][i].get('loadResult',1));return
 if at==m.stop+0x140:calls.append(['destroyItem',allocated[x],y&0xffffffff]);m.finish();return
 if at==0x1404b11d0:
  calls.append(['acquire',allocated[m.q(y)],z&0xffffffff,w&255,u.mem_read(rsp+0x28,1)[0],m.si(rsp+0x30)]);m.finish(c.get('acquireResult',1));return
 if at in [0x140497bb0,0x140496ea0,0x140497990,0x1404969c0,0x1404972b0]:assert x==objectPtr and y==gffPtr and z==rootPtr;calls.append(['visual',at]);m.finish();return
 if at==0x140505710:assert x==objectPtr+0x2e8;calls.append(['uuid']);m.finish(c.get('uuidResult',0));return
 if at==0x14055b6e0:m.finish(modulePtr);return
 if at==0x14047a930:calls.append(['addTag',stored(y),z&0xffffffff]);m.finish();return
 if at==0x140c10368:m.finish(alloc(x));return
 if at in [0x140c10360,0x140c10370]:m.finish();return
 if at==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not 0x1404b4900<=at<0x1404b6703:raise AssertionError(f'Uncaptured placeable dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,cursor,calls,localized,rowsByPtr,allocated
 c=case;cursor=0x10000;calls=[];localized={};rowsByPtr={};allocated={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wq(0x1412df8f8,basePtr)
 # Both 2DA reads use the verified RIP target1412df8f8.
 m.wq(basePtr+0x130,rulesPtr);m.wq(rulesPtr+0x140,rulesPtr);m.wq(rulesPtr+0x288,rulesPtr)
 m.wq(objectPtr,vtablePtr);m.wi(objectPtr+8,99)
 for slot,target in [(0x1e0,0x100),(0x1a0,0x110),(0x1b0,0x120),(0x100,0x130),(0,0x140)]:m.wq(vtablePtr+slot,m.stop+target)
 for offset in offsets:
  value=case.get('initial',{}).get(str(offset),0);u.mem_write(objectPtr+offset,(value&((1<<(8*widths.get(offset,4)))-1)).to_bytes(widths.get(offset,4),'little'))
 if c.get('tag') is not None:owning(tagPtr,c['tag'])
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);m.wq(rsp+0x28,tagPtr if c.get('tag') is not None else 0);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[objectPtr,gffPtr,rootPtr,c.get('loading',0)]):u.reg_write(reg,value)
 try:u.emu_start(0x1404b4900,m.stop,count=250000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,fields={str(offset):field(offset)for offset in offsets})
rows=[]
for plotStatus,plot,usable,staticStatus,static,override in itertools.product([0,1],[0,1],[0,1,2],[0,1],[0,1,2],[0,1,2]):
 rows.append(run(dict(fields=dict(Invulnerable=dict(status=plotStatus,value=plot),Plot=dict(status=1,value=1),Useable=dict(status=1,value=usable),Static=dict(status=staticStatus,value=static)),initial={str(0x5a4):override})))
for state in range(9):rows.append(run(dict(fields=dict(AnimationState=dict(status=1,value=state)))))
for value in [-2147483648,-1,0,72,2147483647]:rows.append(run(dict(fields=dict(Animation=dict(status=1,value=value),AnimationState=dict(status=1,value=2)))))
for tag in [None,'','Override','a\0tail','\0tail']:
 for script in ['', 'default','default\0tail','Default','custom']:
  rows.append(run(dict(tag=tag,fields=dict(Tag=dict(status=1,value='Authored'),OnTrapTriggered=dict(status=1,value=script)),trapScript='native_trap')))
for portrait in [0,65533,65534,65535]:rows.append(run(dict(fields=dict(PortraitId=dict(status=1,value=portrait),Portrait=dict(status=1,value='p_test')))))
for raw,desired,status in itertools.product([0,1,2],[0,1,2],[0,1,2]):rows.append(run(dict(initial={str(0x594):raw},fields=dict(LightState=dict(status=1,value=desired)),lightColor=dict(status=status,value=-1))))
for loading,loadResult,acquireResult in itertools.product([0,1,2],[0,1,2],[0,1]):
 rows.append(run(dict(loading=loading,listStatus=1,acquireResult=acquireResult,items=[dict(loadResult=loadResult,fields=dict(ObjectId=dict(status=1,value=1234),Repos_PosX=dict(status=1,value=511),Repos_Posy=dict(status=1,value=258))),dict(loadResult=1)])))
for status in [0,2]:rows.append(run(dict(listStatus=status,items=[{}])))
rng=random.Random(20261016)
for i in range(120):
 fields={name:dict(status=1,value=rng.randrange(-32768,32768))for name in ['HP','CurrentHP']};fields.update({name:dict(status=1,value=rng.randrange(256))for name in ['Hardness','Fort','Will','Ref','TrapType','BodyBag','OpenLockDC','CloseLockDC','TrapDetectDC','DisarmDC']});fields['Appearance']=dict(status=1,value=rng.randrange(0x100000000));rows.append(run(dict(fields=fields,initial={str(offset):rng.randrange(65536)for offset in [0xfc,0x3c8,0x3d4,0x368]})))
rows.append(run(dict(scriptNull=True)));rows.append(run({}))
for loading in [0,1]:rows.append(run(dict(loading=loading,listStatus=1,items=[dict(allocationFail=True),dict(loadResult=1)])))
fields={name:dict(status=1,value=name.lower()[:16])for name in ['OnClosed','OnDamaged','OnDeath','OnDisarm','OnHeartbeat','OnInvDisturbed','OnLock','OnMeleeAttacked','OnOpen','OnSpellCastAt','OnUnlock','OnUsed','OnUserDefined','OnDialog','OnTrapTriggered','OnClick','Conversation','TemplateResRef']}
fields.update({name:dict(status=1,value=name+'\0tail')for name in ['Tag','DisplayName','KeyName','KeyRequiredFeedbackMessage','DescriptionOverride','Portal']})
fields.update({name:dict(status=1,value=dict(strRef=789,entries=[dict(languageId=0,text=name)]))for name in ['LocName','Description']})
rows.append(run(dict(fields=fields)))
out=m.root/'backups/animations/native-placeable-template-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
