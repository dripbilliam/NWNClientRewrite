"""Read-only unchanged original barter rejection sender1404ceef0.
Original scalar/server-ID writers execute; only transport is captured.
"""
import sys,importlib,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
e=json.loads((m.root/'backups/animations/rea-inventory-gold-barter-v1.json').read_text())
f=next(v for v in e['functions']if v['key']=='gold_barter_reject_sender')
ranges=[(int(v['start'],16),int(v['end'],16)+1)for v in f['procedure']['body']['ranges']]
def hook(u,a,n,data):
 if a==0x1404dc490:
  sp=u.reg_read(UC_X86_REG_RSP);z,k=[u.reg_read(reg)for reg in[UC_X86_REG_R8,UC_X86_REG_R9]];p=m.q(sp+0x28);size=m.si(sp+0x30)&0xffffffff
  packet=bytearray(u.mem_read(p,size));packet[:3]=bytes([80,z&255,k&255]);sent.append(bytes(packet));m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
if __name__=='__main__':
 rows=[]
 for fmt,operation,reason,target in itertools.product([0,1],[1,5,6,7,9,13],range(1,7),[0x7f000000,0x80000002,0xffffffff]):
  sent=[];t.reset(dict(format=fmt));sp=m.stack+0x1fe08;m.wi(sp+0x28,target)
  w.call(0x1404ceef0,[w.message,0x80000001,operation,reason]);assert len(sent)==1
  rows.append(dict(case=dict(format=fmt,operation=operation,reason=reason,targetId=target),packet=sent[0].hex()))
 output=m.root/'backups/animations/native-barter-reject-observations-v1.json';assert not output.exists()
 output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=rows),indent=2));print(json.dumps(dict(output=str(output),cases=len(rows))))
