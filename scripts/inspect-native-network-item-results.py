"""Original inventory success/cancel writers and complete client79f150 reader.

Transport and GUI/controlled-object lookups are captured. Item lookup reports
absent, so the full client consumes each original packet and validates its
boundary without simulating optimistic drag widgets or native item visuals.
No live process changes or proprietary asset copies.
"""
import sys,importlib,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[];writers={}
for action in ['equip','drop','pickup','unequip','move']:
 for suffix in ['', '-cancel']:
  d=json.loads((m.root/'backups/animations'/f'rea-network-item-response-{action}{suffix}.json').read_text())['structuredContent']['raw_result']['value'];writers[action+suffix]=int(d['procedure']['address'],16);ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['procedure']['body']['ranges'])
d=json.loads((m.root/'backups/animations/rea-network-client-inventory-response.json').read_text())['structuredContent']['raw_result']['value']['procedure'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges']);ranges.append((0x1409737c0,0x1409737f0))
gui,actor=[m.heap+n*0x1000 for n in [10,11]]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404dc490:
  p=bytearray(u.mem_read(m.q(sp+0x28),m.si(sp+0x30)&0xffffffff));p[:3]=bytes([80,z&255,k&255]);sent.append(bytes(p));m.finish(1);return
 if a in [0x1406abbe0,0x1406abfd0]:lookups.append('alternate'if a==0x1406abfd0 else'primary');m.finish(gui);return
 if a in [0x1406ac1a0,0x1406ab9e0]:m.finish(actor);return
 if a==0x1406abb70:m.finish(gui);return
 if a==0x140855b10:m.finish(0);return
 if a==0x140296470:m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format,name,itemId,alternate,slot in itertools.product([0,1],writers,[2,0x7f000000,0xffffffff],[0,1],[16,0x80000000]):
 t.reset(dict(format=format));sent=[];lookups=[];sp=m.stack+0x1fe08;equip=name.startswith('equip')
 if equip:m.wi(sp+0x28,alternate)
 w.call(writers[name],[w.message,17,itemId,slot if equip else alternate]);assert len(sent)==1;packet=sent[0]
 u.mem_write(t.inputBase,packet[3:]);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 u.mem_write(gui,bytes(0x4000));u.mem_write(actor,bytes(0x1000));result=w.call(0x14079f150,[w.message,packet[2]]);assert result==1;assert lookups==['alternate'if alternate else'primary'];assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 rows.append(dict(case=dict(format=format,operation=name,itemId=itemId,alternate=alternate,slot=slot),packet=packet.hex(),result=result,lookups=lookups,reader=r.state()))
output=m.root/'backups/animations/native-network-item-results-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
