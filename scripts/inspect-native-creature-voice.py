"""Whole original creature voice807240. SSF demand/read/release, resource
existence, player/rules lookup, allocators and audio calls are explicit captured
services. Actual SSF entry reading has a separate original-code oracle. No real
audio, native process writes or copied proprietary resources.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,ssf,resource,oldSource,new,oldvt,stats,app,rules,tables=[m.heap+n*0x1000 for n in range(1,11)]
def ref(ptr):return bytes(u.mem_read(ptr,17)).split(b'\0')[0].decode('ascii')
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def hook(u,a,n,_):
 global cursor
 if a==m.stop:u.emu_stop();return
 x,y,z,k=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x140c10370:m.finish();return
 if a==0x140c10368:p=m.heap+0x40000+cursor;cursor+=(x+15)&~15;m.finish(p);return
 if a==0x140c10324:m.finish(0 if case.get('allocationFailure')else new);return
 if a==0x140c10410:m.finish();return
 if a==0x14018f300:calls.append(['demand']);m.finish(0 if case.get('demandFailure')else resource);return
 if a==0x1407d7ba0:calls.append(['entry',y&65535]);u.mem_write(z+16,case.get('resRef','voice').encode('ascii').ljust(17,b'\0'));m.finish(1);return
 if a==0x1401912c0:calls.append(['release']);m.finish();return
 if a==0x14018dfd0:m.finish(int(not ref(x)));return
 if a==0x14018f590:calls.append(['exists',ref(y),z&0xffff]);m.finish(not case.get('missingWave'));return
 if a==0x1406ac1a0:calls.append(['controlled']);m.finish(actor if case['controlled']else 0);return
 if a==0x1406ac100:calls.append(['player']);m.finish(123 if case['player']else 0);return
 if a==0x1401a7010:calls.append(['size']);m.wi(k,case['size']);m.finish(1);return
 if a==m.stop+16:calls.append(['destroy']);m.finish();return
 if a==0x1401d95b0:calls.append(['create',ref(y)]);m.finish(x);return
 if a==0x1401d9e90:calls.append(['3d',y&0xffffffff]);m.finish();return
 if a==0x1401da060:calls.append(['priority',y&255]);m.finish();return
 if a==0x1401da020:calls.append(['position',list(struct.unpack('<3f',u.mem_read(y,12))),xmm(UC_X86_REG_XMM2)]);m.finish();return
 if a==0x1401d9ca0:calls.append(['play']);m.finish();return
 assert 0x140807240<=a<=0x1408074a8,f'Uncaptured voice dependency {a:x}'
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,calls,cursor
 case=c;calls=[];cursor=0;u.mem_write(m.heap,bytes(0x10000));m.wq(actor+0x400,0 if c.get('noSet')else ssf);m.wq(ssf+8,resource);u.mem_write(actor+0x3b8,struct.pack('<H',c.get('setId',7)&65535));m.wq(actor+0xe8,oldSource if c['old']else 0);m.wi(actor+0xf0,77);m.wq(oldSource,oldvt);m.wq(oldvt,m.stop+16);m.wq(actor+0x300,stats);u.mem_write(actor+0x38,struct.pack('<3f',1,2,3));m.wq(0x1412df970,app);m.wq(app,app+0x100)
 #807358's verified RIP load names g_pRules1412df8f8.
 m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x100,tables+0x200)
 sp=m.stack+0x1fe08;u.mem_write(sp-0x300,bytes(0x400));m.wq(sp,m.stop);u.reg_write(UC_X86_REG_RSP,sp)
 for reg,v in[(UC_X86_REG_RCX,actor),(UC_X86_REG_RDX,c['code']),(UC_X86_REG_R8,c['positional'])]:u.reg_write(reg,v)
 u.emu_start(0x140807240,m.stop,count=5000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 p=m.q(actor+0xe8);return dict(case=c,calls=calls,state=dict(delay=m.si(actor+0xf0),sound='old'if p==oldSource else'new'if p==new else None))
rows=[]
default=dict(controlled=False,player=False,size=3,old=True,positional=1,code=11)
for controlled,player,size,old,positional,code in itertools.product([False,True],[False,True],[-1,0,3,4,255],[False,True],[0,1,2],[0,11,256,65535]):rows.append(run(dict(controlled=controlled,player=player,size=size,old=old,positional=positional,code=code)))
for change in[dict(setId=65535),dict(noSet=True),dict(demandFailure=True),dict(resRef=''),dict(missingWave=True),dict(allocationFailure=True)]:rows.append(run(default|change))
out=m.root/'backups/animations/native-creature-voice-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
