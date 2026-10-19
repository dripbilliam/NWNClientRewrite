"""Exact door/placeable ScriptEvent2 branches. Capture script-event getters,
hostile history, creature lookup, broadcast/excitement/invisibility and script
dispatch. Original field writes, harmful gates, order and script indices execute.
Full EventHandler dispatch, lower helpers and payload destruction are separate.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,event,source,app=[m.heap+i*0x1000 for i in range(4)]
ranges={'door':(0x14041fbe6,0x14041fc78),'placeable':(0x1404b37dc,0x1404b3863)}
def hook(u,a,n,_):
 if a in[0x14041fe13,0x1404b3883]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1404c6b10:assert y==0;m.finish(c.get('caster',98))
 elif a==0x1404c6af0:m.finish(c.get('spell',93)if y==0 else c.get('harmful',1))
 elif a==0x14049b070:trace.append(['hostile',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x14055b3d0:trace.append(['creature',y&0xffffffff]);m.finish(source if c.get('creature',True)else 0)
 elif a==0x1403837d0:trace.append(['broadcast']);m.finish()
 elif a==0x1403a3000:trace.append(['excited',y&255]);m.finish()
 elif a==0x14039e500:trace.append(['invisibility']);m.finish()
 elif a==0x1404998a0:trace.append(['script',y&0xffffffff,z]);m.finish()
 elif not(ranges[c['owner']][0]<=a<ranges[c['owner']][1]or 0x1404b3878<=a<0x1404b3883):raise AssertionError(f'Unexpected world spell event dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace
 c=case;trace=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);rsp=m.stack+0x1fe00;u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in[(UC_X86_REG_RDI,actor),(UC_X86_REG_RSI,event),(UC_X86_REG_R15,1)]:u.reg_write(reg,v)
 u.emu_start(ranges[c['owner']][0],m.stop,count=1000);assert u.reg_read(UC_X86_REG_RIP)in[0x14041fe13,0x1404b3883]
 return dict(case=c,trace=trace,caster=m.si(actor+0x230)&0xffffffff,spell=m.si(actor+0x234),harmful=m.si(actor+0x238))
rows=[run(dict(owner=o,caster=id,spell=s,harmful=h,creature=cr))for o,id,s,h,cr in itertools.product(ranges,[98,0x80000042,0x7f000000],[-1,93],[0,1,2,-1],[False,True])]
out=m.root/'backups/animations/native-world-spell-notification-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
