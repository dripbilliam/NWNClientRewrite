"""Complete original855d00/855be0 GUI page-button handlers on synthetic GUI.
Grid clear, transport getter/send and string formatting/label are captured
lower boundaries; no live process mutation or original asset copies.
"""
import sys,importlib,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);ranges=[]
for name in ['next','prev']:
 d=json.loads((m.root/f'backups/animations/rea-container-{name}-button.json').read_text())['structuredContent']['raw_result']['value']
 ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
gui,app,label,vt=m.heap+0x40000,m.heap+0x45000,m.heap+0x46000,m.heap+0x47000
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140882700:events.append('clear');m.finish();return
 if a==0x1406abf90:events.append('transport');m.finish(w.message if c['transport']else 0);return
 if a in [0x1407bde70,0x1407bde90]:events.append('next'if a==0x1407bde70 else'previous');m.finish();return
 if a==0x14016afb0:events.append(dict(format=[z&0xffffffff,k&0xffffffff]));m.wq(x,0);m.finish(x);return
 if a==m.stop+0x80:events.append('label');m.finish();return
 if a==0x140c10370:m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for current,count,direction,transport in itertools.product([-1,0,1,2,255,256,257],[0,1,2,3,255],[-1,1],[False,True]):
 c=dict(current=current,count=count,direction=direction,transport=transport);events=[];t.reset(dict(format=1));u.mem_write(gui,bytes(0x4000));m.wq(0x1412df970,app);m.wq(app,app);m.wi(gui+0x2680,current&0xffffffff);u.mem_write(gui+0x2f60,bytes([count]));m.wq(gui+0x2728,label);m.wq(label,vt);m.wq(vt+0xd0,m.stop+0x80)
 w.call(0x140855d00 if direction==1 else 0x140855be0,[gui]);page=m.si(gui+0x2680)&0xffffffff;page=page-0x100000000 if page&0x80000000 else page
 assert events[:2]==['clear','transport'];rows.append(dict(case=c,page=page,events=events))
out=m.root/'backups/animations/native-container-page-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
