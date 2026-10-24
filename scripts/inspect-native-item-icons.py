"""Original UpdateIcons14083f6f0 through icon construction on synthetic items.
Captures resource existence, table getters, allocation and constructors; native
branching, resource naming and material/per-part palette loops execute.
"""
import sys,importlib,json,itertools,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
i=importlib.import_module('inspect-native-network-item-model');m=i.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
# Imported probes own the latest hook; replace it without remapping the source.
# The inherited services retain their verified naming and formatting helpers.
i.ranges.append((0x14083f6f0,0x1408412fe))
item=m.heap+0x90000
partsNames={6:'PELVIS',7:'CHEST',8:'BELT',14:'SHOR',15:'SHOL',18:'ROBE'}
original=i.hook
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x1401e2ca0,0x1401e2e40,0x1401e2f60,0x1401e3000]:
  if a==0x1401e2ca0:result.update(kind='armor',names=[i.cstr(y+j*17)for j in range(6)],palettes=[list(struct.unpack('<10H',bytes(u.mem_read(m.q(sp+0x28)+j*20,20))))for j in range(6)])
  elif a==0x1401e2e40:result.update(kind='composite',names=[i.cstr(p)for p in [y,z,k]])
  elif a==0x1401e3000:result.update(kind='layered',names=[i.cstr(y)],palette=list(struct.unpack('<10H',bytes(u.mem_read(k,20)))))
  else:result.update(kind='flat',names=[i.cstr(y)])
  u.emu_stop();return
 if a==0x1401a68f0:
  column=i.cstr(m.q(z));i.string(k,partsNames[y] if column=='MDLNAME' else 'spell_icon');m.finish(1);return
 if a==0x1401a7010:
  column=i.cstr(m.q(z));m.wi(k,7 if column=='ICON' else hidden);m.finish(1);return
 if a==0x14029dd60:m.finish(overrides[z&255][y&255] if(z&255)<19 and(y&255)<6 else 255);return
 if a==0x14018f590:m.finish(1);return
 if a==0x1401e30f0:u.mem_write(x,bytes(17));m.finish(x);return
 if a==0x14018dea0:
  value=i.cstr(m.q(y)).encode()[:16];u.mem_write(x,value+bytes(17-len(value)));m.finish(x);return
 if a==0x140c10324:m.finish(m.heap+0x80000);return
 original(u,a,n,data)
# Remove the imported handler and install the wrapper. Importer now exposes the
# handle explicitly so there are never two hooks executing the same service.
u.hook_del(i.hook_handle)
u.hook_add(UC_HOOK_CODE,hook)
cases=[]
for type,gender,robe,hidden in itertools.product([0,1,2,3],[70,77],[0,38],[0,1]):
 i.setup(dict(modelType=type,prefix='WSwDg',defaultModel='it_bag',variantFlag=1));result={};colors=[10,20,30,40,50,60];parts=list(range(1,19))+[robe];overrides=[[(255 if(c+p)%2 else(p*11+c)&255)for c in range(6)]for p in range(19)]
 u.mem_write(item,bytes(0x400));m.wi(item+0x258,16 if type==3 else 1);m.wi(item+0x40,16 if type==3 else 1);u.mem_write(item+8,bytes(colors));u.mem_write(item+0x1cc,struct.pack('<19H',*parts));u.mem_write(item+0x1f2,bytes([gender]));m.wi(item+0x284,1)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,item);u.emu_start(0x14083f6f0,m.stop,count=100000)
 assert result
 cases.append(dict(type=type,gender=gender,robe=robe,hidden=hidden,colors=colors,parts=parts,overrides=overrides,**result))
out=m.root/'backups/animations/native-item-icons-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=cases),indent=2)+'\n');print(json.dumps(dict(iconCases=len(cases))))
