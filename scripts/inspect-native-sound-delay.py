"""Whole original SetOneShotDelay1e1500 with captured timer/list services;
bounded original Render1e0c50..1e0c74 expiration decision, not whole renderer.
No native audio output or live game mutation.
"""
import importlib.util,json,itertools
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);source,output,exo,timer=[m.heap+n*0x1000 for n in [1,2,3,4]]
def dossier(name):return json.loads((m.root/'backups/animations'/name).read_text())['structuredContent']['raw_result']['value']
deps={c['name']:int(c['address'],16)for c in dossier('rea-weapon-sound-delay-set-current.json')['callees']}
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if mode=='due'and a in [0x1401e0c74,0x1401e0cba]:u.emu_stop();return
 if a==deps['CExoTimers::GetMillisecondTimer']:calls.append(['timer']);m.finish(case['start']);return
 if a==deps['CExoLinkedListInternal::AddHead']:calls.append(['head']);m.finish(m.heap+0x5000);return
 if a==0x140115890:calls.append(['warning']);m.finish();return
 assert 0x1401e1500<=a<0x1401e15d0 or 0x1401e0c50<=a<0x1401e0c74,f'Unexpected sound delay dependency {a:x}'
u.hook_add(UC_HOOK_CODE,hook);rows=[]
for enabled,oneShot,start,delay in itertools.product([0,1],[0,1],[0,1000,0xffffffff],[0,1,229,0xffffffff]):
 case=dict(enabled=enabled,oneShot=oneShot,start=start,delay=delay);mode='set';calls=[];u.mem_write(source,bytes(0x100));m.wq(source+0x70,output);m.wi(source+0x60,oneShot);m.wi(output+0x48,enabled);m.wq(0x1412df8b8,exo);m.wq(exo+0x10,timer);sp=m.stack+0x1fe08;m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp);u.reg_write(UC_X86_REG_RCX,source);u.reg_write(UC_X86_REG_RDX,delay);u.emu_start(0x1401e1500,m.stop+1,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 rows.append(dict(kind='set',case=case,calls=calls,state=dict(delay=m.si(source+0x88)&0xffffffff,start=m.si(source+0x8c)&0xffffffff,status=u.mem_read(source+0x80,1)[0],listed=m.q(source+0x78)!=0)))
for start,delay,offset in itertools.product([0,1,1000,0xfffffffe,0xffffffff],[0,1,5,229,0xffffffff],[0,1,4,5,228,229,230,0xffffffff]):
 now=(start+offset)&0xffffffff;mode='due';m.wi(source+0x88,delay);m.wi(source+0x8c,start);u.reg_write(UC_X86_REG_RBX,source);u.reg_write(UC_X86_REG_R15,now);u.emu_start(0x1401e0c50,0x1401e0cbb,count=1000);stop=u.reg_read(UC_X86_REG_RIP);assert stop in[0x1401e0c74,0x1401e0cba];rows.append(dict(kind='due',case=dict(start=start,now=now,delay=delay),due=stop==0x1401e0c74))
out=m.root/'backups/animations/native-sound-delay-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
