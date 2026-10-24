"""Complete original7bfa80 Examine writer and real OBJECT_ID/scalar codec.
Client modal-cache lookup returns absent; transport captured. No live changes.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
d=json.loads((m.root/'backups/animations/rea-examine-client-request-writer.json').read_text())['structuredContent']['raw_result']['value'];ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]+[(0x1409737f0,0x140973838)]
def hook(u,a,n,data):
 if a==0x1406abbc0:m.finish(0);return
 if a==0x1407c25c0:
  sp=u.reg_read(UC_X86_REG_RSP);size=m.si(sp+0x28)&0xffffffff;ptr=u.reg_read(UC_X86_REG_R9);packets.append(bytes([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255])+bytes(u.mem_read(ptr,size))[3:]);m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for fmt,target in itertools.product([0,1],[0,1,0x7f000000,0x7fffffff,0x80000000,0x80000001,0xffffffff]):
 packets=[];t.reset(dict(format=fmt));w.call(0x1407bfa80,[w.message,target]);assert len(packets)==1;rows.append(dict(format=fmt,targetId=target,packet=packets[0].hex()))
out=m.root/'backups/animations/native-examine-request-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
