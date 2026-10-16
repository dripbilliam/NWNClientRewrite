"""Full original LoadWaypoint140509f80..14050a462 and Normalize14022db30.
GFF readers, string/localized copy, UUID loader and module tag lookup
are captured boundaries with independently supplied statuses. Tests caller
ordering, defaults, tag override and reload retention; not lower UUID,
GFF malformed-data recovery, template resources, map-pin transport or UI.
"""
import importlib.util,itertools,json,struct,math,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
objectPtr,gffPtr,rootPtr,tagPtr,modulePtr,appPtr=[m.heap+n*0x1000 for n in range(1,7)]
empty=dict(strRef=0xffffffff,entries=[])

def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;return ptr

def owning(ptr,text):
 raw=text.encode('cp1252');target=alloc(len(raw)+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)

def ctext(ptr):return bytes(u.mem_read(ptr,256)).split(b'\0')[0].decode('cp1252') if ptr else ''

def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)&0xffffffff)).decode('cp1252') if m.q(ptr) else ''

def loc(ptr,value):
 token=alloc(16);localized[token]=value;m.wq(ptr,token);m.wi(ptr+8,value['strRef'])

def locvalue(ptr):return localized.get(m.q(ptr),empty)

def vector(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))

def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x140169560:loc(x,empty);m.finish(x);return
 if at==0x1401695b0:m.finish();return
 if at==0x140169600:
  value=locvalue(y);loc(x,value)
  if x in [objectPtr+0x310,objectPtr+0x320]:calls.append(['localized',x-objectPtr,value])
  m.finish(x);return
 if at==0x1401a1130:
  key=ctext(w);entry=c.get('fields',{}).get(key,dict(value='',status=0));calls.append(['read','string',key,'']);owning(y,entry['value']);m.wi(m.q(rsp+0x28),entry['status']);m.finish(y);return
 if at==0x1401a0f80:
  key=ctext(w);entry=c.get('fields',{}).get(key,dict(value=empty,status=0));calls.append(['read','localized',key,empty]);loc(y,entry['value']);m.wi(m.q(rsp+0x28),entry['status']);m.finish(y);return
 if at==0x1401a1650:
  key=ctext(z);entry=c.get('fields',{}).get(key,dict(value=0,status=0));calls.append(['read','float',key,m.rf(rsp+0x28)]);m.wi(w,entry['status']);u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',entry['value']),'little'));m.finish();return
 if at==0x1401a0f60:
  key=ctext(z);entry=c.get('fields',{}).get(key,dict(value=0,status=0));calls.append(['read','bool',key,u.mem_read(rsp+0x28,1)[0]]);m.wi(w,entry['status']);m.finish(entry['value']);return
 if at==0x1401a12d0:
  key=ctext(w);entry=c.get('fields',{}).get(key,dict(value='',status=0));calls.append(['read','resref',key,'']);u.mem_write(y,entry['value'].encode('cp1252')[:16]+b'\0');m.wi(m.q(rsp+0x28),entry['status']);m.finish(y);return
 if at==0x14018ded0:u.mem_write(x,ctext(y).encode('cp1252')[:16]+b'\0');m.finish(x);return
 if at==0x14003d8c0:
  text=bytes(u.mem_read(y,z&0xffffffff)).decode('cp1252');owning(x,text)
  if x in [objectPtr+0x20,objectPtr+0x30]:calls.append(['tag' if x==objectPtr+0x20 else 'template',text])
  m.finish(x);return
 if at==0x14049bb40:
  calls.append(['position',vector(y),z&0xffffffff]);u.mem_write(objectPtr+0xa4,bytes(u.mem_read(y,12)));m.finish();return
 if at==0x14049b910:
  calls.append(['orientation',vector(y)]);u.mem_write(objectPtr+0xb0,bytes(u.mem_read(y,12)));m.finish();return
 if at==0x140c7d6d8:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(m.xmm(UC_X86_REG_XMM0))),'little'));m.finish();return
 if at==0x14055b6e0:m.finish(modulePtr);return
 if at==0x14047a930:assert x==modulePtr;calls.append(['addTag',stored(y),z&0xffffffff]);m.finish();return
 if at==0x140505710:assert x==objectPtr+0x2e8 and y==gffPtr and z==rootPtr;calls.append(['uuid']);m.finish(c.get('uuidResult',0));return
 if at==0x140c10368:m.finish(alloc(x));return
 if at in [0x140c10360,0x140c10370]:m.finish();return
 if at==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not (0x140509f80<=at<0x14050a462 or 0x14022db30<=at<0x14022dbf2):raise AssertionError(f'Uncaptured waypoint load dependency {at:x}: {c}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,cursor,calls,localized
 c=case;cursor=0x10000;calls=[];localized={};u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,appPtr);m.wq(appPtr+8,appPtr);m.wi(objectPtr+8,99);m.wi(objectPtr+0x308,c.get('has',0));m.wi(objectPtr+0x30c,c.get('enabled',0));loc(objectPtr+0x310,c.get('note',empty));owning(objectPtr+0x20,'previous_tag');owning(objectPtr+0x30,'previous_template')
 if c.get('tag') is not None:owning(tagPtr,c['tag'])
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[objectPtr,gffPtr,rootPtr,tagPtr if c.get('tag') is not None else 0]):u.reg_write(reg,value)
 try:u.emu_start(0x140509f80,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls,has=m.si(objectPtr+0x308),enabled=m.si(objectPtr+0x30c),note=locvalue(objectPtr+0x310))

rows=[]
note=dict(strRef=123,entries=[dict(languageId=0,text='Map note')])
for tag,hasStatus,has,enabledStatus,noteStatus,old in itertools.product([None,'','Override','a\0tail','\0tail'],[0,1,2],[0,1,2],[0,1],[0,1,2],[False,True]):
 fields=dict(Tag=dict(value='Authored',status=1),HasMapNote=dict(value=has,status=hasStatus),MapNoteEnabled=dict(value=2,status=enabledStatus),MapNote=dict(value=note,status=noteStatus))
 rows.append(run(dict(tag=tag,fields=fields,has=2 if old else 0,enabled=7 if old else 0,note=dict(strRef=456,entries=[]) if old else empty)))
rng=random.Random(20261016)
for v in [[0,0,0],[1,0,0],[.6,.8,0],[.999999,0,0],[1.000002,0,0],[1,2,3],[-3,5,-9]]+[[rng.uniform(-100,100)for _ in range(3)]for _ in range(150)]:
 fields={key:dict(value=value,status=1)for key,value in zip(['XPosition','YPosition','ZPosition','XOrientation','YOrientation','ZOrientation'],[12.1,-3.2,.125]+v)};fields['TemplateResRef']=dict(value='MiXeD_ref',status=1);fields['LocalizedName']=dict(value=note,status=1);rows.append(run(dict(fields=fields)))
rows.append(run({}))
out=m.root/'backups/animations/native-waypoint-template-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
