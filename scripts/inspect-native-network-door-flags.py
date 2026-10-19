"""Native BOOL packet writers and complete client door update797780.

Client object lookup, trap presentation and body shader callbacks are captured.
The original transition setter86e640 still writes1c0; the handler writes the
other state cells itself. No live process or proprietary asset changes.
"""
import sys,importlib,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['network-client-door-update','network-client-door-transition-state','network-write-char','network-read-char']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result']['procedure']
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
door,vt,body,bvt=[m.heap+n*0x1000 for n in [10,11,12,13]]
def hook(u,a,n,data):
 x,y,z=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x1406aba50:assert y&0xffffffff==0x80000002;m.finish(door);return
 if a==0x14086df40:calls.append(['trapPresentation',y&0xffffffff]);m.finish();return
 if a==m.stop+0x20:m.finish(body);return
 if a==m.stop+0x30:calls.append(['bodyTransition',z&0xffffffff]);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for flags,initialTrap in itertools.product(itertools.product([0,1],repeat=6),[0,1]):
 calls=[];t.reset(dict(format=1));w.call(0x1402dacb0,[w.message,ord('U'),8]);w.call(0x1402da960,[w.message,10,8,1]);w.call(0x1404763e0,[w.message,2]);w.call(0x1402db150,[w.message,16,32]);
 for flag in flags:w.call(0x1402da920,[w.message,flag])
 p=bytearray.fromhex(w.snapshot()['hex']);p[:3]=bytes([80,5,1]);packet=bytes(p);u.mem_write(t.inputBase,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 assert w.call(0x1402d98d0,[w.message,8])==ord('U');assert w.call(0x1402d9630,[w.message,8,1])==10;assert w.call(0x1402d9bc0,[w.message,32])==0x80000002;assert w.call(0x1402d9bc0,[w.message,32])==16
 u.mem_write(door,bytes(0x1000));m.wq(door,vt);m.wq(vt+0x140,m.stop+0x20);m.wq(body,bvt);m.wq(bvt+0x170,m.stop+0x30);m.wi(door+0x1a0,initialTrap);m.wi(door+0x194,77)
 result=w.call(0x140797780,[w.message,0x80000002,16,0]);assert result==1
 cells={hex(offset):m.si(door+offset)for offset in [0x190,0x184,0x188,0x18c,0x194,0x1c0]};assert cells=={'0x190':flags[0],'0x184':flags[2],'0x188':flags[3],'0x18c':flags[1],'0x194':flags[4]if flags[1]else 77,'0x1c0':flags[5]}
 rows.append(dict(flags=list(flags),initialTrap=initialTrap,packet=packet.hex(),cells=cells,calls=list(calls)))
output=m.root/'backups/animations/native-network-door-flags-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
