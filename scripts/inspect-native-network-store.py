"""Complete original store request/open/transaction writers, real scalar codecs.
Object lookup, customer-rate queries and transport are captured lower boundaries.
No original process/binary changes. A transaction intentionally has no success bit.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
ranges=[(0x1409737f0,0x140973838),(0x1402db790,0x1402db86b)]
names=['buy-request-current','sell-request-current','page-request-current','category-request-current','identify-request-verified','close-request-verified','server-open-writer-current','server-transaction-writer-current','close-writer-current']
for name in names:
 d=json.loads((m.root/f'backups/animations/rea-store-{name}.json').read_text())['structuredContent']['normalized_result']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
player,store,actor,values=[m.heap+x for x in [0xc8000,0xc9000,0xca000,0xcb000]]
def hook(u,a,n,data):
 sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;ptr=u.reg_read(UC_X86_REG_R9);packets.append(bytes([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255])+(bytes(u.mem_read(ptr,size))[3:]if size else b''));m.finish(1);return
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;ptr=m.q(sp+0x28);packets.append(bytes([80,u.reg_read(UC_X86_REG_R8)&255,u.reg_read(UC_X86_REG_R9)&255])+(bytes(u.mem_read(ptr,size))[3:]if size else b''));m.finish(1);return
 if a==0x1406abc80:m.finish(0);return
 if a==0x14055b9d0:m.finish(store);return
 if a==0x1404ba840:m.finish(actor);return
 if a in [0x1404fb650,0x1404fb6e0]:m.finish(case['buyRate']if a==0x1404fb650 else case['sellRate']);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for fmt,kind,item in itertools.product([0,1],['buy','sell','identify','close','page','panel','transaction'],[0,0x7f000000,0x80000001,0xffffffff]):
 packets=[];t.reset(dict(format=fmt));m.wi(player+0x48,7)
 if kind=='buy':m.wi(m.stack+0x1fe30,0xffffffff);w.call(0x1407c3c10,[w.message,item,255,6])
 elif kind in ['sell','identify']:w.call(0x1407c3d00 if kind=='sell'else 0x1407c3a70,[w.message,item])
 elif kind=='close':w.call(0x1407c3a50,[w.message])
 elif kind in ['page','panel']:w.call(0x1407c3af0 if kind=='page'else 0x1407c3b80,[w.message,3])
 else:m.wi(m.stack+0x1fe30,-1);w.call(0x1404e08a0,[w.message,player,0,item])
 assert len(packets)==1;rows.append(dict(format=fmt,kind=kind,itemId=item,packet=packets[0].hex()))
for fmt,restricted,black,rate in itertools.product([0,1],[False,True],[False,True],[-1,50,150]):
 case=dict(buyRate=37,sellRate=rate);packets=[];t.reset(dict(format=fmt));m.wi(player+0x48,7);m.wi(actor+8,0xffffffff)
 for offset,value in [(0x378,int(black)),(0x390,100),(0x394,25000),(0x38c,-1),(0x3a0,2 if restricted else 0),(0x3b0,0 if restricted else 2)]:m.wi(store+offset,value)
 u.mem_write(store+0x37c,bytes([20]));m.wq(store+(0x398 if restricted else 0x3a8),values);m.wi(values,1);m.wi(values+4,255)
 w.call(0x1404dd920,[w.message,player,0x80000003,2]);assert len(packets)==1;rows.append(dict(format=fmt,kind='open',restricted=restricted,blackMarket=black,sellRate=rate,packet=packets[0].hex()))
out=m.root/'backups/animations/native-network-store-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
