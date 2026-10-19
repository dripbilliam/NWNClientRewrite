"""Unchanged native prepare/clear writers with real CNWMessage scalar codec.
Transport is captured; heap allocations have known A5 fill. No live writes.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
def hook(u,a,n,data):
 if a==0x1407c25c0:
  sp=u.reg_read(UC_X86_REG_RSP);size=m.si(sp+0x28)&0xffffffff;ptr=u.reg_read(UC_X86_REG_R9)
  packets.append(bytes([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255])+bytes(u.mem_read(ptr,size))[3:]);m.finish(1);return
 if 0x1407c3870<=a<0x1407c3a24:return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global packets
 packets=[];t.reset({'format':1});sp=m.stack+0x1fe08
 if c['clear']:w.call(0x1407c3960,[w.message,c['classIndex'],c['level'],c['slot']])
 else:
  m.wi(sp+0x28,c['domainLevel']);m.wi(sp+0x30,c['metamagic']);w.call(0x1407c3870,[w.message,c['classIndex'],c['spellId'],c['slot']])
 assert len(packets)==1
 return {'case':c,'packet':packets[0].hex()}
cases=[dict(clear=False,classIndex=i,spellId=id,slot=s,domainLevel=d,metamagic=meta)for i,id,s,d,meta in itertools.product([0,7,255],[0,0x12345678,0xffffffff],[0,255],[0,9,255],[0,4,63,255])]
cases += [dict(clear=True,classIndex=i,level=l,slot=s)for i,l,s in itertools.product([0,7,255],[0,9,255],[0,255])]
out=m.root/'backups/animations/native-spellbook-request-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=[run(c)for c in cases]),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(out))))
