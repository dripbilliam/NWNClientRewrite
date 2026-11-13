"""Bounded original1406e8880 popup overlap oracle in isolated Unicorn memory.

Only SetPositionScreenVector is captured (index and exact float bits); no model,
GUI engine, rendering, current client, process access, network or profile used.
The original whole instruction body executes unchanged, with Tracy disabled.
"""
from pathlib import Path
import hashlib,json,random,struct,sys
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
binary=root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'
raw=binary.read_bytes();digest=hashlib.sha256(raw).hexdigest()
assert digest=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase
u=Uc(UC_ARCH_X86,UC_MODE_64)
u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095)
u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x10000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
placed=[]
def wq(at,v):u.mem_write(at,struct.pack('<Q',v))
def wi(at,v):u.mem_write(at,struct.pack('<I',v&0xffffffff))
def wf(at,v):u.mem_write(at,struct.pack('<f',v))
def rf(at):return struct.unpack('<f',u.mem_read(at,4))[0]
def hook(cpu,at,size,data):
 if at==stop:cpu.emu_stop();return
 if at==0x1401fced0:
  obj=cpu.reg_read(UC_X86_REG_RCX);vector=cpu.reg_read(UC_X86_REG_RDX)
  assert obj>=heap+0x4000 and (obj-heap-0x4000)%0x200==0
  placed.append(dict(index=(obj-heap-0x4000)//0x200,xyz=[rf(vector+n*4)for n in range(3)],bits=[bytes(cpu.mem_read(vector+n*4,4)).hex()for n in range(3)]))
  sp=cpu.reg_read(UC_X86_REG_RSP)
  cpu.reg_write(UC_X86_REG_RIP,int.from_bytes(cpu.mem_read(sp,8),'little'))
  cpu.reg_write(UC_X86_REG_RSP,sp+8);return
 assert 0x1406e8880<=at<=0x1406e8ccb,f'Uncaptured original dependency{at:x}'
u.hook_add(UC_HOOK_CODE,hook)
def row(x=100,y=100,w=100,h=20,active=1,z=-5):return dict(x=x,y=y,z=z,width=w,height=h,active=active)
presets=[[],[row()],[row(),row()],[row(),row(199.75,100.25)],
 [row(w=150,h=104),row(100,100,w=100,h=20)],
 [row(),row(105,105,active=0),row(100,100),row(100,100,active=4)],
 [row(),row(95,100),row(105,100),row(100,100)],
 [row(-.75,-.25,151,35),row(.25,.75,101,21)],
 [row(100,100),row(100,120),row(100,110)],
 [row(150,100),row(50,100),row(100,100)],
 [row(100,100,100,20),row(100,100,150,34),row(100,100,300,62),row(100,100,300,454)],
 [row(0,0,0,0),row(0,0,0,0),row(1,1,100,20)]]
cases=[dict(name=f'preset{index}-mode{mode}',mode=mode,enabled=True,rows=rows)for index,rows in enumerate(presets)for mode in [0,1,2]]
cases += [dict(name=f'disabled{n}',mode=1 if n%2 else 2,enabled=False,rows=presets[n+2])for n in range(4)]
rng=random.Random(0x6e8880)
for n in range(24):
 rows=[row(rng.choice([-.75,0,.25,100,140,200])+rng.randrange(-40,40),rng.choice([-.25,0,.75,100,120,200])+rng.randrange(-40,40),rng.choice([100,150,300]),rng.choice([20,34,48,62,104,230,454]),rng.choice([0,1,1,1,4]))for _ in range(3+n%6)]
 cases.append(dict(name=f'bounded{n}',mode=1+n%2,enabled=True,rows=rows))
observations=[]
for case in cases:
 placed=[];u.mem_write(heap,bytes(0x10000));u.mem_write(stack,bytes(0x20000))
 u.mem_write(0x14141e310,b'\0');wi(0x141296de8,case['mode']);wi(0x141296df0,int(case['enabled']))
 wq(0x1414232f0,heap+0x1000);wi(0x1414232f8,len(case['rows']))
 for index,entry in enumerate(case['rows']):
  obj=heap+0x4000+index*0x200;wq(heap+0x1000+index*8,obj)
  wi(obj+0xb0,entry['active']);wf(obj+0xf8,entry['width']);wf(obj+0xfc,entry['height'])
  for n,key in enumerate(['x','y','z']):wf(obj+0x14c+n*4,entry[key])
 sp=stack+0x1fe08;wq(sp,stop);u.reg_write(UC_X86_REG_RSP,sp)
 u.emu_start(0x1406e8880,stop,count=100000)
 assert u.reg_read(UC_X86_REG_RIP)==stop,'Original routine exceeded bounded instruction budget'
 result=[dict(x=rf(heap+0x414c+i*0x200),y=rf(heap+0x4150+i*0x200),z=rf(heap+0x4154+i*0x200))for i in range(len(case['rows']))]
 observations.append(dict(case=case,result=result,placed=placed))
assert hashlib.sha256(binary.read_bytes()).hexdigest()==digest
out=Path(sys.argv[1]);assert out.is_relative_to(root)and not out.exists(),'Use NEW workspace evidence path'
out.write_text(json.dumps(dict(schema='native-overhead-popup-layout-original-v1',binarySha256=digest,harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope=__doc__,procedure='0x1406e8880',capturedBoundary='CGuiPanel.SetPositionScreenVector0x1401fced0',engineRun=False,liveProcessAccess=False,cases=observations),indent=2)+'\n')
print(json.dumps(dict(cases=len(observations),output=str(out),binarySha256=digest)))
