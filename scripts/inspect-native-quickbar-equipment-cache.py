"""Execute original79f150 unequip-result branches with disclosed item/slot state.

Original message writers/readers and800dd0 private-slot getter execute. Object,
GUI and sound lookups are fixture boundaries;7fff10 visual attachment is a
recorded call, not a simulated native body. Exact item24c retirement and calls
are observed. Separately80a770+83ef40 execute to observe attachment-owner clearing.
No live process/network/GPU, credentials, asset publication or gameplay outcomes.
"""
import importlib,itertools,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP
u.hook_del(t.hook_handle)
ranges=[];writers={}
for name in ['unequip','unequip-cancel']:
 d=json.loads((m.root/'backups/animations'/f'rea-network-item-response-{name}.json').read_text())['structuredContent']['raw_result']['value']['procedure']
 writers[name]=int(d['address'],16);ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges'])
d=json.loads((m.root/'backups/animations/rea-network-client-inventory-response.json').read_text())['structuredContent']['raw_result']['value']['procedure']
ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in d['body']['ranges']);ranges.append((0x1409737c0,0x1409737f0))
evidence=json.loads((m.root/'godot-client/reports/native-quickbar-context-research-v8.json').read_text())
for entry in evidence['functions']:
 if entry['key'] in ['0x140800dd0','0x14080a460','0x1407fff10','0x14083ef40','detachEquipment']:
  ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in entry['procedure']['body']['ranges'])
