"""Execute unchanged original GUI scale and video arrow/Apply instructions.
Only configuration/string allocation, list selection, font refresh, GUI refresh
and window-refresh boundaries are captured. No original process, profile or
network is touched. Display enumeration/mode changes and full UI remain open.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel=m.heap+0x1000
sources=[json.loads((m.root/'backups/animations'/f).read_text()) for f in ['rea-native-video-options-v1.json','rea-native-video-scale-v1.json']]
allowed={'0x140074f70','0x1400750a0','0x1400752e0','0x140075710','0x140c7f560','0x14082feb0','0x14082ff20','0x14082ef60'}
ranges=[(int(b['start'],16),int(b['end'],16)+1) for source in sources for row in source['rows'] if row['procedure']['address'] in allowed for b in row['procedure']['body']['ranges']]
def bits(v):return struct.unpack('<I',struct.pack('<f',v))[0]
def xmm(v):u.reg_write(UC_X86_REG_XMM0,bits(v))
def hook(u,address,size,_):
 global refreshed,writes
 if address==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if address==0x14003dc20:
  # Preserve an inline short ui.scale string; longer config-name arguments
  # are consumed only by the named boolean query capture below.
  if z<=15:u.mem_write(x,bytes(u.mem_read(y,z))+b'\0');m.wq(x+0x10,z);m.wq(x+0x18,15)
  m.finish(x);return
 if address==0x140119650:m.finish(unconstrained);return
 if address==0x14011a3c0:
  writes.append(dict(key=bytes(u.mem_read(y,16)).split(b'\0')[0].decode(),value=struct.unpack('<d',u.mem_read(z,8))[0]));m.finish();return
 if address==0x1401f21b0:m.finish(-1);return
 if address==0x1400e9830:refreshed+=1;m.finish();return
 if address in [0x140c10360,0x140c10410,0x1401f63e0,0x1406ac4e0,0x1406ac640]:m.finish();return
 if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original scale dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def initialize():
 global refreshed,writes
 refreshed=0;writes=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8b8,m.heap+0x9000);m.wq(m.heap+0x9000,m.heap+0xa000);m.wq(0x1412df970,m.heap+0xb000);m.wq(m.heap+0xb000,m.heap+0xc000)
 u.mem_write(0x1412996e0,b'\0')
def call(address,first=0,second=0):
 u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,first);u.reg_write(UC_X86_REG_RDX,second)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return m.xmm(UC_X86_REG_XMM0)
sizes=[[640,480],[800,600],[900,700],[1280,720],[1424,921],[1800,1400],[1920,1080],[2560,1440],[3440,1369],[3840,2160],[7200,5600],[1799,1399],[1801,1401],[0,0]]
desired=[]
for width,height in sizes:
 for unconstrained in [False,True]:
  initialize();value=call(0x140074f70,width,height);desired.append(dict(width=width,height=height,unconstrained=unconstrained,value=value,bits=bits(value)))
steps=[];unconstrained=False
for value,minimum,maximum,increase in itertools.product([0.9,1.0,1.09,1.1,1.5,1.6,1.7,4.0],[1.0,1.2],[1.0,1.7,4.0],[False,True]):
 initialize();m.wf(panel+0xe08,value);m.wf(panel+0xe10,minimum);m.wf(0x14128e524,maximum);call(0x14082ff20 if increase else 0x14082feb0,panel);result=m.rf(panel+0xe08)
 steps.append(dict(value=value,minimum=minimum,maximum=maximum,increase=increase,result=result,bits=bits(result)))
updates=[]
for (width,height),fixed,previous,unconstrained in itertools.product(sizes[:10],[0.0,0.5,1.0,1.09,1.1,1.5,4.0],[1.0,1.1],[False,True]):
 initialize();m.wf(0x1413016b0,fixed);m.wf(0x1413016a4,previous);call(0x1400750a0,width,height)
 result={name:m.rf(address) for name,address in [('maximum',0x14128e524),('scale',0x1413016a4),('guiToPixel',0x1413016ac)]}
 updates.append(dict(width=width,height=height,fixed=fixed,previous=previous,unconstrained=unconstrained,**result,bits={k:bits(v) for k,v in result.items()},refreshFonts=refreshed==1));assert refreshed in [0,1]
applies=[]
for value,maximum in itertools.product([0.5,1.0,1.01,1.08,1.09,1.1,1.5,1.69,1.7,1.79,4.0],[1.0,1.7,4.0]):
 unconstrained=False;initialize();m.wf(panel+0xe08,value);m.wf(0x14128e524,maximum);m.wi(0x14128e034,1920);m.wi(0x14128e038,1080);call(0x14082ef60,panel)
 assert len(writes)==1 and writes[0]['key']=='ui.scale' and m.si(panel+0xe18)==1
 fixed=m.rf(0x1413016b0);applies.append(dict(value=value,maximum=maximum,fixed=fixed,bits=bits(fixed),writtenValue=writes[0]['value'],writtenDoubleBits=struct.pack('<d',writes[0]['value']).hex()))
output=m.root/'backups/animations/native-video-scale-observations-v2.json';assert not output.exists(),'Preserve previous observations'
output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,desired=desired,steps=steps,updates=updates,applies=applies),indent=2)+'\n')
print(json.dumps(dict(output=str(output),desired=len(desired),steps=len(steps),updates=len(updates),applies=len(applies))))
