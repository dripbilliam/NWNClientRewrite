"""Unchanged rest, character-sheet, attitude writers and real scalar/ID codec.
Synthetic player lookup and transport capture; no live game/process writes.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);player=m.heap+0xe0000
ranges=[(0x1409737f0,0x140973838),(0x1402303d0,0x14023040d),(0x140c7d6d8,0x140c7d783)]
for name in ['rest-writer-v1','sheet-writer-v2','pvp-write1-v1','char-codec-v1']:
 d=json.loads((m.root/f'backups/animations/rea-hud-{name}.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def hook(u,a,n,data):
 if a==0x1407c25c0:
  sp=u.reg_read(UC_X86_REG_RSP);size=m.si(sp+0x28)&0xffffffff;ptr=u.reg_read(UC_X86_REG_R9)
  packets.append(bytes([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255])+(bytes(u.mem_read(ptr,size))[3:]if size else b''));m.finish(1);return
 if a==0x1406ac110:m.finish(player);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global packets
 packets=[];t.reset({'format':1});m.wi(player+0x34,c.get('targetId',0xffffffff))
 if c['kind']=='rest':w.call(0x1407bffb0,[w.message])
 elif c['kind']=='sheet':w.call(0x1407bddd0,[w.message,c['page']&255,c['targetId']])
 else:w.call(0x1407c31b0,[w.message,123,int(c['likes'])])
 assert len(packets)==1
 return dict(case=c,packet=packets[0].hex())
cases=[dict(kind='rest')]+[dict(kind='sheet',page=p,targetId=id)for p,id in itertools.product([-128,-1,0,1,2,127],[0x80000001,0xffffffff,0x7f000000])]+[dict(kind='attitude',targetId=id,likes=b)for id,b in itertools.product([0x80000002,0xffffffff,0x7f000000],[False,True])]
out=m.root/'backups/animations/native-hud-request-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=[run(c)for c in cases]),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(out))))
