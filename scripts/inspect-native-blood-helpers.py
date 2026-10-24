"""Whole native float acos and Gob GetAnimation time-query owners.
FP-status/domain handling, stricmp and inactive model animation lookup are
captured service boundaries. Actual run scan, float polynomial and stores run.
"""
import sys,importlib,json,struct,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent));t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
def cstring(p):return bytes(u.mem_read(p,128)).split(b'\0')[0].decode('ascii')
def hook(u,a,n,data):
 x,y=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX]]
 if a==0x140cae8e0:m.finish();return
 if a in[0x140caeb60,0x140caecb0]:u.reg_write(UC_X86_REG_XMM0,0x7fc00000);m.finish();return
 if a==0x140c9a9fc:aa,bb=cstring(x).lower(),cstring(y).lower();m.finish(0 if aa==bb else -1 if aa<bb else 1);return
 if a==0x140050f80:m.finish(0);return
 if 0x140c79a38<=a<0x140c79c87 or 0x1400510b0<=a<0x1400512b1:return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
acos=[]
values=[i/1000 for i in range(-1000,1001)]+[-2,2,float('inf'),-float('inf'),float('nan')]+[struct.unpack('<f',struct.pack('<I',v))[0]for v in[0,0x80000000,0x32ffffff,0x33000000,0x3effffff,0x3f000000,0x3f000001,0x3f7fffff,0xbf7fffff]]
for value in values:
 t.reset(dict(format=1));inputBits=struct.unpack('<I',struct.pack('<f',value))[0];u.reg_write(UC_X86_REG_XMM0,inputBits);w.call(0x140c79a38);acos.append(dict(input=inputBits,output=u.reg_read(UC_X86_REG_XMM0)&0xffffffff))
queries=[];gob=m.heap+0x6000;array=m.heap+0x7000;query=m.heap+0x7800;out=m.heap+0x7900
for runs in[[],[('impact',.25)],[('IMPACT',-.00001)],[('other',.3),('impact',.75)],[('impact',.1),('impact',.9)],[('impact',-1)]]:
 for name in['impact','IMPACT','absent']:
  t.reset(dict(format=1));m.wq(gob+0xe0,array);m.wi(gob+0xe8,len(runs));u.mem_write(query,name.encode()+b'\0')
  for i,(label,time)in enumerate(runs):run=m.heap+0x8000+i*0x100;clip=m.heap+0x9000+i*0x100;m.wq(array+i*8,run);m.wq(run,clip);m.wf(run+0x14,time);u.mem_write(clip+0x10,label.encode()+b'\0')
  result=w.call(0x1400510b0,[gob,query,out,0]);queries.append(dict(runs=runs,name=name,time=struct.unpack('<f',u.mem_read(out,4))[0],active=bool(result)))
path=m.root/'backups/animations/native-blood-helper-observations.json';path.write_text(json.dumps(dict(target=m.digest,limits=__doc__,acos=acos,queries=queries),indent=2)+'\n');print(json.dumps(dict(acos=len(acos),queries=len(queries),output=str(path))))
