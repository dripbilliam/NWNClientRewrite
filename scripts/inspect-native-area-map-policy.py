"""Unchanged original area-map frame sizing894720 and coordinate conversion892010.
Only sprintf/model binding, alpha, slider resize, viewport attachment, position
publication and security-cookie return are captured lower boundaries. No GPU,
network, original profile or live process is accessed. Caps are authored inputs;
this does not establish how every original viewport updates those globals.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,model,vtable,point,out=[m.heap+n for n in [0x1000,0x3000,0x4000,0x5000,0x6000]]
d=json.loads((m.root/'backups/animations/rea-native-area-map-v1.json').read_text())
ranges=[(int(b['start'],16),int(b['end'],16)+1) for row in d['rows'] if row['procedure']['address'] in ['0x140894720','0x140892010'] for b in row['procedure']['body']['ranges']]
def string(address):return bytes(u.mem_read(address,80)).split(b'\0')[0].decode('ascii')
def hook(u,address,size,_):
 global published
 if address==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if address==0x140047000:
  text=string(y)%(z&0xffffffff,w&0xffffffff);u.mem_write(x,text.encode()+b'\0');m.finish(len(text));return
 if address==0x1401fb710:published=string(y);m.wq(x+0x10,model);m.finish();return
 if address==0x1400a4c30:calls.append(['alpha',m.xmm(UC_X86_REG_XMM1)]);m.finish();return
 if address==0x1401e7390:calls.append(['slider',x-panel,m.xmm(UC_X86_REG_XMM1)]);m.finish();return
 if address in [0x1401f05e0,0x140c10410,m.stop+0x100]:m.finish();return
 if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original map dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
frames=[]
for width,height,zoom,caps in itertools.product([1,2,4,9,10,21,32,64],[1,2,4,9,10,21,32,64],[8,16,32],[(21,24),(4,2),(40,30)]):
 u.mem_write(m.heap,bytes(0x100000));m.wq(model,vtable);m.wq(vtable+0xb0,m.stop+0x100)
 for offset,value in [(0x4e0,width),(0x4e4,height),(0x514,zoom),(0x9c0,-1),(0x9c4,-1)]:m.wi(panel+offset,value)
 m.wi(0x1412981cc,caps[0]);m.wi(0x1412981d0,caps[1]);published='';calls=[];call(0x140894720,[panel])
 assert published and len(calls)==3
 frames.append(dict(width=width,height=height,zoom=zoom,caps=caps,output=dict(resource=published.lower(),columns=m.si(panel+0x9c0),rows=m.si(panel+0x9c4),calls=calls)))
coordinates=[]
for width,height,zoom,local in itertools.product([1,10,64],[1,10,64],[8,16,32],[(0,0,0),(-0.5,0.25,0.02),(1.125,-2.25,-0.09),(10,10,0)]):
 u.mem_write(m.heap,bytes(0x100000));m.wi(panel+0x4e0,width);m.wi(panel+0x4e4,height);m.wi(panel+0x514,zoom)
 for axis,value in enumerate(local):m.wf(point+axis*4,value)
 call(0x140892010,[panel,out,point]);coordinates.append(dict(width=width,height=height,zoom=zoom,local=local,world=[m.rf(out+axis*4)for axis in range(3)]))
path=m.root/'backups/animations/native-area-map-policy-observations-v1.json';assert not path.exists(),'Preserve previous map observations'
path.write_text(json.dumps(dict(target=m.digest,scope=__doc__,frames=frames,coordinates=coordinates),indent=2)+'\n');print(json.dumps(dict(output=str(path),frames=len(frames),coordinates=len(coordinates))))
