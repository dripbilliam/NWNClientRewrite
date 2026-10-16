"""Original AddSpecialAttack140374da0. GetAttack and array append are
captured lower storage providers; physical remaining-attack scan, cap50 and
sequence rollover execute unchanged. No attack resolution is claimed here.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);roundstate=m.heap+0x1000;words=m.heap+0x6000;parameters=m.heap+0x7000;attacks=m.heap+0x10000
def word(a):return int.from_bytes(u.mem_read(a,2),'little')
def ww(a,v):u.mem_write(a,struct.pack('<H',v&65535))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==0x140375e40:m.finish(attacks+min(y&0xffffffff,49)*0x100)
 elif a==0x1400a1bb0:
  count=m.si(x+8);ww(m.q(x)+count*2,y);m.wi(x+8,count+1);m.finish()
 elif not 0x140374da0<=a<0x140374eee:raise AssertionError(f'Uncaptured append dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 u.mem_write(m.heap,bytes(0x100000));m.wi(roundstate+0x2f04,case['started']);u.mem_write(roundstate+0x2f2c,bytes([case['current']&255]));ww(roundstate+0x2f00,case['sequence'])
 for offset,v in zip([0x2f50,0x2f54,0x2f60,0x2f64],case['counts']):m.wi(roundstate+offset,v)
 for offset,ptr in [(0x2ee0,words),(0x2ef0,parameters)]:m.wq(roundstate+offset,ptr);m.wi(roundstate+offset+8,case['queued'])
 for i in range(case['queued']):ww(words+i*2,10+i);ww(parameters+i*2,20+i)
 for i in range(50):ww(attacks+i*0x100+0x7a,0 if case['occupied']=='none' or case['occupied']=='first' and i>0 else 9);ww(attacks+i*0x100+0x7c,255)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,roundstate);u.reg_write(UC_X86_REG_RDX,case['type']);u.emu_start(0x140374da0,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=case,sequence=word(roundstate+0x2f00),special=[word(words+i*2) for i in range(m.si(roundstate+0x2ee8))],parameters=[word(parameters+i*2) for i in range(m.si(roundstate+0x2ef8))],attacks=[[word(attacks+i*0x100+0x7a),word(attacks+i*0x100+0x7c)] for i in range(50)])
cases=[dict(started=started,queued=queued,counts=counts,current=current,occupied=occupied,sequence=sequence,type=65000) for started,queued,counts,current,occupied,sequence in itertools.product([0,1,2],[0,1,49,50],[[0,0,0,0],[2,1,0,0],[255,1,1,1]],[0,1,49,50,255],['none','first','all'],[0,65534,65535])]
rows=[run(c) for c in cases];out=m.root/'backups/animations/native-add-special-attack-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
