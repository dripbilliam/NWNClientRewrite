"""Execute original inventory tooltip composition883340 and placement1f6df0.
Heap/string services, item display-name resolution, shared bubble dimensions,
GUI scale and final tooltip/position/activation calls are explicit providers.
Placement does not prove font fitting or final GUI pixels. No game or network.
"""
import importlib.util,itertools,json,math,re,struct,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);gui,item,bubble,input_text=[m.heap+n*0x1000 for n in [1,2,3,4]]
def allocate(size):
 global cursor
 assert 0<size<65536
 p=m.heap+cursor;cursor+=(size+31)&~15;assert cursor<0xff000;u.mem_write(p,bytes(size));return p
def cstring(p):
 if not p:return b''
 data=bytearray()
 while len(data)<65536:
  value=bytes(u.mem_read(p+len(data),1))
  if value==b'\0':return bytes(data)
  data.extend(value)
 raise AssertionError('Unbounded fixture string')
def string(p):
 size=m.si(p+8)&0xffffffff;assert size<65536
 return bytes(u.mem_read(m.q(p),size)) if size and m.q(p) else b''
def put(p,value):
 raw=value.encode('cp1252') if isinstance(value,str) else value
 q=allocate(len(raw)+1);u.mem_write(q,raw+b'\0');m.wq(p,q);m.wi(p+8,len(raw));m.wi(p+12,len(raw)+1);return p
def hook(u,a,n,_):
 x,y,z=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop:u.emu_stop();return
 if a in [0x140c10324,0x140c10368]:m.finish(allocate(x));return
 if a in [0x140c10370,0x140c10410]:m.finish();return
 if a==0x14003d8c0:put(x,cstring(y));m.finish(x);return
 if a==0x14016ab00:put(y,string(x)+string(z));m.finish(y);return
 if a==0x14083d8a0:assert x==item and z==1;put(y,case['name']);m.finish(y);return
 if a==0x1401f6df0 and phase=='compose':outputs.append(dict(raw=string(y).decode('cp1252'),below=z&0xffffffff));m.finish();return
 if a==0x1401fd690:assert x==bubble;assert cstring(y)==b'Tooltip';m.finish();return
 if a==0x1400752c0:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',case['scale']),'little'));m.finish();return
 if a==0x140c8f234:
  value=m.xmm(UC_X86_REG_XMM0);rounded=math.copysign(math.floor(abs(value)+0.5),value)
  u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',rounded),'little'));m.finish();return
 if a==0x1401fcca0:assert x==bubble;outputs.append(dict(anchor=[y&0xffffffff,z&0xffffffff]));m.finish();return
 if a==0x1401fbe70:assert x==bubble;m.finish(1);return
 if not start<=a<end:raise AssertionError(f'Uncaptured tooltip dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset(entry,last):
 global cursor,outputs,start,end
 cursor=0x10000;outputs=[];start=entry;end=last;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
def execute(args):
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],args):u.reg_write(reg,value)
 u.emu_start(start,m.stop,count=30000);assert u.reg_read(UC_X86_REG_RIP)==m.stop and len(outputs)==1
 return outputs[0]
compositions=[];phase='compose'
for mode,name,custom,below in itertools.product(range(5),['Native Item','[b]Literal[/b]\nName'],['','<c\x01\xff\x01>Custom</c>','Prefix\n'],[0,1]):
 reset(0x140883340,0x140883448);case=dict(mode=mode,name=name,custom=custom,below=below);m.wi(item+0x16c,mode);put(item+0x170,custom)
 compositions.append(dict(**case,output=execute([gui,item,below])))
positions=[];phase='position'
for scale,point,dimensions,below in itertools.product([1,1.25,2],[[0,0],[100,200],[790,590]],[[100,20],[300,60]],[0,1]):
 reset(0x1401f6df0,0x1401f6fbd);case=dict(scale=scale,point=point,viewport=[800,600],dimensions=dimensions,below=below)
 m.wq(gui+0x170,bubble);m.wi(gui+0xd4,point[0]);m.wi(gui+0xd8,point[1]);m.wi(gui+0xb8,800);m.wi(gui+0xbc,600);m.wf(bubble+0xf8,dimensions[0]);m.wf(bubble+0xfc,dimensions[1]);put(input_text,'Tooltip')
 positions.append(dict(**case,output=execute([gui,input_text,below])))
name=next((arg.split('=',1)[1]for arg in sys.argv[1:]if arg.startswith('--report=')),'native-item-tooltip-v1.json');assert re.fullmatch(r'native-item-tooltip-[a-z0-9-]+\.json',name)
output=m.root/'backups/animations'/name;assert not output.exists(),'Preserve prior evidence'
output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,compositions=compositions,positions=positions),indent=2)+'\n')
print(json.dumps(dict(output=str(output),compositions=len(compositions),positions=len(positions))))
