"""Read-only original main-menu enable/DM policy70e7f0 and local-host
Save/Load predicate6daa40. Unchanged original instructions execute in Unicorn.
Captured lower boundaries: SetEnabled, string color, model texture replacement,
DM getter and network connected/localhost queries. Inputs are authored facts,
not a claim to disclose these facts in the replacement's current bridge.
No live original process, network connection or original profile is accessed.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,model,vtable,app,client,net=[m.heap+n for n in [0x1000,0x3000,0x4000,0x5000,0x6000,0x7000]]
offset_tags={0x490:'newbutton',0x2c0:'loadbutton',0x1d8:'multibutton',0x3a8:'moviesbutton',0x578:'optionsbutton',0xf0:'exitbutton',0x660:'reponewsbutton'}
sources=[json.loads((m.root/'backups/animations'/file).read_text()) for file in ['rea-native-entry-menus-v1.json','rea-native-entry-menu-actions-v1.json']]
ranges=[(int(b['start'],16),int(b['end'],16)+1) for source in sources for row in source['rows'] if row['procedure']['address'] in ['0x14070e7f0','0x1406daa40'] for b in row['procedure']['body']['ranges']]
def string(address):return bytes(u.mem_read(address,80)).split(b'\0')[0].decode('ascii')
def hook(u,address,size,_):
 if address==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if address==0x1401eb800:
  tag=offset_tags[x-panel];enabled[tag]=bool(y&0xffffffff);calls.append(['enabled',tag,bool(y&0xffffffff)]);m.finish();return
 if address==0x1401eb5c0:
  tag=offset_tags[x-panel-0xd0];color=[m.xmm(reg) for reg in [UC_X86_REG_XMM1,UC_X86_REG_XMM2,UC_X86_REG_XMM3]]+[m.rf(u.reg_read(UC_X86_REG_RSP)+0x28)]
  colors[tag]=color;calls.append(['color',tag,color]);m.finish();return
 if address==0x1406aba60:m.finish(inputs['dm']);return
 if address==m.stop+0x100:replacements.append([string(y),string(z)]);m.finish();return
 if address==0x1402376a0:calls.append(['connected']);m.finish(inputs['connected']);return
 if address==0x1402379c0:calls.append(['localhost']);m.finish(inputs['localhost']);return
 if not any(lo<=address<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original entry-menu dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,argument):
 u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,argument)
 u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return u.reg_read(UC_X86_REG_RAX)
def initialize(mode):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(0x1412df93b,bytes([mode]));m.wq(0x1412df970,app);m.wq(app,client);m.wq(panel+0x10,model);m.wq(model,vtable);m.wq(vtable+0x60,m.stop+0x100)
main=[]
for dm,mode in itertools.product([0,1],[0,1]):
 initialize(mode);inputs=dict(dm=dm);calls=[];enabled={};colors={};replacements=[];call(0x14070e7f0,panel)
 assert len(enabled)==len(offset_tags) and len(colors)==len(offset_tags)
 main.append(dict(dm=bool(dm),clientServerMode=bool(mode),enabled=enabled,colors=colors,replacements=replacements,calls=calls))
local=[]
for mode,connected,present,localhost,field in itertools.product([0,1],repeat=5):
 initialize(mode);inputs=dict(connected=connected,localhost=localhost);calls=[];m.wq(app+8,client if present else 0);m.wq(client+0x18,net);m.wi(client+0x5a4,field)
 allowed=call(0x1406daa40,client);assert allowed in [0,1]
 local.append(dict(clientServerMode=bool(mode),connected=bool(connected),appServerPresent=bool(present),localhost=bool(localhost),clientField5a4=bool(field),allowed=bool(allowed),calls=calls))
output=m.root/'backups/animations/native-entry-menu-policy-observations-v1.json';assert not output.exists(),'Preserve previous observations'
output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,main=main,localSaveLoad=local),indent=2)+'\n')
print(json.dumps(dict(output=str(output),main=len(main),localSaveLoad=len(local))))
