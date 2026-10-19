"""Complete object-visual receiver1407857f0..14078644b with successful and
failed temporary creature allocations. Scalar message reads, empty transform
maps, creature constructor/model, module/area, internal-array registration,
AI/scene/position and delay setter are captured lower boundaries. This proves
receiver ordering/arguments/field writes, not those lower implementations,
full native model loading, GPU presentation, wire decoding or scene scheduling.
In particular source registration tests the ORIGINAL inverted status branch.
Read-only original binary; no original runtime or install writes.
"""
import importlib,itertools,json,struct
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
message,manager,app,rules,table,target,source,vt,head,module,area=[m.heap+n*0x1000 for n in range(1,12)]
load,setId,setArea,setScene,setPosition,asObject,add=[m.stop+n*0x10 for n in range(1,8)]
def vector(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))
def word(ptr):return m.si(ptr)&0xffffffff
def hook(u,a,n,_):
 global allocation,objectReads,floatReads,byteReads
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140368530:m.finish(head)
 elif a in [0x140c10370,0x14011b210,0x140369860]:m.finish()
 elif a==0x140c10368:
  ptr=m.heap+0x80000+allocation*0x400;allocation+=1;m.finish(ptr)
 elif a==0x1409737c0:
  value=[c['targetId'],c['sourceId']][objectReads];objectReads+=1;m.finish(value)
 elif a==0x1402da450:m.finish(c['visualId'])
 elif a in [0x1402d9460,0x1402d9520,0x1407c4ab0]:m.finish(0)
 elif a==0x1402d9c30:
  value=([1.25,-2,3.5,7,8,9,c['duration']])[floatReads];floatReads+=1;u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
 elif a==0x1402d9630:
  value=[17,250][byteReads];byteReads+=1;m.finish(value)
 elif a==0x1401a68f0:
  value=c['kind'].encode()+b'\0';ptr=m.heap+0x90000;u.mem_write(ptr,value);m.wq(w,ptr);m.wi(w+8,len(value)-1);m.finish(1)
 elif a==0x1406abb60:
  ident=y&0xffffffff;calls.append(['object',ident]);m.finish(target if ident==123 else source if ident==789 else 0)
 elif a==0x1403591a0:m.wq(x,head);m.wq(x+8,0);m.finish(x)
 elif a==0x140c10324:
  assert x==0x480;role={0x140785b1b:'point',0x140785ee7:'source',0x1407860b9:'target'}[m.q(rsp)]
  calls.append(['allocate',role,x]);ptr=m.heap+0x20000+len(dummies)*0x2000
  if not c['allocateFailure']:dummies[ptr]=role
  m.finish(0 if c['allocateFailure'] else ptr)
 elif a==0x1407fb140:
  calls.append(['construct',dummies[x]]);m.wq(x,vt);m.wi(x+8,0x7f000000);m.wq(x+0x300,x+0x1000);u.mem_write(x+0xc,b'\x05');m.finish(x)
 elif a==0x14018ded0:u.mem_write(x,bytes(u.mem_read(y,17)));m.finish(x)
 elif a==load:
  calls.append(['load',dummies[x],bytes(u.mem_read(y,17)).split(b'\0')[0].decode(),z&255,w&255]);m.finish(c['load'])
 elif a==0x1406abea0:calls.append(['module']);m.finish(module)
 elif a in [0x1406abb70,0x1406ab940]:m.finish(app)
 elif a==0x140295d40:
  calls.append(['register',dummies[z],c['register'],w]);m.wi(y,7+len(dummies)-1);m.finish(c['register'])
 elif a==setId:calls.append(['id',dummies[x],y&0xffffffff]);m.wi(x+8,y);m.finish()
 elif a==setArea:calls.append(['area',dummies[x]]);m.wq(x+0x30,y);m.finish()
 elif a==0x1407675d0:calls.append(['ai',dummies[y]]);m.finish()
 elif a==setScene:calls.append(['scene',dummies[x],y]);m.finish()
 elif a==setPosition:
  calls.append(['position',dummies[x],vector(y)]);u.mem_write(x+0x38,bytes(u.mem_read(y,12)));m.finish()
 elif a==0x140765920:
  calls.append(['delay',dummies[x],y&255,z&0xffffffff,w&0xffffffff,word(x+0x104)]);m.finish()
 elif a==asObject:m.finish(x)
 elif a==add:
  calls.append(['add',dummies.get(x,'existing'),word(x+8),y&65535,z&0xffffffff,w&0xffffffff,word(rsp+0x28)&255,word(rsp+0x30)&255,vector(m.q(rsp+0x38))]);m.finish(0)
 elif not 0x1407857f0<=a<0x14078644b:raise RuntimeError(f'Uncaptured receiver dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,allocation,objectReads,floatReads,byteReads,dummies
 c=case;calls=[];dummies={};allocation=objectReads=floatReads=byteReads=0
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,manager);m.wq(manager,app);m.wq(0x1412df8f8,app);m.wq(app+0x130,rules);m.wq(rules+0x280,table);m.wq(module+0xf8,area if c['area']else 0);m.wq(area+0x248,1234)
 for ptr,ident in [(target,123),(source,789)]:m.wq(ptr,vt);m.wi(ptr+8,ident);u.mem_write(ptr+0xc,b'\x05')
 for off,fn in [(0xf0,load),(8,setId),(0x118,setArea),(0x138,setScene),(0x128,setPosition),(0x18,asObject),(0x178,add)]:m.wq(vt+off,fn)
 for off in [0,8,16]:m.wq(head+off,head)
 u.mem_write(head+0x19,b'\1');rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,message);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 try:u.emu_start(0x1407857f0,m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,calls=calls,rip=hex(u.reg_read(UC_X86_REG_RIP)))));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 states=[dict(role=role,id=word(ptr+8),position=vector(ptr+0x38),desiredPosition=vector(ptr+0x2c0),appearance=int.from_bytes(u.mem_read(m.q(ptr+0x300)+0xcc,2),'little'),temporary=word(ptr+0x104))for ptr,role in dummies.items()]
 return dict(case=c,calls=calls,dummies=states,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff)
cases=[]
for role,alloc,loaded,hasArea,status,duration in itertools.product(['point','target','source'],[0,1],[0,1],[0,1],[0,1],[0,0.001,2.5,-0.125,4294968]):
 cases.append(dict(role=role,kind='F'if role=='point'else'P',visualId=1,targetId=123 if role=='source'else 0x7f000000,sourceId=0x7f000000 if role=='source'else 789,allocateFailure=alloc,load=loaded,area=hasArea,register=status,duration=duration))
rows=[run(c)for c in cases]
# Confirm actual inversion, timing ABI and field order independently of the JS port.
for row in rows:
 c=row['case'];calls=row['calls'];registered=not c['allocateFailure']and c['load']and c['area'];aborted=c['allocateFailure']or(registered and c['register']!=(1 if c['role']=='source'else 0))
 assert bool([v for v in calls if v[0]=='add'])==(not aborted)
 for call in calls:
  if call[0]=='delay':
   assert call[2:4]==[1,1]and call[5]==0
   duration=struct.unpack('<f',struct.pack('<f',c['duration']))[0]if c['role']=='target'else 0
   expected=10000 if c['role']=='point'else 6000 if duration==0 else int(struct.unpack('<f',struct.pack('<f',duration*1000))[0])&0xffffffff
   assert call[4]==expected,(c,call,expected)
 for dummy in row['dummies']:
  assert dummy['temporary']==(0 if aborted else 1)
out=m.root/'backups/animations/native-visual-dummy-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),verified=True)))
