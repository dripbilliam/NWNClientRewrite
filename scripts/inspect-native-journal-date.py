"""Unchanged original CWorldTimer::TranslateWorldTimeToString597a70.
Only allocation/free and CExoString::Format publication are captured. Original
unsigned calendar, overflow fallback, hour-byte division and varargs execute.
Authored Day/Month labels are supplied; no live game or server is touched.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
clock,out,day_label,month_label,strings=[m.heap+n for n in [0x1000,0x2000,0x3000,0x4000,0x5000]]
def text(ptr):return bytes(u.mem_read(ptr,128)).split(b'\0')[0].decode('ascii')
def hook(u,a,n,_):
 global observed
 if a==m.stop:u.emu_stop();return
 if a==0x140c10370:m.finish();return
 if a==0x14016afb0:
  rsp=u.reg_read(UC_X86_REG_RSP)
  fields=dict(day=u.reg_read(UC_X86_REG_R9)&0xffffffff,month=m.si(rsp+0x30),year=m.si(rsp+0x38),hour=m.si(rsp+0x40),minute=m.si(rsp+0x48))
  template=text(u.reg_read(UC_X86_REG_RDX));day=text(u.reg_read(UC_X86_REG_R8));month=text(m.q(rsp+0x28))
  observed=dict(parts=fields,text=template%(day,fields['day'],month,fields['month'],fields['year'],fields['hour'],fields['minute']))
  m.finish(out);return
 if not 0x140597a70<=a<=0x140597b8f:raise AssertionError(f'Uncaptured original journal formatter dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for hour,date,time in itertools.product([1,5,60,255],[0,27,28,335,336,32767*336+335,32768*336,0xffffffff],[0,59999,60000,420000,0xffffffff]):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(clock+0x2c,bytes([hour]));u.mem_write(strings,b'Day\0Month\0');m.wq(day_label,strings);m.wq(month_label,strings+4)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);m.wq(rsp+0x28,day_label);m.wq(rsp+0x30,month_label);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[clock,out,date,time]):u.reg_write(reg,value)
 observed={};u.emu_start(0x140597a70,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;rows.append(dict(minutesPerHour=hour,date=date,time=time,output=observed))
path=m.root/'backups/animations/native-journal-date-observations-v1.json';assert not path.exists(),'Preserve previous observations'
path.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(path),rows=len(rows),target=m.digest)))
