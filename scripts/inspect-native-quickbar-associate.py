"""Original bound39 wrapper packing and widget -> 7bf0e0 activation.

Executes original8693b0 packing up to the real860760 setter boundary and full
85c8f0 activation/7bf0e0/scalar OBJECT_ID writer. Object/message lookup,
transport and stack-cookie/allocator boundaries are captured, not gameplay.
Static retained860760/9ab4d0 evidence separately covers icon/TLK selection;
this corpus does not claim rendered pixels or original server AI outcomes.
"""
import importlib,itertools,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP
u.hook_del(t.hook_handle)
evidence=json.loads((m.root/'godot-client/reports/native-quickbar-context-research-v5.json').read_text());assert evidence['binarySha256']==m.digest
ranges=[]
for row in evidence['records']:
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in row['procedure']['body']['ranges'])
for file in ['rea-network-associate-command-sender.json','rea-network-client-objectid-writer.json']:
 record=json.loads((m.root/'backups/animations'/file).read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in record['procedure']['body']['ranges'])
widget,actor,bar=m.heap+0x60000,m.heap+0x64000,m.heap+0x70000
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140860760:
  calls.append(dict(kind='setter',widget=x,packed=y&0xffffffff,associateId=m.si(x+0xe8)&0xffffffff));m.finish();return
 if a==0x1406ac1a0:calls.append(dict(kind='controlled'));m.finish(0 if c.get('noActor')else actor);return
 if a==0x1406abf90:calls.append(dict(kind='message'));m.finish(0 if c.get('noMessage')else w.message);return
 if a==0x1407bf0e0:calls.append(dict(kind='sender',targetId=y&0xffffffff,command=(z&0xffffffff)-(0x100000000 if z&0x80000000 else 0)))
 if a==0x1407c25c0:
  packet=bytearray(u.mem_read(k,m.si(sp+0x28)&0xffffffff));packet[:3]=bytes([112,y&255,z&255]);packets.append(bytes(packet).hex());m.finish(1);return
 if a==0x1408693b0 or 0x1408693b0<=a<=0x1408693e1 or any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
commands=[-65537,-32769,-20,-19,-18,-9,-8,0,32767,32768,65535,65536]
packing=[]
for slot,command,associate_type,associate_id in itertools.product([0,35,255],commands,[0,1,2,3,4,65535],[0x7f000000,0x80000002]):
 c={};calls=[];packets=[];t.reset(dict(format=1));u.mem_write(bar,bytes(0x30000));sp=m.stack+0x1fe08;m.wi(sp+0x28,associate_id)
 w.call(0x1408693b0,[bar,slot,command,associate_type]);expected=bar+0xf0+slot*0x2c8
 assert calls==[dict(kind='setter',widget=expected,packed=((command&65535)<<16)|associate_type,associateId=associate_id)]
 packing.append(dict(slot=slot,command=command,associateType=associate_type,associateId=associate_id,packed=calls[0]['packed']))
rows=[]
for format,associate_type,command,flags,no_actor,no_message in itertools.product([0,1],[0,1,2,3,4,65535],commands,[0,1,2],[False,True],[False,True]):
 c=dict(format=format,associateType=associate_type,command=command,widgetFlags=flags,noActor=no_actor,noMessage=no_message);calls=[];packets=[];t.reset(dict(format=format));u.mem_write(widget,bytes(0x1000));u.mem_write(actor,bytes(0x1000));m.wi(widget+8,flags);u.mem_write(widget+0x140,bytes([39]));m.wi(widget+0x118,((command&65535)<<16)|associate_type);m.wi(widget+0xe8,0x80000002);m.wi(actor+0x278,0xffffffff);m.wi(actor+0x27c,0x7f000000)
 w.call(0x14085c8f0,[widget]);rows.append(dict(case=c,calls=list(calls),packets=list(packets)))
out=m.root/'backups/animations/native-quickbar-associate-observations-v1.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,packing=packing,cases=rows),indent=2)+'\n');print(json.dumps(dict(packing=len(packing),cases=len(rows),output=str(out))))
