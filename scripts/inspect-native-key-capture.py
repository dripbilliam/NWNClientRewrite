"""Execute unchanged original key capture, remappability and label-table setup.
OS event preprocessing, queue publication, allocator, critical-section and
vector-constructor boundaries are captured. No OS input, original process,
profile or network is touched. Uninitialized native slot105 is deliberately
sentinel-filled, not emulated as a reliable key. This is not full UI acceptance.
"""
import importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
source=json.loads((m.root/'backups/animations/rea-native-key-settings-v1.json').read_text())
names={'0x14016ecb0','0x14016f880','0x1401703e0','0x140170490','0x14016eb90','0x1408bb490'}
ranges=[(int(b['start'],16),int(b['end'],16)+1) for row in source['dossiers'] if row['result'].get('procedure',{}).get('address') in names for b in row['result']['procedure']['body']['ranges']]
input_obj=m.heap+0x1000;wrapper=m.heap+0x4000;panel=m.heap+0x6000;event=m.heap+0x9000
allocation=0;published=[];boundaries={}
def hook(u,address,size,_):
 global allocation
 if address==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if address in [0x140c10324,0x140c10368]:
  ptr=m.heap+0x10000+allocation*0x1000;allocation+=1;assert allocation<100;m.finish(ptr);return
 if address in [0x140c11414,0x140164cd0,0x140c10370,0x140a6f930,0x140c10410]:
  boundaries[hex(address)]=boundaries.get(hex(address),0)+1;m.finish();return
 if address==0x14016fc30:published.append([y,z]);m.finish(1);return
 if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured key dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,first=0,second=0):
 u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RCX,first),(UC_X86_REG_RDX,second)]:u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)&0xffffffff
u.mem_write(input_obj,bytes([0xa5])*0x1000);call(0x14016ecb0,input_obj)
mapping=[m.si(input_obj+0x58+index*4) for index in range(106)]
m.wq(wrapper+8,input_obj)
call(0x1408bb490,panel)
labels=[dict(code=m.si(panel+0x508+index*8),strRef=m.si(panel+0x50c+index*8)) for index in range(67)]
remappable=[dict(code=code,result=call(0x140170490,input_obj,code)) for code in range(256)]
captures=[]
for enabled in [0,1]:
 for modifiers in [0,3,0xc0]:
  for scan in range(512):
   call(0x14016eb90,wrapper,enabled);published.clear();u.mem_write(event,bytes(64))
   m.wi(event,0x300);m.wi(event+0x10,scan);m.wi(event+0x18,modifiers)
   result=call(0x14016f880,input_obj,event);native=call(0x1401703e0,input_obj)
   captures.append(dict(enabled=enabled,modifiers=modifiers,scan=scan,captured=native,raw=struct.unpack('<H',u.mem_read(input_obj+0x258,2))[0],result=result,published=published.copy()))
# Release-only events cannot become an assignment; Alt+Enter remains reserved.
special=[]
for event_type,scan,symbol,modifiers in [(0x301,4,97,0),(0x300,40,13,0x300),(0x300,41,27,0),(0x300,53,96,0)]:
 call(0x14016eb90,wrapper,1);published.clear();u.mem_write(event,bytes(64));m.wi(event,event_type);m.wi(event+0x10,scan);m.wi(event+0x14,symbol);m.wi(event+0x18,modifiers)
 result=call(0x14016f880,input_obj,event);special.append(dict(eventType=event_type,scan=scan,symbol=symbol,modifiers=modifiers,captured=call(0x1401703e0,input_obj),result=result,published=published.copy()))
out=m.root/'backups/animations/native-key-capture-observations-v1.json';assert not out.exists(),'Preserve prior observations'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,boundaries=boundaries,nativeToSDL=mapping,labels=labels,remappable=remappable,captures=captures,special=special),indent=2)+'\n')
print(json.dumps(dict(output=str(out),labels=len(labels),remappable=len(remappable),captures=len(captures),special=len(special))))
