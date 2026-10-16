"""Complete original LoadMaterial496ea0, LoadTextureReplace497990,
LoadAnimationOverrides4969c0 and LoadMiscVisuals4972b0 (image base140000000).
Typed GFF reads, allocator/copy/free/cookie are captured lower boundaries.
No renderer, native file parser or visual-transform setters are claimed.
"""
import importlib.util,itertools,json,struct,random
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);objectPtr,gffPtr,rootPtr=m.heap+0x1000,m.heap+0x2000,m.heap+0x3000
specs=dict(material=(0x140496ea0,0x1404972aa,'Material','ShaderParams',0x2b8,108),texture=(0x140497990,0x140497ba0,'TextureReplace','TextureReplaceList',0x2c8,34),animation=(0x1404969c0,0x140496bd0,'AnimationReplace','AnimationReplaceList',0x2d8,34),misc=(0x1404972b0,0x1404974ad,'MiscVisuals',None,None,None))
misc=[(0x260,'int'),(0x254,'float'),(0x258,'float'),(0x25c,'float'),(0x268,'float'),(0x26c,'int'),(0x270,'int')]
def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~15;assert cursor<0x100000;return ptr
def ctext(ptr):return bytes(u.mem_read(ptr,512)).split(b'\0')[0].decode('cp1252') if ptr else ''
def owning(ptr,text):
 raw=text.encode('cp1252');target=alloc(len(raw)+1);u.mem_write(target,raw+b'\0');m.wq(ptr,target if raw else 0);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1 if raw else 0)
def stored(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8))).decode('cp1252') if m.q(ptr) else ''
def read(record,kind,key,fallback):
 calls.append(['read',record,kind,key,fallback]);fields=c.get('fields',{}) if record=='root' else c.get('rows',[])[record].get('fields',{});return fields.get(key,dict(status=0,value=fallback))