gui,actor,item,vt,widget=[m.heap+n for n in [0x60000,0x68000,0x6a000,0x6c000,0x6d000]]
old_item=m.heap+0x6e000
slots={1:0x308,2:0x30c,4:0x310,8:0x314,16:0x318,32:0x31c,64:0x320,128:0x324,256:0x328,512:0x32c,1024:0x330,2048:0x334,4096:0x338,8192:0x33c,16384:0x340,32768:0x344,65536:0x348,131072:0x34c}
client_id=0x80000002
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404dc490:
  packet=bytearray(u.mem_read(m.q(sp+0x28),m.si(sp+0x30)&0xffffffff));packet[:3]=bytes([80,z&255,k&255]);sent.append(bytes(packet));m.finish(1);return
 if a in [0x1406abbe0,0x1406abfd0]:calls.append(dict(kind='gui-owner',alternate=a==0x1406abfd0));m.finish(gui);return
 if a in [0x1406ac1a0,0x1406ab9e0]:m.finish(0 if c.get('noActor')else actor);return
 if a==0x1406abb70:m.finish(gui);return
 if a==0x140296470:
  calls.append(dict(kind='object-lookup',id=y&0xffffffff));m.wq(z,(old_item if y&0xffffffff==0x80000003 else item)+0x48);m.finish(1 if c.get('missingItem')else 0);return
 if a==m.stop+0x10:m.finish(x-0x48);return
 if a in [m.stop+0x20,m.stop+0x30]:m.finish(0);return
 if a==0x140855b10:m.finish(widget if c.get('widget')else 0);return
 if a==0x14083d850:m.finish(item);return
 if a==0x140880130:calls.append(dict(kind='repository-widget-lookup'));m.finish(0);return
 if a==0x1407fff10 and not c.get('attachmentBody'):calls.append(dict(kind='equipment-set',slot=y&0xffffffff,item=client_id if z==item else None));m.finish();return
 if a==0x1408828a0:calls.append(dict(kind='widget-clear'));m.finish();return
 if a==0x14083ea00:calls.append(dict(kind='sound'));m.finish();return
 if a==0x14076b760:calls.append(dict(kind='gui-repair'));m.finish();return
 if a in [0x140811000,0x140811190,0x1408075d0,0x140764300]:m.finish(0);return
 if a==0x140763220:m.finish(0);return
 if a==0x1406ac1c0:m.finish(0x80000099);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format,success,slot,match,alternate,widget_present in itertools.product([0,1],[False,True],[1,2,16,32,65536,-1],[False,True],[0,1],[False,True]):
 c=dict(format=format,success=success,slot=slot,match=match,alternate=alternate,widget=widget_present);sent=[];calls=[];t.reset(c)
 w.call(writers['unequip'if success else'unequip-cancel'],[w.message,17,2,alternate]);assert len(sent)==1;packet=sent[0]
 u.mem_write(t.inputBase,packet[3:]);m.wi(m.stack+0x1fe30,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 for p,size in [(gui,0x4000),(actor,0x1000),(item,0x1000),(vt,0x1000),(widget,0x1000)]:u.mem_write(p,bytes(size))
 for offset in slots.values():m.wi(actor+offset,0x7f000000)
 if slot in slots:m.wi(actor+slots[slot],client_id if match else 0x80000003)
 m.wq(item+0x48,vt);m.wq(vt+0x68,m.stop+0x10);m.wi(item+0x50,client_id);m.wi(item+0x24c,slot);m.wi(item+0x25c,0xffffffff);m.wi(widget+0x174,client_id)
 result=w.call(0x14079f150,[w.message,packet[2]]);assert result==1
 assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 rows.append(dict(case=c,packet=packet.hex(),result=result,cachedGuiSlot=m.si(item+0x24c),attachmentOwner=m.si(item+0x25c)&0xffffffff,calls=list(calls),reader=r.state()))
detach=[]
for missingItem,itemId in itertools.product([False,True],[0x7f000000,client_id]):
 c=dict(missingItem=missingItem);sent=[];calls=[];t.reset(dict(format=1));u.mem_write(item,bytes(0x1000));u.mem_write(vt,bytes(0x1000));m.wq(item+0x48,vt);m.wq(vt+0x68,m.stop+0x10);m.wi(item+0x25c,0xffffffff)
 w.call(0x14080a770,[actor,itemId]);detach.append(dict(case=dict(missingItem=missingItem,itemId=itemId),owner=m.si(item+0x25c)&0xffffffff,calls=list(calls)))
attachment=[]
for slot,old_id,other_id,new_id in itertools.product([1,2,4,16,32,64],[0x7f000000,0x80000003],[0x7f000000,client_id,0x80000003],[0x7f000000,client_id,0x80000003]):
 c=dict(attachmentBody=True,slot=slot,oldId=old_id,otherId=other_id,newId=new_id);sent=[];calls=[];t.reset(dict(format=1))
 for p,size in [(actor,0x1000),(item,0x1000),(old_item,0x1000),(vt,0x1000)]:u.mem_write(p,bytes(size))
 m.wi(actor+8,0xffffffff)
 for offset in slots.values():m.wi(actor+offset,0x7f000000)
 m.wi(actor+slots[slot],old_id)
 if slot in [16,32]:m.wi(actor+slots[32 if slot==16 else 16],other_id)
 for ptr,item_id in [(item,client_id),(old_item,0x80000003)]:
  m.wq(ptr+0x48,vt);m.wi(ptr+0x50,item_id);m.wi(ptr+0x25c,0xffffffff)
 m.wq(vt+0x68,m.stop+0x10);m.wq(vt+0x140,m.stop+0x20);m.wq(vt+0x118,m.stop+0x30)
 w.call(0x1407fff10,[actor,slot,0 if new_id==0x7f000000 else item if new_id==client_id else old_item])
 attachment.append(dict(case=c,slotId=m.si(actor+slots[slot])&0xffffffff,newOwner=m.si(item+0x25c)&0xffffffff,oldOwner=m.si(old_item+0x25c)&0xffffffff,calls=list(calls)))
output=m.root/'backups/animations/native-quickbar-equipment-cache-observations-v1.json'
output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows,detach=detach,attachment=attachment),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),detach=len(detach),attachment=len(attachment),output=str(output))))
