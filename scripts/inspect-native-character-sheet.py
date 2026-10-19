"""Original complete character-sheet receiver444e00, permission4bd020,
target setter4be500, stats update constructor50a680/destructor50a790 and
ClearEffectIcons50a8c0. Scalar codec, player-info/creature lookup, allocation,
free/memmove/memset, and individually tested lower lifecycle owners are captured
boundaries. Profiling disabled. Synthetic inputs; no client packet/UI sender,
network replication, full stats writer or campaign-completion parity claim.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
message,client,gui,update,app,vt,net,info,rules,pool,a1,a2=[m.heap+n*0x1000 for n in range(12)]
entries={'receive':0x140444e00,'permission':0x1404bd020,'target':0x1404be500,'create':0x14050a680,'clear':0x14050a8c0,'dispose':0x14050a790}
ends={'receive':0x14044502f,'permission':0x1404bd0b6,'target':0x1404be585,'create':0x14050a78a,'clear':0x14050a984,'dispose':0x14050a8b8}

def alloc(size):
 global cursor
 ptr=m.heap+cursor;cursor+=(size+31)&~31;assert cursor<0xf0000;u.mem_write(ptr,bytes([0xcd])*size);names[ptr]='new'+str(len(allocated));allocated.append(size);return ptr
def name(ptr):return names.get(ptr,'null' if ptr==0 else hex(ptr))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1402d98d0:calls.append(['char',y]);m.finish(c['page'])
 elif a==0x140476130:calls.append(['objectId']);m.finish(c['target'])
 elif a==0x1402d9460:calls.append(['overflow']);m.finish(c.get('overflow',0))
 elif a==0x1402d9520:calls.append(['underflow']);m.finish(c.get('underflow',0))
 elif a==0x1404bd020 and c['mode']=='receive':calls.append(['permission',y&0xffffffff]);m.finish(c['allowed'])
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish({11:a1,22:a2}.get(y&0xffffffff,0) if c.get('creatures',True) else 0)
 elif a==0x1404d90b0:calls.append(['denied',y&0xffffffff,z&0xffffffff]);m.finish()
 elif a==0x1404be500 and c['mode']=='receive':calls.append(['target',y&0xffffffff]);m.wi(x,y);m.finish()
 elif a==0x14050a8c0 and c['mode']=='receive':calls.append(['clear']);m.finish()
 elif a==m.stop+0x10:calls.append(['net']);m.finish(net)
 elif a==0x140237850:calls.append(['info',y&0xffffffff]);m.finish(info if c.get('info',True) else 0)
 elif a==0x14050a790 and c['mode']=='target':calls.append(['dispose',name(x)]);m.finish()
 elif a==0x14050a680 and c['mode']=='target':calls.append(['create',name(x)]);m.finish(x)
 elif a in [0x140c10324,0x140c10368]:
  calls.append(['allocate',x]);m.finish(0 if c.get('failAllocate',False) else alloc(x))
 elif a==0x140c42060:u.mem_write(x,bytes([y&255])*z);m.finish(x)
 elif a==0x1402a22b0:calls.append(['combatCreate',name(x)]);m.finish(x)
 elif a==0x1402a2930:calls.append(['combatDispose',name(x)]);m.finish()
 elif a in [0x140c10360,0x140c10370,0x140c4f024]:calls.append(['free',name(x)]);m.finish()
 elif a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x)
 elif not entries[c['mode']]<=a<ends[c['mode']]:raise AssertionError(f'Unexpected character-sheet dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,cursor,names,allocated
 c=case;calls=[];cursor=0x40000;names={update:'oldUpdate',pool:'icons',pool+0x100:'list0',pool+0x200:'list1',pool+0x300:'skills',pool+0x400:'combat'};allocated=[]
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app if c.get('server',True) else 0);m.wq(app,vt);m.wq(vt+0x38,m.stop+0x10);m.wq(0x1412df8f8,rules)
 m.wi(a1+8,11);m.wi(a2+8,22);m.wi(a2+0x8fc,c.get('master',0x7f000000));m.wi(a1+0x8fc,0x7f000000);m.wi(a1+0x540,c.get('counts',[3,7])[0]);m.wi(a2+0x540,c.get('counts',[3,7])[1]);m.wi(client+0x48,77);m.wi(client+0x54,c.get('controlled',11));m.wi(info+0x24,c.get('dm',0));m.wq(client+0x90,gui)
 m.wi(gui,c.get('previous',11));u.mem_write(gui+4,bytes([c.get('oldPage',2)]));m.wq(gui+8,update if c.get('hasUpdate',True) else 0)
 if c['mode']=='create':u.mem_write(update,bytes([0xcd])*128);u.mem_write(rules+0x107,bytes([c['skillCount']]))
 else:
  m.wq(update,pool+0x100);m.wq(update+8,0x100000001);m.wq(update+0x10,pool+0x200);m.wq(update+0x18,0x200000002);m.wq(update+0x28,pool);m.wi(update+0x30,len(c.get('icons',[])));m.wi(update+0x34,16);m.wq(update+0x70,pool+0x400 if c.get('combat',True) else 0);m.wq(update+0x78,pool+0x300 if c.get('skills',True) else 0)
  for index,icon in enumerate(c.get('icons',[])):
   ptr=pool+0x500+icon*16 if icon is not None else 0;m.wq(pool+index*8,ptr)
   if ptr:names[ptr]='icon'+str(icon)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 args={'receive':[message,client,c.get('subtype',1)],'permission':[client,c.get('target',22)],'target':[gui,c['target'] if 'target'in c else 22],'create':[update],'clear':[update],'dispose':[update]}[c['mode']]
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 try:u.emu_start(entries[c['mode']],m.stop,count=10000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 row=dict(case=c,calls=calls)
 if c['mode']=='receive':row|=dict(result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,target=m.si(gui)&0xffffffff,page=struct.unpack('<b',u.mem_read(gui+4,1))[0],counts=[m.si(a1+0x540),m.si(a2+0x540)])
 elif c['mode']=='permission':row['result']=u.reg_read(UC_X86_REG_RAX)&0xffffffff
 elif c['mode']=='target':row|=dict(target=m.si(gui)&0xffffffff,update=name(m.q(gui+8)))
 elif c['mode']=='create':row|=dict(scalars=list(u.mem_read(update,0x70)),combat=name(m.q(update+0x70)),skills=list(u.mem_read(m.q(update+0x78),c['skillCount'])) if m.q(update+0x78) else None,allocations=allocated)
 else:row|=dict(count=m.si(update+0x30),capacity=m.si(update+0x34),pointers=[name(m.q(update+o))for o in [0,0x10,0x28,0x70]])
 return row

cases=[dict(mode='receive',previous=old,target=new,page=page,allowed=allowed,subtype=subtype,counts=counts)for old,new,page,allowed,subtype,counts in itertools.product([11,22,0x7f000000],[11,22,0x7f000000],[0,1,127,128,254,255],[0,1],[0,1,2],[[3,7],[0,0],[-2147483648,2147483647]])]
cases += [dict(mode='receive',target=22,page=255,allowed=1,overflow=over,underflow=under)for over,under in [(1,0),(0,1),(1,1),(-1,0)]]
cases += [dict(mode='permission',target=target,controlled=controlled,master=master,dm=dm,info=info,server=server)for target,controlled,master,dm,info,server in itertools.product([11,22,0x7f000000],[11,22,33],[11,22,0x7f000000],[0,1,2],[False,True],[False,True])]
cases += [dict(mode='target',previous=old,target=new,hasUpdate=has,failAllocate=fail)for old,new,has,fail in itertools.product([11,22],[11,22],[False,True],[False,True])]
cases += [dict(mode='create',skillCount=count)for count in [0,1,28,64,255]]
cases += [dict(mode=mode,icons=icons,skills=skills,combat=combat)for mode,icons,skills,combat in itertools.product(['clear','dispose'],[[],[0],[None],[1,None,2,3]],[False,True],[False,True])]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-character-sheet-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),modes={mode:sum(r['case']['mode']==mode for r in rows)for mode in entries})))
