"""Complete4d31c0 one-liner writer, real scalar/ID/locstring codecs.
Transport and locstring destruction are explicit captured boundaries.
Synthetic memory only; no native process writes or proprietary asset copies.
"""
import sys,importlib,itertools,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
d=json.loads((m.root/'backups/animations/rea-feedback-chat-multilang-helper.json').read_text())['structuredContent']['raw_result']['value'];ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]
ref=m.heap+0x90000
def hook(u,a,n,data):
 if a==0x1401695b0:m.finish();return
 if a==0x1404dc490:
  sp=u.reg_read(UC_X86_REG_RSP);size=m.si(sp+0x30)&0xffffffff;ptr=m.q(sp+0x28);packets.append(bytes([80,u.reg_read(UC_X86_REG_R8)&255,u.reg_read(UC_X86_REG_R9)&255])+bytes(u.mem_read(ptr,size))[3:]);m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for fmt,custom,gender,oneLiner,soundFlag,sound in itertools.product([0,1],[False,True],[0,1],[0,1],[0,1],['','test_voice']):
 c=dict(format=fmt,custom=custom,gender=gender,oneLiner=oneLiner,soundFlag=soundFlag,sound=sound);packets=[];t.reset(dict(format=fmt));t.populateLoc(t.loc,dict(strRef=57779,entries=[dict(key=0,hex=b'Native custom line'.hex())]if custom else []));u.mem_write(ref,sound.encode().ljust(17,b'\0'));sp=m.stack+0x1fe08
 for off,value in [(0x28,t.loc),(0x30,0x7fffffff),(0x38,gender),(0x40,oneLiner),(0x48,ref),(0x50,soundFlag),(0x58,0x7fffffff)]:m.wq(sp+off,value)
 w.call(0x1404d31c0,[w.message,0x80000001,8,0x13]);assert len(packets)==1;rows.append(dict(case=c,packet=packets[0].hex()))
out=m.root/'backups/animations/native-network-speech-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
