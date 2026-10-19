"""Original client assignment emitters -> complete original server30/2 reader
and typed quickbar setters. Player/creature/spell lookup and transport are
captured lower boundaries; scalar and canonical ID readers/writers execute.
Stored fields retain GFF native names:54 QBMetaType,55 QBDomainLevel. Client
sender7bee70 takes field55 as argument5 and field54 as argument6, then emits54/55.
No actual UI, server process mutation, gameplay or credential material involved.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,vt,player,buttons,input_=[m.heap+n*0x1000 for n in [3,4,5,6,20]]
ranges=[(0x1409737f0,0x140973845),(0x1403a3f80,0x1403a40d9),(0x1403a3a50,0x1403a3a9b)]
for name in ['int','empty','item','spell','ability','associate']:
 d=json.loads((m.root/f'backups/animations/rea-network-quickbar-client-{name}-sender.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['procedure']['body']['ranges'])
for name in ['rea-network-quickbar-server-dispatch']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['procedure']['body']['ranges'])
ranges.append((0x1404521d0,0x140452b96));packet=None;case={}
def hook(u,a,n,data):
 global packet
 x,y,z,v=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407c25c0:
  length=m.si(sp+0x28)&0xffffffff;raw=bytes(u.mem_read(v,length));packet=bytes([112,y&255,z&255])+raw[3:];m.finish(1);return
 if a==0x1404ba840:m.finish(actor);return
 if a==m.stop+0x60:m.finish(actor);return
 if a==0x1402af4a0:m.finish(m.heap+0x9000);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
extended='--associate-extension'in sys.argv
for format_,type_,index,value,second in itertools.product([0,1],[38,39,42]if extended else[0,6,3,4,10,37,1,2,44],[0,35],[-2147483648,0,0x1234567],[1,2,3]if extended else[0x7f000000,0xffffffff]):
 case=dict(format=format_,type=type_,index=index,intParam=value,itemId=0xffffffff,secondaryItemId=second,classIndex=7,metamagic=33,domainLevel=9);t.reset(dict(format=format_));packet=None;m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x60);m.wq(actor+0x4e0,buttons);m.wq(0x1412df8f8,m.heap+0xa000)
 sp=m.stack+0x1fe08
 if type_ in [0,6,38]:entry=0x1407becd0;args=[w.message,index,type_]
 elif type_ in [3,4,10,37,42]:entry=0x1407bec10;args=[w.message,index,type_,value]
 elif type_==39:entry=0x1407be1d0;args=[w.message,index,value,second];m.wi(sp+0x28,0xffffffff);case.update(associateId=0xffffffff,associateType=second)
 elif type_==1:entry=0x1407bed80;args=[w.message,index,0xffffffff,value];m.wi(sp+0x28,second)
 elif type_==2:entry=0x1407bee70;args=[w.message,index,7,value];m.wi(sp+0x28,9);m.wi(sp+0x30,33)
 else:entry=0x1407bef70;args=[w.message,index,value,9]
 w.call(entry,args);assert packet[:3]==bytes([112,30,2]);u.mem_write(input_,packet[3:]);m.wi(sp+0x28,1);w.call(0x1402da7b0,[w.message,input_,len(packet)-3,0xffffffff]);w.call(0x140452030,[w.message,player,2]);assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 p=buttons+index*0x60;result=dict(type=u.mem_read(p+8,1)[0],itemId=m.si(p)&0xffffffff,secondaryItemId=m.si(p+4)&0xffffffff,classIndex=u.mem_read(p+9,1)[0],intParam=m.si(p+0x50),metamagic=u.mem_read(p+0x54,1)[0],domainLevel=u.mem_read(p+0x55,1)[0]);
 if type_==39:result.update(associateType=int.from_bytes(u.mem_read(p+0x56,2),'little'),associateId=m.si(p+0x58)&0xffffffff)
 rows.append(dict(case=case,packet=packet.hex(),result=result))
out=m.root/('backups/animations/native-network-associate-shortcut-request-observations.json'if extended else'backups/animations/native-network-quickbar-request-observations.json');out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
