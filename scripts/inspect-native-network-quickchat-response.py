"""Complete original4df1c0 quickchat server sender, native ID/WORD writers.
Player/object/area lookups, player list and transport are captured boundaries.
Original same-area and <=400 squared-distance recipient filters execute.
No audio playback, original UI or live process modification is claimed.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,recipient,vt,player,players,area,otherArea=[m.heap+n*0x1000 for n in range(20,27)]
d=json.loads((m.root/'backups/animations/rea-network-command-server-quickchat-response.json').read_text())['structuredContent']['raw_result']['value'];ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x14055b850:m.finish(m.heap+0x60000);return
 if a==0x140296470:m.wq(z,actor);m.finish(1 if c['noSource']else 0);return
 if a==m.stop+0x60:m.finish(x);return
 if a==0x140494e80:m.finish(otherArea if x==recipient and not c['sameArea']else area);return
 if a==0x14055b8e0:m.finish(players);return
 if a==0x1404ba840:m.finish(recipient);return
 if a==0x1404dc490:
  size=m.si(sp+0x30)&0xffffffff;sent.append(dict(playerId=y&0xffffffff,packet=(bytes([80,z&255,k&255])+bytes(u.mem_read(m.q(sp+0x28),size))[3:]).hex()));m.finish(1);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,sent
 c=case;sent=[];t.reset(dict(format=c['format']));m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x60);m.wi(actor+8,c['objectId']);m.wi(player+0x48,7)
 m.wq(players,players+0x100);m.wi(players+8,1);m.wq(players+0x100,player)
 for i,v in enumerate([c['distance'],0,0]):m.wf(recipient+0xa4+i*4,v)
 result=w.call(0x1404df1c0,[w.message,c['objectId'],c['quickChat']]);return dict(case=c,sent=list(sent),result=result)
rows=[]
for f,oid,word,dist,same,missing in itertools.product([0,1],[100,0x7fffffff,0x7f000000],[0,4,9,10,22,65535],[0,19.999,20,20.001,100],[False,True],[False,True]):
 c=dict(format=f,objectId=oid,quickChat=word,distance=dist,sameArea=same,noSource=missing)
 try:rows.append(run(c))
 except Exception:print(json.dumps(dict(case=c,ip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
out=m.root/'backups/animations/native-network-quickchat-response-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
