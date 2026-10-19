"""Complete original quickbar server sender4d9da0 and client dispatcher79d980/
entry79db00 using real scalar/string/resref writers/readers. Item lookups are
absent in this fixture; embedded item resources have separate inventory oracles
and live packet replays. Player/GUI/empty-map/string-copy/allocator services are
captured lowers. No UI renderer, local gameplay, transport or assets copied.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
t.readSource=[]
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,vt,player,buttons,gui,input_,strings=[m.heap+n*0x1000 for n in [3,4,5,6,9,20,30]]
ranges=[(0x140392f60,0x140392f80),(0x1409737c0,0x1409737e8)]
for name in ['rea-network-quickbar-set-button-writer','rea-network-quickbar-client-dispatch','rea-network-quickbar-client-set-button','rea-network-quickbar-string-left','rea-network-ranged-resref-assignment']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['procedure']['body']['ranges'])
case={};packet=None;calls=[];head=m.heap+0xa0000
def string(p):return bytes(u.mem_read(m.q(p),m.si(p+8))).decode('cp1252')if m.q(p)else''
def text(p,s,at):b=s.encode('cp1252');u.mem_write(at,b+b'\0');m.wq(p,at);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def wb(p,v):u.mem_write(p,bytes([v&255]))
def hook(u,a,n,data):
 global packet,head
 x,y,z,v=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404ba840:m.finish(actor);return
 if a==m.stop+0x60:m.finish(actor);return
 if a==0x14055b6c0:m.finish(0);return
 if a==0x1406abbc0:m.finish(gui);return
 if a==0x1404dc490:
  length=m.si(sp+0x30)&0xffffffff;raw=bytes(u.mem_read(m.q(sp+0x28),length));packet=bytes([80,z&255,v&255])+raw[3:];m.finish(1);return
 if a==0x140368530:m.wq(x,head);m.wq(head,head);m.wq(head+8,head);m.wq(head+16,head);head+=0x300;m.finish(head-0x300);return
 if a in [0x140369860,0x14011b210]:m.finish();return
 if a==0x1400f4e30:m.wq(x,0);m.wq(x+8,0);m.finish(x);return
 if a in [0x1401881e0,0x14019e620]:u.mem_write(x,bytes(u.mem_read(y,16)));m.finish(x);return
 if 0x140860000<=a<0x14086e000:
  if a==0x14086d2b0:m.finish();return
  c=dict(index=y&255,type=case['type'],function=hex(a))
  if case['type']==2:c.update(classIndex=z&255,spellId=v&0xffffffff,field55=m.si(sp+0x28)&255,field54=m.si(sp+0x30)&255)
  elif case['type']==1:c.update(itemId=z&0xffffffff,intParam=v&0xffffffff,secondId=m.si(sp+0x28)&0xffffffff)
  elif case['type']in [11,12,13,14,15,16,17]:c.update(resRef=bytes(u.mem_read(z,16)).split(b'\0')[0].decode(),toolTip=string(v))
  elif case['type']==18:c.update(commandLabel=string(z),commandLine=string(v))
  elif case['type']in [29,30]:c['resRef']=bytes(u.mem_read(z,16)).split(b'\0')[0].decode()
  elif case['type']==39:c.update(intParam=z&0xffffffff,associateType=v&65535,associateId=m.si(sp+0x28)&0xffffffff)
  elif case['type']==44:c.update(spellId=z&0xffffffff,domainLevel=v&255)
  elif case['type']in [3,4,8,10,27,28,31,32,33,34,37,42,43,45,46,47,48]:c['intParam']=z&0xffffffff
  calls.append(c);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format_,type_,full,index in itertools.product([0,1],[i for i in range(49)if i not in [5,9,26]],[False,True],[0,35]):
 case=dict(format=format_,type=type_,full=full,index=index);t.reset(dict(format=format_));packet=None;calls=[];head=m.heap+0xa0000;m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x60);m.wq(actor+0x4e0,buttons);m.wi(player+0x48,7);m.wq(gui+0x60,gui+0x100)
 for i in range(36):
  p=buttons+i*0x60;wb(p+8,type_);wb(p+9,7);m.wi(p+0x50,0x81234567);wb(p+0x54,0x81);wb(p+0x55,9);u.mem_write(p+0x56,struct.pack('<H',0xabcd));m.wi(p+0x58,0x7fffffff);u.mem_write(p+10,b'fixture_ref\0'+bytes(5));text(p+0x20,'Label',strings);text(p+0x30,'Command',strings+100);text(p+0x40,'Tooltip',strings+200)
 w.call(0x1404d9da0,[w.message,player,index,int(full)]);assert packet[:2]==bytes([80,30]);u.mem_write(input_,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1);w.call(0x1402da7b0,[w.message,input_,len(packet)-3,0xffffffff])
 try:result=w.call(0x14079d980,[w.message,packet[2]])
 except Exception:print(json.dumps(dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert result==1;assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 rows.append(dict(case=case,packet=packet.hex(),calls=calls))
out=m.root/'backups/animations/native-network-quickbar-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
