"""Execute complete original item text-bubble sender4e2360 with original
CNWMessage writers. Only transport and the existing allocator/copy boundaries
are captured. No game process, credentials, GPU or network connection is used.
"""
import importlib,itertools,json,re,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
def hook(u,a,n,data):
 if a==0x1404dc490:
  sp=u.reg_read(UC_X86_REG_RSP);major=u.reg_read(UC_X86_REG_R8)&255;minor=u.reg_read(UC_X86_REG_R9)&255
  pointer=m.q(sp+0x28);size=m.si(sp+0x30)&0xffffffff
  packet=bytearray(u.mem_read(pointer,size));packet[:3]=bytes([80,major,minor]);sent.append(bytes(packet));m.finish(1);return
 if 0x1404e2360<=a<0x1404e2458:return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for fmt,item_id,mode,text in itertools.product([0,1],[0x80000002,0xfffffffe],[-1,0,1,2,3,4],['','Plain','<c\x01\xff\x01>Line</c>\n[b]literal[/b]']):
 sent=[];t.reset(dict(format=fmt));item=m.heap+0x9000;player=t.clientBase;buffer=t.inputBase+0x6000;raw=text.encode('cp1252')
 u.mem_write(buffer,raw+b'\0');m.wi(item+0x50,item_id);m.wi(item+0x2b8,mode);m.wq(item+0x2c0,buffer);m.wi(item+0x2c8,len(raw));m.wi(item+0x2cc,len(raw)+1)
 w.call(0x1404e2360,[w.message,player,item,0]);assert len(sent)==1
 rows.append(dict(format=fmt,itemId=item_id,mode=mode,text=text,packet=sent[0].hex()))
sent=[];t.reset(dict(format=1));assert w.call(0x1404e2360,[w.message,t.clientBase,0,0])==0 and not sent
name=next((arg.split('=',1)[1]for arg in sys.argv[1:]if arg.startswith('--report=')),'native-item-caption-wire-v1.json');assert re.fullmatch(r'native-item-caption-wire-[a-z0-9-]+\.json',name)
output=m.root/'backups/animations'/name;assert not output.exists(),'Preserve prior evidence'
output.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows,nullItemNoPacket=True),indent=2)+'\n')
print(json.dumps(dict(output=str(output),cases=len(rows),sample=rows[0])))
