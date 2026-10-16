"""Untouched player message18 conversion admission14045498f..140454ba7.
Earlier packet decoding, actor/area and target-mask checks are outside this
fixture. Capture class/spell/slot queries, action manager and queue boundaries.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,stats,spell,master,rules,classes,frame=[m.heap+n*0x1000 for n in range(1,8)]
def hook(u,a,n,_):
 if a in [m.stop,0x140453780]:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1403fa4a0:m.finish(c['classType'])
 elif a==0x140409160:calls.append(['uses',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&255]);m.finish(c['uses'])
 elif a==0x1402af530:m.finish(c['level'])
 elif a==0x1402a3f70:m.finish(c['cost'])
 elif a==0x140405770:m.finish(len(c['slots']))
 elif a in [0x140404db0,0x140402ff0]:row=c['slots'][w&255];m.finish((row or {}).get('ready' if a==0x140404db0 else 'domain',0))
 elif a==0x1402af4a0:m.finish(0 if c['missingMaster'] else master)
 elif a==0x14037cbc0:calls.append(['manager',y&0xffffffff]);m.finish()
 elif a==0x140453772:calls.append(['feedback',y&0xffffffff]);u.emu_stop()
 elif a==0x14037d540:
  calls.append(['cast',y&0xffffffff,z&255,w&255,m.si(rsp+0x28)&255,m.si(rsp+0x30),list(struct.unpack('<3f',u.mem_read(m.q(rsp+0x38),12))),m.si(rsp+0x40)&0xffffffff,m.si(rsp+0x48)]);m.finish()
 elif not 0x14045498f<=a<0x140454ba7:raise AssertionError(f'Uncaptured {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df8f8,rules);m.wq(rules+0x110,classes);m.wi(classes+10*0x530+0x520,c['classAllows']);m.wi(spell+0x178,2);u.mem_write(master+0x18c,bytes([c['allowedMeta']]));
 for offset,v in [(-0x64,c['spontaneous']),(-0x68,1),(-0x40,100),(-0x60,0)]:m.wi(frame+offset,v)
 for offset,v in [(-0x7f,0),(-0x80,c['domain']),(0x208,c['meta'])]:u.mem_write(frame+offset,bytes([v]))
 m.wq(frame-0x58,spell);u.mem_write(frame-0x78,struct.pack('<3f',1,2,3));rsp=m.stack+0x1fe08;u.mem_write(rsp-0x100,bytes(0x200));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RBP,UC_X86_REG_R12,UC_X86_REG_R15,UC_X86_REG_R14,UC_X86_REG_RSI,UC_X86_REG_RBX],[frame,stats,actor,1,0,100]):u.reg_write(reg,v)
 u.emu_start(0x14045498f,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP) in [0x140453780,0x140453772,m.stop]
 return dict(case=c,calls=calls)
rows=[]
for requested,uses,cls,allows,meta,allowed,domain,slots in itertools.product([0,1,2],[0,1],[10,255],[0,1],[0,16],[0,16],[0,2],[[],[None],[dict(ready=1,domain=1)],[dict(ready=0,domain=0),dict(ready=1,domain=0)]]):
 rows.append(run(dict(spontaneous=requested,uses=uses,classType=cls,classAllows=allows,meta=meta,allowedMeta=allowed,domain=domain,slots=slots,level=1,cost=1 if meta else 0,missingMaster=False)))
out=m.root/'backups/animations/native-spell-input-conversion-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
