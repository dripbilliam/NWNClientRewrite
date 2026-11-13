"""Execute the complete hash-pinned original activity sender7c02e0 in isolated
Unicorn memory. Native CreateWriteMessage/scalar/GetWriteMessage code runs;
transport is captured. No process writes, network or gameplay outcomes."""
import sys,importlib,json,argparse
from pathlib import Path
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts'))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_RSP
u.hook_del(t.hook_handle)
sent=[]
def hook(u,address,size,data):
 x,y,z,k=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if address==0x1407c25c0:
  length=m.si(u.reg_read(UC_X86_REG_RSP)+0x28)&0xffffffff
  sent.append(bytes([112,y&255,z&255])+bytes(u.mem_read(k,length))[3:]);m.finish(1);return
 if 0x1407c02e0<=address<=0x1407c0386 or 0x1409737f0<=address<=0x140973838:return
 t.hook(u,address,size,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for format_mode in [0,1]:
 for activity in [0,1,5,10]:
  for target in ([1,0x80000001,0xfffffffa,0x7f000000] if activity==5 else [0x7f000000]):
   sent.clear();t.reset(dict(format=format_mode));w.call(0x1407c02e0,[w.message,activity,target])
   assert len(sent)==1
   rows.append(dict(format=format_mode,activityId=activity,targetId=target,packet=sent[0].hex(),lastBitOffset=u.mem_read(w.message+0x2c,1)[0]))
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--report',required=True);args=parser.parse_args()
output=(root/args.report).resolve();assert output.is_relative_to(root/'godot-client/reports') and not output.exists()
with output.open('x',encoding='utf-8') as stream:stream.write(json.dumps(dict(binarySha256=m.digest,scope=__doc__,cases=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),output=str(output))))
