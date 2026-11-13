"""Unchanged original LoadBorder1407dea10 over installed SET/Edge2DA values.

Isolated Unicorn only. Captures C2DA resource/string, allocation/free, GUI status,
screen update and Scene.SpawnTile boundaries. Actual original control flow,
matching/order, side/corner iteration, orientation getters and float placement
execute. No model/art loading, renderer, game process, network or private data.
"""
from pathlib import Path
import sys,struct,json,hashlib
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'backups/research-python'))
import pefile
from unicorn import Uc,UC_ARCH_X86,UC_MODE_64,UC_HOOK_CODE
from unicorn.x86_const import *
source=root.parent/'FullDecomp/NwnRootInstall/bin/win32/nwmain.exe';raw=source.read_bytes();sha=hashlib.sha256(raw).hexdigest()
assert sha=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase;u=Uc(UC_ARCH_X86,UC_MODE_64)
u.mem_map(base,(pe.OPTIONAL_HEADER.SizeOfImage+4095)&~4095);u.mem_write(base,pe.get_memory_mapped_image())
heap,stack,stop=0x200000000,0x300000000,0x400000000
u.mem_map(heap,0x2000000);u.mem_map(stack,0x20000);u.mem_map(stop,0x1000)
def q(at):return int.from_bytes(u.mem_read(at,8),'little')
def wi(at,v):u.mem_write(at,struct.pack('<I',v&0xffffffff))
def wq(at,v):u.mem_write(at,struct.pack('<Q',v))
def wf(at,v):u.mem_write(at,struct.pack('<f',v))
def rf(at):return struct.unpack('<f',u.mem_read(at,4))[0]
def cstr(at):
 if not at:return ''
 out=bytearray()
 for n in range(4096):
  byte=u.mem_read(at+n,1)[0]
  if not byte:return out.decode('latin1')
  out.append(byte)
 raise RuntimeError('Unbounded native string')
cursor=0;case={};observed=[]
def allocate(size):
 global cursor
 at=heap+cursor;cursor+=(size+31)&~31
 assert cursor<0x2000000,'Bounded oracle heap exhausted'
 return at
def string(at,text):
 data=text.encode('latin1');p=allocate(len(data)+1);u.mem_write(p,data+b'\0');wq(at,p);wi(at+8,len(data));wi(at+12,len(data)+1)
def finish(value=0):
 sp=u.reg_read(UC_X86_REG_RSP);u.reg_write(UC_X86_REG_RIP,q(sp));u.reg_write(UC_X86_REG_RSP,sp+8);u.reg_write(UC_X86_REG_RAX,value&0xffffffffffffffff)
