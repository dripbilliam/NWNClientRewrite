"""Complete original journal notification owner1406dab60 in isolated memory.
Real string/ResRef copies; message-data SetString, feedback dispatch, GUI sound,
button highlight, app getters and deallocation are captured lower boundaries.
Deferred array append executes intact with fixture capacity. No live writes.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
d=json.loads((m.root/'backups/animations/rea-journal-feedback-owner.json').read_text())['structuredContent']['raw_result']['value']
ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]
helper=json.loads((m.root/'backups/animations/rea-journal-notice-queue-string.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in helper['procedure']['body']['ranges'])
owner,gui,records,title,raw=[m.heap+n for n in [0x80000,0x81000,0x82000,0x83000,0x84000]]
def string(p):
 n=m.si(p+8)&0xffffffff;v=m.q(p);assert n<65536;return bytes(u.mem_read(v,n)).hex()if v else ''
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406abe20:m.finish(c['defer']);return
 if a==0x1406ac020:m.finish(gui if c['toolbar']else 0);return
 if a==0x1402da8a0:strings[x]=string(z);m.finish();return
 if a==0x1406aaf90:events.append(dict(kind='feedback',type=y&65535,textHex=strings[z]));m.finish();return
 if a==0x1401f6110:events.append(dict(kind='sound',resource=bytes(u.mem_read(x,16)).split(b'\0')[0].decode()));m.finish();return
 if a==0x1401e5d20:events.append(dict(kind='highlight',enabled=y));m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for present,toolbar,defer,quest,changed,text in itertools.product([0,1],[0,1],[0,1],[0,1],[0,1],[b'',b'Module-defined journal title']):
 c=dict(present=present,toolbar=toolbar,defer=defer,quest=quest,changed=changed,textHex=text.hex());events=[];strings={};t.reset(dict(format=1));m.wq(owner+0x70,gui if present else 0);m.wq(gui+0x58,records);m.wi(gui+0x60,0);m.wi(gui+0x64,8);u.mem_write(raw,text or b'\0');m.wq(title,raw);m.wi(title+8,len(text));m.wi(title+12,len(text)+1)
 try:w.call(0x1406dab60,[owner,quest,changed,title])
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 count=m.si(gui+0x60);queued=[dict(textHex=string(records+i*24),changed=m.si(records+i*24+16))for i in range(count)];rows.append(dict(case=c,events=events,queued=queued))
out=m.root/'backups/animations/native-journal-notices-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
