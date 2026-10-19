"""Original creature PlayAnimation7fc7d0 for type4 cast action records.
Current-animation and clip-length queries, queue insertion and allocation are
captured boundaries. Native routing, FLOAT speed math and flags execute intact.
No model playback, spell effects, server actions or live process modification.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);actor,record=[m.heap+n*0x1000 for n in [20,21]]
d=json.loads((m.root/'backups/animations/rea-network-spell-animation-playback.json').read_text())['structuredContent']['raw_result']['value']['procedure'];ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['body']['ranges']]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1407630d0:m.finish(c['current']);return
 if a==0x1407630b0:u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',c['length']),'little'));m.finish();return
 if a==0x1407635a0:
  speed=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM3)&0xffffffff))[0];calls.append(dict(animation=y&65535,duration=z&0xffffffff,speed=speed,sameRecord=m.q(sp+0x28)==record,delay=m.si(sp+0x30)));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];t.reset(dict(format=1));u.mem_write(record,bytes([4])+bytes(79));m.wi(actor+0x434,7);m.wi(actor+0x43c,c['flag']);w.call(0x1407fc7d0,[actor,c['animation'],record]);return dict(case=c,calls=list(calls),flag=m.si(actor+0x43c),field434=m.si(actor+0x434))
rows=[run(dict(animation=a,current=current,length=length,flag=flag))for a,current,length,flag in itertools.product([17,18,19,20,61],[0,2,4,16,24,25],[0,123.25,500,1279.875],[0,1])]
output=m.root/'backups/animations/native-network-spell-animation-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
