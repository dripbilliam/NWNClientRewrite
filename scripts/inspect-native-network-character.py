"""Original character-blob scalar writer and native login handler.

Module lookup and LoadCharacterStart are captured boundaries. Real DWORD/VOID
reads and original over/underflow gates route exact synthetic byte blobs to the
native admission ABI; actual character validation is covered by the live server.
"""
import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;r=t.r;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
ranges=[]
for name in ['network-player-login-handler','network-read-void']:
 d=json.loads((m.root/'backups/animations'/('rea-'+name+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(x['start'],16),int(x['end'],16)+1)for x in d['procedure']['body']['ranges'])
player,module,server,source,packet=[m.heap+n*0x1000 for n in [5,6,7,8,9]]
def hook(u,a,n,data):
 if a==0x14055b6e0:m.finish(module);return
 if a==0x14055bb90:
  rsp=u.reg_read(UC_X86_REG_RSP);size=m.si(rsp+0x30);p=m.q(rsp+0x28);calls.append(dict(subtype=u.reg_read(UC_X86_REG_RDX)&255,size=size,blob=bytes(u.mem_read(p,size)).hex()));m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for subtype in [1,19]:
 for size in [1,31,128,1024]:
  w.cursor=0x10000;t.sizes={};t.readSource=[];r.diagnostics=[];u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,w.app);m.wi(w.app+0x28,1);m.wq(w.app+8,server);w.call(0x1402d4830)
  blob=bytes((i*37+19)&255 for i in range(size));u.mem_write(source,blob);w.call(0x1402d54a0,[w.message,size+4,0xffffffff,1]);w.call(0x1402db150,[w.message,size,32]);w.call(0x1402dad90,[w.message,source,size]);written=w.snapshot();wire=bytearray.fromhex(written['hex']);wire[:3]=bytes([112,2,subtype]);u.mem_write(packet,bytes(wire[3:]));m.wi(m.stack+0x1fe08+0x28,1);w.call(0x1402da7b0,[w.message,packet,len(wire)-3,0xffffffff]);calls=[];result=w.call(0x140457850,[w.message,player,subtype]);assert result==1 and len(calls)==1 and calls[0]['blob']==blob.hex()
  rows.append(dict(subtype=subtype,blob=blob.hex(),packet=bytes(wire).hex(),calls=calls,result=result))
output=m.root/'backups/animations/native-network-character-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
