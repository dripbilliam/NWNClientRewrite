"""Complete original26/1 and22/0 per-recipient voice writers with real native
scalar/OBJECT_ID codecs; complete26/1 receiver with synthetic creature lookup
and captured807240 boundary. No live transport, native voices or GUI execution.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);player=m.heap+0x90000;actor=m.heap+0x91000
def dossier(name):return json.loads((m.root/'backups/animations'/name).read_text())['structuredContent']['raw_result']['value']
ranges=[]
for name in ['rea-creature-voice-wire-writer-current.json','rea-creature-quickchat-direct-writer-current.json','rea-combat-voice-packet-current.json','rea-client-projectile-object-id-reader-body.json']:
 for r in dossier(name)['procedure']['body']['ranges']:ranges.append((int(r['start'],16),int(r['end'],16)+1))
def hook(u,a,n,data):
 if a==0x1404dc490:
  sp=u.reg_read(UC_X86_REG_RSP);ptr=m.q(sp+0x28);size=m.si(sp+0x30)&0xffffffff;packets.append(bytes([80,u.reg_read(UC_X86_REG_R8)&255,u.reg_read(UC_X86_REG_R9)&255])+bytes(u.mem_read(ptr,size))[3:]);m.finish(1);return
 if a==0x1406ab9e0:calls.append(['lookup',u.reg_read(UC_X86_REG_RDX)&0xffffffff]);m.finish(0 if case.get('noActor')else actor);return
 if a==0x140807240:calls.append(['voice',u.reg_read(UC_X86_REG_RDX)&65535,u.reg_read(UC_X86_REG_R8)&0xffffffff]);m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for fmt,source,code,kind in itertools.product([0,1],[0,99,0x7ffffffe,0x7fffffff,0x7f000000,0xffffffff],[0,11,255,256,65535],['voice','quick']):
 case=dict(format=fmt,source=source,code=code,kind=kind);calls=[];packets=[];t.reset(dict(format=fmt));m.wi(player+0x48,7)
 w.call(0x1404e25d0,[w.message,player,source,code])if kind=='voice'else w.call(0x1404df120,[w.message,7,source,code]);assert len(packets)==1;packet=packets[0]
 if kind=='voice':
  body=packet[3:];u.mem_write(t.inputBase,body+bytes(128));assert w.call(0x1402da7b0,[w.message,t.inputBase,len(body),0xffffffff])==1;w.call(0x1407b9160,[w.message,1]);assert calls[-1]==['voice',code&255,1]
 rows.append(dict(case=dict(case),packet=packet.hex(),calls=list(calls)))
out=m.root/'backups/animations/native-creature-voice-wire.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