def hook(cpu,at,size,data):
 x,y,z,v=[cpu.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if at==stop:cpu.emu_stop();return
 if at in [0x140c10324,0x140c10368]:finish(allocate(x));return
 if at==0x140c10370:finish();return
 if at==0x140c417f0:cpu.mem_write(x,bytes(cpu.mem_read(y,z)));finish(x);return
 if at==0x14003d8c0:
  text=cstr(y)if z&0xffffffff==0xffffffff else bytes(cpu.mem_read(y,z&0xffffffff)).decode('latin1')if z else ''
  string(x,text);finish(x);return
 if at==0x14018ded0:cpu.mem_write(x,cstr(y).encode('latin1')[:16].ljust(17,b'\0'));finish(x);return
 if at==0x1401a62b0:wq(x,heap+0x400);wi(x+0x50,len(case['sample']['rows']));finish(x);return
 if at==0x1401a73a0:finish(1 if case.get('loaded',True)else 0);return
 if at==0x1401a9b10 or at==stop+0x10 or at==0x1401ec270 or at==0x1400451c0 or at==0x140c10410:finish();return
 if at in [0x1401a68f0,0x1401a7010]:
  row=case['sample']['rows'][y];column=cstr(q(z));key=next((k for k in row if k.lower()==column.lower()),None)
  text=str(row[key])if key else case['sample']['defaultValue'];text=''if text=='****'else text
  if at==0x1401a68f0:string(v,text)
  else:
   assert not text or text.lstrip('+-').isdigit(),'Oracle restricts installed Height to proven decimal conversion'
   wi(v,int(text or '0'))
  finish(int(key is not None and bool(text)));return
 if at==0x14016bd70:string(y,cstr(q(x)).lower());finish(y);return
 if at==stop+0x30:
  sp=cpu.reg_read(UC_X86_REG_RSP);flags=int.from_bytes(cpu.mem_read(sp+0x28,4),'little');rotation=v&0xff
  assert flags==1 and q(sp+0x30)==0
  observed.append(dict(model=cstr(y),orientation=rotation,nativePosition=[rf(z+i*4)for i in range(3)],positionBits=[bytes(cpu.mem_read(z+i*4,4)).hex()for i in range(3)],nativeSpawnFlags=flags))
  finish(1);return
 allowed=[(0x1407dea10,0x1407e1928),(0x1402c6720,0x1402c6755),(0x1402c6760,0x1402c6795),(0x1402c67c0,0x1402c67c6),(0x1402c5d20,0x1402c5dbf),(0x1402c5dc0,0x1402c5e74),(0x140044840,0x140044885)]
 assert any(lo<=at<hi for lo,hi in allowed),f'Uncaptured original dependency{at:x}'
u.hook_add(UC_HOOK_CODE,hook)
fixture=json.loads((root/'godot-client/reports/native-area-border-installed-v1.json').read_text())
cases=[]
for sample in fixture['samples']:
 for turn in [0,1]:
  tiles=[dict(id=(i*17+turn*3)%len(sample['tiles']),orientation=(i+turn)%4,height=i-1)for i in range(4)]
  cases.append(dict(name=sample['setName']+'-turn'+str(turn),sample=sample,area=dict(width=2,height=2,tiles=tiles)))
cases.append(dict(name='missing-edge-table',sample=fixture['samples'][0],area=dict(width=1,height=1,tiles=[dict(id=0,orientation=0,height=0)]),loaded=False))
rows=[]
for case in cases:
 observed=[];cursor=0x20000;u.mem_write(heap,bytes(0x20000));u.mem_write(stack,bytes(0x20000));u.mem_write(0x14141e310,b'\0')
 area,set_owner,tile_data,scene,scene_vt,cells=heap+0x1000,heap+0x2000,heap+0x4000,heap+0x100,heap+0x200,heap+0x1e000
 assert tile_data+len(case['sample']['tiles'])*0xb8<=cells,'Native SET metadata and area tile arrays must be disjoint'
 wq(heap+0x400,stop+0x10);wq(scene,scene_vt);wq(scene_vt+0x30,stop+0x30)
 width=case['area']['width'];height=case['area']['height'];wi(area+0xc,width);wi(area+0x10,height)
 u.mem_write(area+0x150,case['sample']['setName'].encode()+b'\0');wq(area+0x290,set_owner);wq(area+0x298,cells);wq(area+0x248,scene);wq(set_owner+0x60,tile_data);wf(set_owner+0x4c,float(case['sample']['general']['Transition']))
 for tile in case['area']['tiles']:
  index=case['area']['tiles'].index(tile);wi(cells+index*0x60+0x14,tile['id']);wi(cells+index*0x60+0x18,tile['height']);wi(cells+index*0x60+0x24,tile['orientation'])
 for tile in case['sample']['tiles']:
  at=tile_data+tile['id']*0xb8
  for key,offset in [('TopLeft',0x38),('TopRight',0x48),('BottomLeft',0x58),('BottomRight',0x68),('Top',0x78),('Bottom',0x88),('Left',0x98),('Right',0xa8)]:string(at+offset,tile.get(key,''))
 sp=stack+0x1fe08;wq(sp,stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,area);u.reg_write(UC_X86_REG_RDX,heap+0x800);u.reg_write(UC_X86_REG_XMM2,int.from_bytes(struct.pack('<f',50),'little'))
 u.emu_start(0x1407dea10,stop,count=20000000);assert u.reg_read(UC_X86_REG_RIP)==stop,'Bounded instruction ceiling'
 rows.append(dict(name=case['name'],setName=case['sample']['setName'],loaded=case.get('loaded',True),area=case['area'],calls=observed))
assert hashlib.sha256(source.read_bytes()).hexdigest()==sha
out=root/'godot-client/reports/native-area-border-original-v2.json';assert not out.exists();out.write_text(json.dumps(dict(schema='native-area-border-original-v2',binarySha256=sha,harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope=__doc__,priorRejected='v1 constructed SET and area tile memory overlapped; corrected disjoint fixture addresses only.',rows=rows),indent=2)+'\n')
print(json.dumps(dict(rows=len(rows),calls=sum(len(row['calls'])for row in rows),output=str(out))))
