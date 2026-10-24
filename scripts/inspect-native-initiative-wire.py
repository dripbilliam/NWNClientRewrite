"""Whole original SendServerToPlayerCCMessage case14, real scalar/OBJECT_ID
codecs and GetWriteMessage. Data getters, string lifetime/allocator and final
transport are explicit synthetic lower services. Read-only pinned PE in Unicorn;
not an original-client gameplay or transport test.
"""
import importlib,sys,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);data=m.heap+0x40000
def hook(u,a,n,extra):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1402d57f0:assert y==0;m.finish(case['sourceId']);return
 if a==0x1402d5740:assert y in [0,1];m.finish(case['roll']if y==0 else case['modifier']);return
 if a in [0x140169560,0x1401695b0]:m.finish(x);return
 if a==0x1404dc490:
  ptr=m.q(sp+0x28);length=m.si(sp+0x30)&0xffffffff;packets.append((bytes([80,z&255,k&255])+bytes(u.mem_read(ptr,length))[3:]).hex());m.finish(1);return
 if 0x1404cf090<=a<=0x1404d0b50 or 0x1402dacb0<=a<0x1402dad90:return
 t.hook(u,a,n,extra)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for fmt,source,roll,modifier in itertools.product([0,1],[99,0xffffffff,0xfffffffe,0x7f000000],[0,1,20,31,32,255],[-129,-128,-1,0,1,127,128,255]):
 case=dict(format=fmt,sourceId=source,roll=roll,modifier=modifier);packets=[];t.reset(dict(format=fmt));result=w.call(0x1404cf090,[w.message,0x80000001,14,data]);assert len(packets)==1 and result==1;rows.append(dict(case=case,packet=packets[0]))
out=m.root/'backups/animations/native-network-initiative-wire.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
