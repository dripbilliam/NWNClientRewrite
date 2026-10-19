"""Complete native GetItemACValue and GetIsSkillSuccessful VM owners. Original
typed-pop/default gates, signed/BYTE/WORD arithmetic, dynamic passive traversal,
skill-label indexing, message construction/result classification and push status
execute. Capture lookup/cast, GetPassiveProperty, effective rank, RollDice,
allocation/message setters/broadcast and temporary array-release boundaries.
Invalid skill-label indices use synthetic mapped data to observe original index
arithmetic; this does not claim the actual game safely accepts out-of-range IDs.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);u.mem_map(m.heap+0x100000,0x400000)
command,vm,app,actor,vt,stats,rules,item,props,message=[m.heap+i*0x1000 for i in range(10)];skills=m.heap+0x100000
ranges=[(0x140527d80,0x140527e48),(0x140527910,0x140527b86),(0x1402ae8a0,0x1402ae8e6),(0x1402ac8b0,0x1402ac937)]
def hook(u,a,n,_):
 global index,output
 if a in[m.stop,0x1402ac937]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in[0x140286160,0x140286110]:
  trace.append(['pop','object'if a==0x140286160 else'int']);ok=index!=c.get('failPop',-1)
  if ok:m.wi(y,arguments[index])
  index+=1;m.finish(int(ok))
 elif a==0x140286410:output=y&0xffffffff;trace.append(['push',output]);m.finish(c.get('push',1))
 elif a==0x140c10370:m.finish()
 elif a==0x140c10368:m.finish(message)
 elif a==0x1401a7010:
  assert bytes(u.mem_read(m.q(z),m.si(z+8)))==b'Name';trace.append(['name',y&0xffffffff]);m.wi(w,c['name']);m.finish(c.get('loadStatus',1))
 elif a==0x14055b6c0:trace.append(['item',y&0xffffffff]);m.finish(item if c.get('exists',True)else 0)
 elif a==0x140468ef0:
  trace.append(['property',y&0xffffffff]);
  if c.get('shrink',False):m.wi(item+0x380,0)
  m.finish(0 if y==c.get('nullProperty')else props+y*32)
 elif a==0x14055b850:m.finish(app)
 elif a==0x140296470:trace.append(['lookup',y&0xffffffff]);m.wq(z,actor);m.finish(c.get('status',0))
 elif a==m.stop+0x20:trace.append(['cast']);m.finish(actor if c.get('creature',True)else 0)
 elif a==0x140406a40:trace.append(['rank',y&255,z,w&0xffffffff]);m.finish(c.get('rank',5)&255)
 elif a==0x1402ad680:trace.append(['dice',y&255,z&255]);m.finish(c.get('roll',10)&65535)
 elif a==0x140c10324:trace.append(['allocate',x]);m.finish(message)
 elif a==0x1402da770:trace.append(['object',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1402da730:trace.append(['integer',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x140384150:trace.append(['broadcast']);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Unmapped script check dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,trace,index,output,arguments
 c=case;trace=[];index=0;output=None;u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df910,vm);m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x120,skills);m.wq(actor,vt);m.wq(vt+0x60,m.stop+0x20);m.wq(actor+0xad0,stats);m.wi(actor+8,c.get('id',0x80000042));m.wi(item+0x35c,c.get('base',4))
 properties=c.get('properties',[[1,2],[1,3],[2,99]]);m.wi(item+0x380,c.get('count',len(properties)))
 for n,(type,value)in enumerate(properties):u.mem_write(props+n*32,(type&65535).to_bytes(2,'little'));u.mem_write(props+n*32+6,(value&65535).to_bytes(2,'little'))
 skill=c.get('skill',1);m.wi(skills+(skill&65535)*56,c.get('name',260+(skill&65535)))
 arguments=[c.get('id',0x80000042)]if c['mode']=='armor'else[c.get('id',0x80000042),skill,c.get('dc',15)]
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c['mode']in['nameCtor','nameLoad']:
  if c['mode']=='nameCtor':u.mem_write(message,bytes([c['seed']])*56);entry=0x1402ae8a0;u.reg_write(UC_X86_REG_RCX,message)
  else:
   entry=0x1402ac8b0;u.reg_write(UC_X86_REG_RDI,rules);u.reg_write(UC_X86_REG_RSI,c['nameIndex']*56);u.reg_write(UC_X86_REG_R13,0);u.reg_write(UC_X86_REG_R14,app);u.reg_write(UC_X86_REG_R15,c['nameIndex']);u.reg_write(UC_X86_REG_RBP,rsp-0x200)
  u.emu_start(entry,m.stop,count=1000);return dict(case=c,name=m.si(message if c['mode']=='nameCtor'else skills+c['nameIndex']*56),trace=trace)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[command,0,len(arguments)]):u.reg_write(r,v)
 try:u.emu_start(0x140527d80 if c['mode']=='armor'else 0x140527910,m.stop,count=5000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),trace=trace)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,trace=trace)
cases=[dict(mode='armor',base=base,properties=p)for base,p in itertools.product([0,-1,10,2147483647,-2147483648],[[],[[1,2]],[[1,65535],[1,65536],[1,-1]],[[65537,9],[2,7],[1,3]],[[1,2],[1,3],[2,99]]])]
cases +=[dict(mode='armor',**d)for d in[dict(exists=False),dict(failPop=0),dict(push=0),dict(nullProperty=0),dict(nullProperty=1),dict(shrink=True),dict(count=0),dict(count=-1)]]
cases +=[dict(mode='skill',rank=r,roll=d,dc=dc)for r,d,dc in itertools.product([-129,-128,-1,0,5,127,128,255,256],[1,20,65535,65536],[-2147483648,-1,0,1,10,25,50,2147483647])]
cases +=[dict(mode='skill',skill=skill,status=status,creature=cr,dc=dc)for skill,status,cr,dc in itertools.product([-65537,-257,-1,0,27,254,255,256,65535],[0,1,255,256],[False,True],[-1,0,1])]
cases +=[dict(mode='skill',**d)for d in[*[dict(failPop=i)for i in range(3)],dict(push=0),dict(name=-1)]]
cases +=[dict(mode='nameCtor',seed=s)for s in[0,85,255]]
cases +=[dict(mode='nameLoad',nameIndex=i,name=n,loadStatus=s)for i,n,s in itertools.product([0,27,255],[-1,0,343,2147483647,-2147483648],[0,1])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-script-checks-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows))))
