"""Execute unchanged original split6/23 and learn12/13 senders, native client
OBJECT_ID/scalar writers and message extraction. Only transport/allocation/copy
boundaries are captured; no game/network is opened and no outcome is fabricated.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
proof=json.loads((m.root/'backups/animations/rea-native-item-context-v1.json').read_text())
allowed={'0x1407c0050','0x1407c0ee0'}
ranges=[(int(b['start'],16),int(b['end'],16)+1) for row in proof['rows'] if row['result']['procedure']['address'] in allowed for b in row['result']['procedure']['body']['ranges']]+[(0x1409737f0,0x140973845)]
packets=[]
def hook(u,address,size,data):
    if address==0x1407c25c0:
        rsp=u.reg_read(UC_X86_REG_RSP);length=m.si(rsp+0x28)&0xffffffff;raw=bytes(u.mem_read(u.reg_read(UC_X86_REG_R9),length))
        packets.append(bytes([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255])+raw[3:]);m.finish(1);return
    if any(lo<=address<hi for lo,hi in ranges):return
    t.hook(u,address,size,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for kind,id,amount in itertools.product(['split','learn'],[0,0x80000001,0xff000002,0xffffffff,0x7f000000],[1,2,65535]):
    packets.clear();t.reset({'format':1});w.call(0x1407c0050 if kind=='split' else 0x1407c0ee0,[w.message,id,amount]);assert len(packets)==1
    rows.append(dict(kind=kind,itemId=id,amount=amount,packet=packets[0].hex()))
output=m.root/'backups/animations/native-item-menu-request-observations-v1.json';assert not output.exists(),'Preserve previous observations'
output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=rows),indent=2)+'\n')
print(json.dumps(dict(output=str(output),cases=len(rows))))
