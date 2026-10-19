"""Complete AddUnlockObjectAction and AIActionUnlockObject gameplay path for
noncreatures. Original action record stores/group wrapping and all noncreature
gates/lock writes/event scheduling run. Begin after disabled profiler setup;
stop before profiler-only epilogue. Capture casts, object/item/health lookups,
allocation, script-event ctor and append/event boundaries. Creature range,
skills/tools/timing and profiler owners are excluded, not emulated as success.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,target,node,vt,tvt,app,list_,allocated=[m.heap+i*0x1000 for i in range(8)]
exports={s.name.decode():m.base+s.address for s in m.pe.DIRECTORY_ENTRY_EXPORT.symbols if s.name};ctor=next(a for n,a in exports.items()if n.startswith('??0CScriptEvent@@'))
def snapshot(p):return dict(actionId=m.si(p),group=int.from_bytes(u.mem_read(p+0x98,2),'little'),count=int.from_bytes(u.mem_read(p+0x9a,2),'little'),flag=m.si(p+0x9c),types=[m.si(p+4+i*4)for i in range(12)],data=[m.si(p+0x38+i*8)for i in range(12)])
def hook(u,a,n,_):
 if a==m.stop or a==0x1404a970a:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(0)
 elif a==m.stop+0x20:m.finish(target if c.get('world',True)else 0)
 elif a==m.stop+0x30:m.finish(target if c.get('kind','door')=='door'else 0)
 elif a==m.stop+0x40:m.finish(target if c.get('kind','door')=='placeable'else 0)
 elif a==0x1404953b0:trace.append(['dead']);m.finish(c.get('dead',0))
 elif a==0x140495620:trace.append(['dying']);m.finish(c.get('dying',0))
 elif a==0x14055b6c0:trace.append(['item',y&0xffffffff]);m.finish(0)
 elif a==0x14055b4c0:trace.append(['object',y&0xffffffff]);m.finish(target if c.get('target',True)else 0)
 elif a==0x140c10324:m.finish(allocated)
 elif a==ctor:u.mem_write(x,bytes(0x48));m.finish(x)
 elif a==0x14055b960:m.finish(app)
 elif a==0x1405570b0:trace.append(['event',w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),int.from_bytes(u.mem_read(m.q(rsp+0x38),2),'little')]);m.finish()
 elif a==0x140169030:trace.append(['append',snapshot(y)]);m.finish(0)
 elif not(0x14048ddf0<=a<0x14048df63 or 0x1404a878a<=a<0x1404a970a):raise AssertionError(f'Unexpected unlock dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace
 c=case;trace=[];u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x10);m.wq(target,tvt);m.wq(tvt+0x20,m.stop+0x20);m.wq(tvt+0x30,m.stop+0x30);m.wq(tvt+0x98,m.stop+0x40)
 m.wi(actor+8,99);m.wi(target+8,99 if c.get('self',True)else 100);m.wi(node+0x38,99 if c.get('self',True)else 100);m.wi(node+0x40,c.get('item',0x7f000000));m.wi(node+0x48,0);m.wi(target+0x424,c.get('locked',1));m.wi(target+0x378,c.get('locked',1));m.wi(target+0x450,c.get('key',0));m.wi(target+0x3a0,c.get('key',0));u.mem_write(target+0x41f,bytes([c.get('dc',17)&255]));u.mem_write(target+0x3a8,bytes([c.get('dc',17)&255]))
 rsp=m.stack+0x1fc00;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBP,rsp+0x100)
 if c['mode']=='add':
  m.wi(actor+0xec,c.get('commandable',1));u.mem_write(actor+0x18,(c.get('group',0)&65535).to_bytes(2,'little'));m.wq(actor+0x100,list_)
  for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[actor,c.get('targetId',123)&0xffffffff,c.get('item',0x7f000000)&0xffffffff,c.get('property',0)&0xffffffff]):u.reg_write(r,v)
  entry=0x14048ddf0
 else:
  entry=0x1404a878a
  for r,v in[(UC_X86_REG_RDI,actor),(UC_X86_REG_R12,node),(UC_X86_REG_R15,0)]:u.reg_write(r,v)
 try:u.emu_start(entry,m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,trace=trace,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==(m.stop if c['mode']=='add'else 0x1404a970a)
 return dict(case=c,trace=trace,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff if c['mode']=='add'else u.reg_read(UC_X86_REG_RBX)&0xffffffff,group=int.from_bytes(u.mem_read(actor+0x18,2),'little'),lastGroup=int.from_bytes(u.mem_read(actor+0x1a,2),'little'),locked=m.si(target+(0x424 if c.get('kind','door')=='door'else 0x378)))
cases=[dict(mode='add',commandable=cmd,group=g,targetId=t,item=i,property=-1)for cmd,g,t,i in itertools.product([0,1,2],[0,65533,65534,65535],[123,0x80000042],[0x7f000000,0x80000042])]
cases +=[dict(mode='execute',kind=k,locked=l,key=key,self=s,dead=d,dying=y)for k,l,key,s,d,y in itertools.product(['door','placeable','other'],[0,1,-1],[0,1],[False,True],[0,1,2],[0,1])]
cases +=[dict(mode='execute',target=False),dict(mode='execute',world=False)]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-unlock-action-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
