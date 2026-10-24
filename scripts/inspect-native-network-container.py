"""Complete original bag-use/close/page writers and server status writer.
Real scalar/OBJECT_ID codecs, captured transport; no live changes or assets.
Server close/page action ownership has separate native-container-input evidence.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[(0x1409737f0,0x140973838)]
for name in ['open-request','close-request','page-request','prev-request','server-status']:
 d=json.loads((m.root/f'backups/animations/rea-container-{name}.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
player=m.heap+0xe0000
def hook(u,a,n,data):
 sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;ptr=u.reg_read(UC_X86_REG_R9)
  packets.append(bytes([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255])+(bytes(u.mem_read(ptr,size))[3:]if size else b''));m.finish(1);return
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;ptr=m.q(sp+0x28)
  packets.append(bytes([80,u.reg_read(UC_X86_REG_R8)&255,u.reg_read(UC_X86_REG_R9)&255])+bytes(u.mem_read(ptr,size))[3:]);m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for fmt,kind,target,primary in itertools.product([0,1],['open','close','status'],[0,0x7f000000,0x80000001,0xffffffff],[0,1]):
 packets=[];t.reset(dict(format=fmt));m.wi(player+0x48,7)
 if kind=='open':w.call(0x1407c07c0,[w.message,target,0,0])
 elif kind=='close':w.call(0x1407bdeb0,[w.message,target])
 else:w.call(0x1404d9c30,[w.message,player,target,primary])
 assert len(packets)==1;rows.append(dict(format=fmt,kind=kind,targetId=target,primary=primary,packet=packets[0].hex()))
for address,direction in [(0x1407bde70,1),(0x1407bde90,-1)]:
 packets=[];t.reset(dict(format=1));w.call(address,[w.message]);assert len(packets)==1
 rows.append(dict(format=1,kind='page',direction=direction,packet=packets[0].hex()))
out=m.root/'backups/animations/native-network-container-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
