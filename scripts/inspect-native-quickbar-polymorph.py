"""Original complete type43 widget activation85c8f0 ->804cc0 ->7bf460.

The real widget disabled branch, controlled-creature/message availability,
actor-ID selection, native message constructor/writers and packet extraction
execute. Only object/message lookups, transport and stack-cookie boundary are
captured. No effect/state gate is invented from server-only fields. The widget
setter's bounded original assembly separately proves fixed icon/TLK and mode
animation conditions; it is static evidence, not rendered pixels. No live
process/network/GPU, credentials or original asset publication.
"""
import importlib,itertools,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP
from capstone import Cs,CS_ARCH_X86,CS_MODE_64
u.hook_del(t.hook_handle)
evidence=json.loads((m.root/'godot-client/reports/native-quickbar-context-research-v5.json').read_text());assert evidence['binarySha256']==m.digest
ranges=[]
for row in evidence['records']:
 ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in row['procedure']['body']['ranges'])
client_writer=json.loads((m.root/'backups/animations/rea-network-client-objectid-writer.json').read_text())['structuredContent']['raw_result']['value']['procedure']
ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in client_writer['body']['ranges'])
widget,actor=m.heap+0x60000,m.heap+0x64000
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1406ac1a0:calls.append('controlled-creature');m.finish(0 if c['noActor']else actor);return
 if a==0x1406abf90:calls.append('message-owner');m.finish(0 if c['noMessage']else w.message);return
 if a==0x1407c25c0:
  packet=bytearray(u.mem_read(k,m.si(sp+0x28)&0xffffffff));packet[:3]=bytes([112,y&255,z&255]);packets.append(bytes(packet).hex());m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format,actor_id,flags,no_actor,no_message,int_param in itertools.product([0,1],[0,0x7f000000,0x80000002,0xffffffff],[0,1,2,3],[False,True],[False,True],[-1,123]):
 c=dict(format=format,actorId=actor_id,widgetFlags=flags,noActor=no_actor,noMessage=no_message,intParam=int_param);calls=[];packets=[];t.reset(dict(format=format));u.mem_write(widget,bytes(0x1000));u.mem_write(actor,bytes(0x1000));m.wi(widget+8,flags);u.mem_write(widget+0x140,bytes([43]));m.wi(widget+0x118,int_param);m.wi(actor+8,actor_id)
 w.call(0x14085c8f0,[widget]);rows.append(dict(case=c,calls=list(calls),packets=list(packets)))
cs=Cs(CS_ARCH_X86,CS_MODE_64);setter=[hex(i.address)+': '+i.mnemonic+' '+i.op_str for i in cs.disasm(m.pe.get_data(0x861350,0x1d7),0x140861350)]
assert setter[-1].endswith('ret ')
output=m.root/'backups/animations/native-quickbar-polymorph-observations-v1.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows,setterAssembly=setter,setterIcon='IR_SKILLSELF',setterLabelRef=8272,modeAnimation={'clientPolymorphField':'408','clientLockField':'40c','condition':'408 != 0 && 40c == 0; qbMode animation only, no activation gate'}),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
