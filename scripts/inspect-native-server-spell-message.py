"""Original SendServerToPlayerCCMessage4cf090 case8. Whole writer dispatch,
flag comparisons, item lookup/name branch and payload/send gates execute. CC data
getters, scalar encoders/OBJECTID conversion, localized/string/CRT and transport
are captured lower services; this does not execute native wire encoding.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);message,data,item,app,payload=[m.heap+n*0x2000 for n in range(1,6)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a in [0x140169560,0x1401695b0,0x140169600,0x140c10370]:m.finish(x)
 elif a==0x1402d5740:m.finish([37,c['identified'],c['casting'],c['baseItem']][y&0xffffffff])
 elif a==0x1402d57f0:m.finish([99,c['itemId']][y&0xffffffff])
 elif a==0x1402d54a0:calls.append(['create',y&0xffffffff,z&0xffffffff,w&0xffffffff]);m.finish()
 elif a==0x1404763e0:fields.append(dict(type='object',value=y if y==0x7f000000 else (y|0x80000000)&0xffffffff));m.finish()
 elif a==0x1402db150:assert z==32;fields.append(dict(type='dword',value=y&0xffffffff));m.finish()
 elif a==0x1402da920:fields.append(dict(type='bool',value=y&1));m.finish()
 elif a==0x1402da960:assert z==8 and w==1;fields.append(dict(type='byte',value=y&255));m.finish()
 elif a==0x14055b6c0:calls.append(['item',y&0xffffffff]);m.finish(item if c['item']else 0)
 elif a==0x140115890:calls.append(['warning']);m.finish()
 elif a==0x140476160:assert z==0;fields.append(dict(type='localized',value='ItemLoc'));m.finish()
 elif a==0x14019e620:m.finish(x)
 elif a==0x1402dab50:assert z==32;fields.append(dict(type='string',value='Override'));m.finish()
 elif a==0x1402d5880:m.wq(y,payload);m.wi(z,17);calls.append(['payload']);m.finish(c['payload'])
 elif a==0x1404dc490:calls.append(['send',y&0xffffffff,z&255,w&255,m.si(rsp+0x30)]);m.finish(c['send'])
 elif not 0x1404cf090<=a<=0x1404d0b50:raise AssertionError(f'Unexpected CC8 writer lower {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,fields
 c=case;calls=[];fields=[];u.mem_write(m.heap,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wi(item+0x438,8 if c['override']else 0)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x300,bytes(0x400));m.wq(rsp,m.stop);m.wq(rsp+0x28,0)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[message,0x11223344,8,data]):u.reg_write(reg,v)
 u.reg_write(UC_X86_REG_RSP,rsp)
 try:u.emu_start(0x1404cf090,m.stop,count=2000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,fields=fields,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
rows=[run(dict(identified=identified,casting=casting,itemId=itemId,item=itemOk,override=override,payload=hasPayload,send=send,baseItem=baseItem))for identified,casting,itemId,itemOk,override,hasPayload,send,baseItem in itertools.product([0,1,2,3,-1],[0,1,2,-1],[0x7f000000,100],[0,1],[0,1],[0,1],[0,1],[8,0x123])]
out=m.root/'backups/animations/native-server-spell-message-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