def hook(u,at,n,_):
 if at==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if at==0x1401a04e0:
  key=ctext(w);assert key==active[2];calls.append(['struct',key]);result=c.get('structStatus',1)
  if result:descriptors[y]='root'
  m.finish(result);return
 if at==0x1401a02c0:
  key=ctext(w);assert key==active[3];calls.append(['list','root',key]);result=c.get('listStatus',1)
  if result:descriptors[y]='list'
  m.finish(result);return
 if at==0x1401a0370:calls.append(['count']);m.finish(c.get('count',len(c.get('rows',[]))));return
 if at==0x1401a03f0:
  index=w&0xffffffff;calls.append(['element',index]);result=c['rows'][index].get('status',1)
  if result:descriptors[y]=index
  m.finish(result);return
 if at in [0x1401a0ee0,0x1401a1770,0x1401a1650]:
  kind={0x1401a0ee0:'byte',0x1401a1770:'int',0x1401a1650:'float'}[at];fallback=u.mem_read(rsp+0x28,1)[0] if kind=='byte' else m.si(rsp+0x28) if kind=='int' else m.rf(rsp+0x28)
  entry=read(descriptors[y],kind,ctext(z),fallback);m.wi(w,entry['status'])
  if kind=='float':u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',entry['value']),'little'));m.finish()
  else:m.finish(entry['value'])
  return
 if at in [0x1401a1130,0x1401a12d0]:
  kind='string' if at==0x1401a1130 else 'resref';entry=read(descriptors[z],kind,ctext(w),'');value=entry['value'];m.wi(m.q(rsp+0x28),entry['status'])
  if kind=='string':owning(y,'' if value.startswith('\0') else value)
  else:u.mem_write(y,value.encode('cp1252')[:16].ljust(17,b'\0'))
  m.finish(y);return
 if at==0x14018ded0:u.mem_write(x,ctext(y).encode('cp1252')[:16].ljust(17,b'\0'));m.finish(x);return
 if at in [0x14048dfb0,0x14048e0d0]:
  offset=x-objectPtr;size=108 if at==0x14048dfb0 else 34;capacity=y&0xffffffff;calls.append(['reserve',offset,capacity]);target=alloc(capacity*size)
  if m.q(x) and m.si(x+8):u.mem_write(target,bytes(u.mem_read(m.q(x),m.si(x+8)*size)))
  m.wq(x,target);m.wi(x+12,capacity);m.finish();return
 if at in [0x140496f5e,0x140497a1f,0x140496a4f]:calls.append(['clear',active[4]])
 if at==0x140c4eec0:
  raw=ctext(y).encode('cp1252')[:z];u.mem_write(x,raw.ljust(z,b'\0'));m.finish(x);return
 if at==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x);return
 if at==0x140c10368:m.finish(alloc(x));return
 if at in [0x140c10360,0x140c10370]:m.finish();return
 if at==0x140c417f0:
  if z:u.mem_write(x,bytes(u.mem_read(y,z)))
  m.finish(x);return
 if at==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not active[0]<=at<active[1]:raise AssertionError(f'Uncaptured object visual data dependency {at:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,active,cursor,calls,descriptors
 c=case;active=specs[c['mode']];cursor=0x10000;calls=[];descriptors={rootPtr:'root'};u.mem_write(m.heap,bytes(0x100000))
 for _,_,_,_,offset,size in [specs[k]for k in ['material','texture','animation']]:
  ptr=alloc(size*2);u.mem_write(ptr,bytes((i+offset)&255 for i in range(size)));m.wq(objectPtr+offset,ptr);m.wi(objectPtr+offset+8,1);m.wi(objectPtr+offset+12,2)
 for offset,kind in misc:
  if kind=='float':m.wf(objectPtr+offset,offset/8)
  else:m.wi(objectPtr+offset,offset)
 owning(objectPtr+0x278,'old bubble')
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes([c.get('stackSeed',0)])*0x700);m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[objectPtr,gffPtr,rootPtr]):u.reg_write(reg,value)
 try:u.emu_start(active[0],m.stop,count=3000000)
 except Exception:print(json.dumps(dict(case=c,calls=calls[-12:],rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 pools={}
 for _,_,_,_,offset,size in [specs[k]for k in ['material','texture','animation']]:
  ptr,count,capacity=m.q(objectPtr+offset),m.si(objectPtr+offset+8),m.si(objectPtr+offset+12);pools[str(offset)]=dict(capacity=capacity,records=[bytes(u.mem_read(ptr+i*size,size)).hex()for i in range(count)])
 fields={str(offset):m.rf(objectPtr+offset) if kind=='float' else m.si(objectPtr+offset)for offset,kind in misc};fields[str(0x278)]=stored(objectPtr+0x278)
 return dict(case=c,calls=calls,pools=pools,fields=fields)
rows=[]
for mode,status,listStatus in itertools.product(specs,[0,1,2],[0,1,2]):rows.append(run(dict(mode=mode,structStatus=status,listStatus=listStatus)))
for mode in ['texture','animation']:
 old,new=('OldTexture','NewTexture')if mode=='texture'else('OldAnimation','NewAnimation')
 for value,replacement in [('', ''),('MiXeD','TARGET'),('a'*16,'b'*20),('x\0tail','y\0tail'),('café','été')]:
  rows.append(run(dict(mode=mode,rows=[dict(fields={old:dict(status=1,value=value),new:dict(status=1,value=replacement)}),dict(status=0),dict(fields={old:dict(status=2,value=value),new:dict(status=1,value='duplicate')})])))
 for count in [1,15,16,17,32,33]:rows.append(run(dict(mode=mode,rows=[dict(fields={old:dict(status=1,value='same'),new:dict(status=1,value=str(i))})for i in range(count)])))
 rows.append(run(dict(mode=mode,count=-1)))
for kind in [0,1,2,3,255]:
 fields=dict(Type=dict(status=1,value=kind),Int=dict(status=1,value=-1234),Float1=dict(status=1,value=1.25),Float2=dict(status=1,value=-2.5),Float3=dict(status=1,value=3.75),Float4=dict(status=1,value=0.125),Material=dict(status=1,value='m'*19),Param=dict(status=1,value='p'*67))
 rows.append(run(dict(mode='material',rows=[dict(fields=fields),dict(status=0),dict(fields=fields)])))
for count in [16,17,1023,1024,1025]:rows.append(run(dict(mode='material',rows=[dict(fields=dict(Type=dict(status=1,value=1),Int=dict(status=1,value=i)))for i in range(count)])))
for count in [-1,0]:rows.append(run(dict(mode='material',count=count)))
rows.append(run(dict(mode='material',stackSeed=165,rows=[dict(fields=dict(Type=dict(status=1,value=1),Int=dict(status=1,value=27)))])))
for value in ['', 'bubble\0tail','\0discard','café']:
 rows.append(run(dict(mode='misc',fields=dict(TextBubbleText=dict(status=1,value=value),TextBubbleType=dict(status=1,value=3),MouseCursor=dict(status=1,value=-2147483648),HiliteColorR=dict(status=1,value=.1234),HiliteColorG=dict(status=1,value=2),HiliteColorB=dict(status=1,value=-2),VisibleDistance=dict(status=1,value=99.875),UiDiscoverMask=dict(status=1,value=-1)))))
rng=random.Random(20261016)
for i in range(90):
 fields=dict(Type=dict(status=1,value=1+i%2),Int=dict(status=1,value=rng.randrange(-2147483648,2147483648)),Material=dict(status=1,value='a\0tail' if i%2 else 'Café'),Param=dict(status=1,value='Param'+str(i)))
 fields.update({f'Float{n}':dict(status=1,value=rng.uniform(-100,100))for n in range(1,5)});rows.append(run(dict(mode='material',rows=[dict(fields=fields)])))
out=m.root/'backups/animations/native-object-visual-data-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
