"""Execute original conversation sizing14087dd00 and reply selection14087e750.
Text measurement, model/scrollbar operations, manager clearance and callback
publication are captured boundaries; arithmetic and branch instructions execute
unchanged. This proves sizing/selection policy, not typography or rendered pixels.
No live game or server is opened or changed.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
dialog,entry,replies,model,reply_model,index,table,entry_bounds,reply_bounds,manager,flags=[m.heap+n*0x2000 for n in range(11)]
update,bounds,get_hook,set_hook,get_position,attach,callback=[m.heap+0xe0000+n*0x100 for n in range(7)]
observed={}
def hook(u,a,n,_):
 global observed
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==callback:
  observed['callback']=struct.unpack('<i',struct.pack('<I',y&0xffffffff))[0];m.finish();return
 if a==update or a==attach:m.finish();return
 if a==bounds:m.finish(entry_bounds if x==entry else reply_bounds);return
 if a==get_hook:
  u.mem_write(z,bytes(12));m.finish(1);return
 if a==set_hook:
  if x==model:observed['replyTop']=-m.rf(z+4)*100
  m.finish(1);return
 if a==get_position:u.mem_write(y,bytes(12));m.finish(y);return
 if a==0x1406abbc0:m.finish(manager);return
 if a==0x1406f9a90:m.finish(1);return
 if a==0x1406f7c00:u.mem_write(y,bytes(12));m.wf(y+4,-case['clearance']*.01);m.finish(y);return
 if a==0x1401fb350:
  observed['height']=m.rf(dialog+0xbb8)*100;observed['time']=m.xmm(UC_X86_REG_XMM2);m.finish();return
 if a==0x1401eb430:
  observed['entryScroll' if x==dialog+0x1d8 else 'replyScroll']=True;m.finish();return
 if a==0x1401ec240:
  observed['entryScroll' if x==dialog+0x1d8 else 'replyScroll']=False;m.finish();return
 if a in [0x1401fb540,0x1401f0560,0x1401f05e0,0x1401ee2b0]:m.finish();return
 if not any(lo<=a<=hi for lo,hi in [(0x14087dd00,0x14087e1c8),(0x14087e750,0x14087e798)]):raise AssertionError(f'Uncaptured original dialog dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset():
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]:u.reg_write(reg,0)
def run(address):
 u.reg_write(UC_X86_REG_RCX,dialog);u.emu_start(address,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
flows=[]
for entry_height,reply_height,clearance in itertools.product([0,16,71.999,72,72.001,199.999,200,200.001,600],[0,16,140,200,201,400,1600],[0,399.999,400,400.001,700,960]):
 case=dict(entry=entry_height,reply=reply_height,clearance=clearance);reset();observed={}
 for ptr in [entry,replies,model,reply_model,index]:m.wq(ptr,table)
 for off,ptr in [(0xb0,update),(0xb8,bounds),(0x138,get_hook),(0x148,get_hook),(0x130,set_hook),(0x140,set_hook),(0xc0,get_position),(0x18,attach)]:m.wq(table+off,ptr)
 for off,ptr in [(0x268,entry),(0x670,replies),(0x10,model),(0x5f0,reply_model),(0xa98,index),(0x308,1),(0x710,1)]:m.wq(dialog+off,ptr)
 m.wf(entry_bounds+0x14,entry_height*.01);m.wf(reply_bounds+0x14,reply_height*.01);m.wq(0x1412df970,manager)
 run(0x14087dd00);observed['logicalHeight']=m.rf(dialog+0xbb8)*100;flows.append(dict(input=case,output=observed))
selections=[]
for count,blocked,terminal,mask,choice in itertools.product([1,3],[0,1],[0,1],[0,1,2,7],[-3,0,1,2,3]):
 reset();observed={};m.wi(dialog+0xbbc,blocked);m.wi(dialog+0x120,count);m.wi(dialog+0x138,terminal);m.wq(dialog+0x128,flags);m.wq(dialog+0xf0,manager);m.wq(dialog+0xf8,callback)
 for at in range(count):m.wi(flags+at*4,(mask>>at)&1)
 u.reg_write(UC_X86_REG_RDX,choice&0xffffffff);run(0x14087e750)
 selections.append(dict(count=count,blocked=blocked,terminal=terminal,mask=mask,choice=choice,callback=observed.get('callback')))
out=m.root/'backups/animations/native-conversation-policy-observations-v1.json';assert not out.exists(),'Preserve previous observations'
out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,flows=flows,selections=selections),indent=2));print(json.dumps(dict(output=str(out),flows=len(flows),selections=len(selections),target=m.digest)))
