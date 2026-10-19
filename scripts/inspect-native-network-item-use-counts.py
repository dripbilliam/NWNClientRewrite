"""Complete original server G/Q writer4edc50 and client7b4390 with original
scalar/OBJECTID code. Server item/property/uses queries and virtual creature cast
are captured lower owners. Original client property getter83d580, uses setter
83ef60 and stack setter83f190 execute; icon is null, GUI invalidation captured.
No local gameplay calculations, live process mutation, renderer or asset copies.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,vt,last,buttons,caches,item,client,properties,property_,gui,input_=[m.heap+n*0x1000 for n in range(3,14)]
ranges=[(0x140392f60,0x140392f80),(0x1409737c0,0x1409737e8)]
for name in ['rea-network-quickbar-uses-writer','rea-network-client-inventory-quickbar','rea-network-quickbar-client-property','rea-network-quickbar-client-use-set','rea-network-quickbar-client-charge-set','rea-network-write-char','rea-network-read-char']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['procedure']['body']['ranges'])
case={};notifications=[];clientPresent=True
def wh(p,v):u.mem_write(p,struct.pack('<H',v&65535))
def word(p):return int.from_bytes(u.mem_read(p,2),'little')
def wb(p,v):u.mem_write(p,bytes([v&255]))
def hook(u,a,n,data):
 x,y,z=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==m.stop+0x60:m.finish(actor);return
 if a==0x14055b6c0:m.finish(item);return
 if a==0x1404686d0:m.finish(0 if case['missingProperty']else property_);return
 if a==0x140469170:m.finish(case['uses']);return
 if a==0x1406abbc0:m.finish(gui);return
 if a==0x1406abc80:m.finish(client if clientPresent else 0);return
 if a==0x14029ca00:m.finish(0);return
 if a==0x14086c440:notifications.append(y&0xffffffff);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format_,type_,cost,propType,missing,propIndex,clientPresent,uses in itertools.product([0,1],[1,9],[1,3],[15,55,80],[False,True],[0,7,8,255,256,65535],[False,True],[0,17,65535]):
 case=dict(format=format_,type=type_,cost=cost,propertyType=propType,missingProperty=missing,propertyIndex=propIndex,clientPresent=clientPresent,uses=uses,stack=42);t.reset(dict(format=format_));notifications=[]
 m.wq(0x1412df8f8,m.heap+0xe000)
 m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x60);m.wq(actor+0x4e0,buttons);m.wq(last+0x268,caches);m.wi(item+0x50,0x7ffffffe);m.wi(item+0x454,42);wh(property_,propType);wh(property_+6,cost)
 for slot in [0,35]:p=buttons+slot*0x60;m.wi(p,0x7ffffffe);wb(p+8,type_);m.wi(p+0x50,propIndex)
 w.call(0x1404edc50,[w.message,actor,last]);packet=bytes.fromhex(w.snapshot()['hex']);u.mem_write(input_,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1);w.call(0x1402da7b0,[w.message,input_,len(packet)-3,0xffffffff]);assert w.call(0x1402d98d0,[w.message,8])&255==ord('G');assert w.call(0x1402d98d0,[w.message,8])&255==ord('Q')
 m.wq(gui+0x60,gui+0x100);m.wi(client+0x50,0xfffffffe);m.wi(client+0x284,99);m.wi(client+500,8);m.wq(client+0x1f8,properties);wb(client+0x27c,propIndex)
 for i in range(8):wh(properties+i*0x30,propType);wh(properties+i*0x30+6,cost);wh(client+0x26c+i*2,100+i)
 result=w.call(0x1407b4390,[w.message]);assert result==1;assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 rows.append(dict(case=case,packet=packet.hex(),stack=m.si(client+0x284),uses=[word(client+0x26c+i*2)for i in range(8)],selected=u.mem_read(client+0x27c,1)[0],notifications=notifications,cached=[word(caches+i*0x10+0xc)for i in [0,35]]))
out=m.root/'backups/animations/native-network-item-use-count-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
