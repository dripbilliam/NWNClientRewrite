"""Unchanged CWorldTimer seconds conversion leaves140597010/140597140.
No gameplay helper interceptions. Finite stable progress domains plus NaN;
zero-day/nonadvancing infinite loops are diagnosed, not native recovery claims.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);timer=m.heap
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if not(0x140597010<=a<0x14059703c or 0x140597140<=a<0x140597177):raise AssertionError(f'Unexpected world conversion dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(value,length):
 m.wi(timer+0x34,length);result={}
 for key,address in [('day',0x140597010),('time',0x140597140)]:
  rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,timer);u.reg_write(UC_X86_REG_XMM1,int.from_bytes(struct.pack('<f',value),'little'))
  u.emu_start(address,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop;result[key]=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 return dict(value='NaN' if math.isnan(value) else value,length=length,result=result)
rows=[run(value,length) for length in [1,7200,14400,86400,4294967295] for value in [-1,0,.0001,.99999,1,1.23456,length-.001,length,length+.001,length*3.25,float('nan')]]
out=m.root/'backups/animations/native-seconds-world-delta-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
