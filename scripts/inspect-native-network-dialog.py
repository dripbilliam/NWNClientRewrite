"""Original dialog reply sender7bbc50 and full server handler448a00.

Native scalar writers/readers and admission execute intact. Transport,
allocation/copy/logging, owner lookup/cast and ReplyDialog are captured lower
boundaries. Does not evaluate DLG scripts or decide which replies are available.
"""
import sys,importlib,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['network-client-dialog-reply-sender','network-dialog-request-handler','network-client-objectid-writer']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result']['procedure']
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
client,owner,vt=[m.heap+n*0x1000 for n in [10,11,12]]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  size=m.si(sp+0x28)&0xffffffff;p=bytearray(u.mem_read(k,size));p[:3]=bytes([112,y&255,z&255]);sent.append(bytes(p));m.finish(1);return
 if a==0x14055b850:m.finish(vt);return
 if a==0x140296470:m.wq(z,owner);m.finish(1 if current.get('missingOwner')else 0);return
 if a==m.stop+0x10:m.finish(0 if current.get('badCast')else x);return
 if a==0x140498df0:calls.append(dict(owner=x,playerId=y&0xffffffff,replyId=z&0xffffffff,abort=k&0xffffffff,entryId=m.si(sp+0x28)&0xffffffff));m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
cases=[dict(format=f,ownerId=o,replyId=r,abort=a,entryId=e)for f,o,r,a,e in itertools.product([0,1],[0x80000013,0xffffffff,0x7f000000],[0,32,0xffffffff],[0,1],[0,32,0xffffffff])]
cases.extend(dict(format=1,ownerId=0x80000013,replyId=0,abort=0,entryId=32,**extra)for extra in [dict(missingOwner=True),dict(badCast=True)])
for current in cases:
 sent=[];calls=[];t.reset(dict(format=current['format']));sp=m.stack+0x1fe08;m.wi(sp+0x28,current['entryId'])
 w.call(0x1407bbc50,[w.message,current['ownerId'],current['replyId'],current['abort']]);assert len(sent)==1;packet=sent[0]
 u.mem_write(t.inputBase,packet[3:]+bytes([0xa5])*128);m.wi(sp+0x28,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 u.mem_write(client,bytes(0x1000));u.mem_write(owner,bytes(0x1000));m.wi(client+0x48,17);m.wq(owner,vt);m.wq(vt+0x20,m.stop+0x10)
 result=w.call(0x140448a00,[w.message,client,3,0])
 if current.get('missingOwner')or current.get('badCast'):assert result==0 and calls==[]
 else:assert result==1 and calls==[dict(owner=owner,playerId=17,replyId=current['replyId'],abort=current['abort'],entryId=current['entryId'])]
 rows.append(dict(case=current,packet=packet.hex(),result=result,calls=list(calls),reader=r.state()))
output=m.root/'backups/animations/native-network-dialog-reply-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
