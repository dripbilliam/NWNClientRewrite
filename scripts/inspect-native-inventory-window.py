"""Original inventory13/1 sender/reader and GUI open/close ownership body.

Unmodified hash-pinned original writers, readers,79d4f0 and857cd0 execute.
Object/GUI/message lookup, transport and actual GUI visibility/attachment/
repository repaint boundaries are fixtures. Visibility providers publish their
explicit active-bit effect; original code owns displayed-owner/container-mode
writes. No renderer/game process, secret, network or original asset publication.
"""
import importlib,itertools,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP
u.hook_del(t.hook_handle)
ranges=[(0x1409737c0,0x1409737f0)]
for filename in ['native-associate-inventory-owner-research-v1.json','native-associate-inventory-lifecycle-research-v1.json']:
 dossier=json.loads((m.root/'godot-client/reports'/filename).read_text());assert dossier['binarySha256']==m.digest
 for row in dossier['records']:
  ranges.extend((int(b['start'],16),int(b['end'],16)+1)for b in row['procedure']['body']['ranges'])
player,creature,primary,alternate,manager=[m.heap+n for n in [0x60000,0x62000,0x68000,0x6c000,0x70000]]
PC,OTHER,INVALID=0x80000002,0x80000007,0x7f000000
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;sent.append(bytes([80,z&255,k&255])+bytes(u.mem_read(m.q(sp+0x28),size))[3:]);m.finish(1);return
 if a==0x1406ac1c0:m.finish(PC);return
 if a==0x1406ab9e0:calls.append(dict(kind='lookup',id=y&0xffffffff));m.finish(creature if c.get('present')else 0);return
 if a in [0x1406abbe0,0x1406abfd0]:
  calls.append(dict(kind='gui',alternate=a==0x1406abfd0));m.finish((alternate if a==0x1406abfd0 else primary)if c.get('guiAvailable',True)else 0);return
 if a==0x140857cd0 and not c.get('windowBody'):
  calls.append(dict(kind='window',alternate=x==alternate,open=y&0xffffffff,notify=z&0xffffffff,ownerId=k&0xffffffff));m.finish();return
 if a==0x1406abbc0:m.finish(manager);return
 if a==0x1406abf90:m.finish(w.message if c.get('messageOwner',True)else 0);return
 if a==0x1401fc750:calls.append(dict(kind='forceVisible'));m.wi(x+0xb0,1);m.finish();return
 if a==0x1401fc470:calls.append(dict(kind='deactivate'));m.wi(x+0xb0,0);m.finish();return
 if a==0x1406fa140:calls.append(dict(kind='attach'));m.finish();return
 if a==0x1406fa7b0:calls.append(dict(kind='hideConflicts'));m.finish();return
 if a==0x140856fa0:calls.append(dict(kind='refreshOwner',ownerId=y&0xffffffff));m.finish();return
 if a==0x1407be110:calls.append(dict(kind='statusRequest',open=y&0xffffffff,ownerId=z&0xffffffff));m.finish();return
 if a==0x1407bdeb0:calls.append(dict(kind='containerClose',targetId=y&0xffffffff));m.finish();return
 if a in [0x140882700,0x1401fb630,0x1401fafa0]:calls.append(dict(kind={0x140882700:'clearContainer',0x1401fb630:'detachContainer',0x1401fafa0:'attachEquipment'}[a]));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format,opened,server_owner,present,removed,gui_available in itertools.product([0,1],[0,1],[2,7,INVALID],[False,True],[0,1],[False,True]):
 owner=server_owner if server_owner==INVALID else server_owner|0x80000000
 c=dict(format=format,open=opened,ownerId=owner,serverOwnerId=server_owner,present=present,removed=removed,guiAvailable=gui_available);sent=[];calls=[];t.reset(dict(format=format));u.mem_write(player,bytes(0x1000));u.mem_write(creature,bytes(0x1000));m.wi(player+0x48,17);m.wi(creature+0x104,removed)
 w.call(0x1404ccd90,[w.message,player,opened,server_owner]);assert len(sent)==1;packet=sent[0];u.mem_write(t.inputBase,packet[3:]);m.wi(m.stack+0x1fe30,1);assert w.call(0x1402da7b0,[w.message,t.inputBase,len(packet)-3,0xffffffff])==1
 result=w.call(0x14079d4f0,[w.message,1]);assert result==1;assert w.call(0x1402d9460,[w.message])==0;assert w.call(0x1402d9520,[w.message])==0
 rows.append(dict(case=c,packet=packet.hex(),calls=list(calls)))
windows=[]
for active,opened,owner,displayed,mode,notify,message_owner,attached in itertools.product([0,1],[0,1],[PC,OTHER,INVALID],[PC,OTHER],[0,1],[0,1],[False,True],[False,True]):
 c=dict(windowBody=True,active=active,open=opened,ownerId=owner,displayedOwner=displayed,containerMode=mode,notify=notify,messageOwner=message_owner,attached=attached);sent=[];calls=[];t.reset(dict(format=1));u.mem_write(primary,bytes(0x4000));m.wi(primary+0xb0,active);m.wi(primary+0x2f68,displayed);m.wi(primary+0x2f64,mode);m.wi(primary+0x268c,OTHER);m.wi(primary+0x2690,99);m.wq(primary+0xa0,1 if attached else 0)
 w.call(0x140857cd0,[primary,opened,notify,owner]);windows.append(dict(case=c,active=m.si(primary+0xb0),displayedOwner=m.si(primary+0x2f68)&0xffffffff,containerMode=m.si(primary+0x2f64),containerId=m.si(primary+0x268c)&0xffffffff,containerField=m.si(primary+0x2690),calls=list(calls)))
output=m.root/'backups/animations/native-inventory-window-observations-v1.json';assert not output.exists();output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows,windows=windows),indent=2)+'\n');print(json.dumps(dict(receivers=len(rows),windows=len(windows),output=str(output))))
