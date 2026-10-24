"""Whole original CC8 server writer with real native scalar/OBJECT_ID/string/
localized encoders and GetWriteMessage. CC data/item lookup, CExoString copies,
cleanup, allocator and final transport are fixture lower providers. Synthetic
memory only. Client decode/formatting is checked separately against these bytes.
"""
import sys,importlib,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
data,item,raw=m.heap+0x40000,m.heap+0x42000,m.heap+0x44000

def hook(u,a,n,extra):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402d5740:m.finish([case['spellId'],case['identified'],case['casting'],case['baseItem']][y&0xffffffff]);return
 if a==0x1402d57f0:m.finish([case['sourceId'],0x7f000000 if case['item']=='none'else 100][y&0xffffffff]);return
 if a==0x14055b6c0:m.finish(item);return
 if a in [0x140169560,0x1401695b0]:m.finish(x);return
 if a in [0x140169600,0x14019e620]:u.mem_write(x,bytes(u.mem_read(y,16)));m.finish(x);return
 if a==0x1404dc490:
  ptr=m.q(sp+0x28);length=m.si(sp+0x30)&0xffffffff
  packets.append((bytes([80,z&255,k&255])+bytes(u.mem_read(ptr,length))[3:]).hex());m.finish(1);return
 if 0x1404cf090<=a<=0x1404d0b50:return
 t.hook(u,a,n,extra)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for source,spell,identified,casting,variant in itertools.product([99,0xffffffff,0x7f000000],[37,0xffffffff,0x80000000],[0,1],[0,1],['none','base','override','localized-ref','localized-inline']):
 case=dict(sourceId=source,spellId=spell,identified=identified,casting=casting,item=variant,baseItem=0x123)
 packets=[];t.reset(dict(format=1));name=b'Native item \x80\xe9'
 if variant=='override':u.mem_write(raw,name);m.wq(item+0x430,raw);m.wi(item+0x438,len(name));m.wi(item+0x43c,len(name)+1)
 else:t.populateLoc(item+0x420,dict(strRef=123 if variant=='localized-ref'else 0xffffffff,entries=[]if variant=='localized-ref'else[dict(key=0,hex=name.hex())]))
 m.wq(m.stack+0x1fe30,0)
 try:result=w.call(0x1404cf090,[w.message,0x80000001,8,data])
 except Exception:print(json.dumps(dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert len(packets)==1 and result==1
 rows.append(dict(case=case,packet=packets[0],itemTextHex=name.hex()))
out=m.root/'backups/animations/native-network-spell-feedback-wire.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
