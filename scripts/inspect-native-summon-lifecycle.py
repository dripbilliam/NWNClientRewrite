"""Original summon apply140433d70/remove140438ca0. Lower allocation, creature
template loading, geometry, calendar, events, associates and unsummon owners are
captured. This proves coordinator ordering/state, not those captured owners.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
handler,owner,effect,existing,new,area,string,chars,app,ints,visual,vints,event,message,vt,path=[m.heap+n*0x1000 for n in range(1,17)]
def point(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))
def retfloat(v):u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',v),'little'));m.finish()
def hook(u,a,n,_):
 global allocation
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==m.stop+0x10:m.finish(owner if c.get('creature',True) else 0)
 elif a==m.stop+0x20:calls.append(['destroy',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x140424690:m.finish(string)
 elif a==0x140423fd0:m.finish(m.si(x+0xc0+(y&255)*4)&0xffffffff)
 elif a==0x140423fc0:m.finish(m.si(m.q(x+0x48)+(y&255)*4)&0xffffffff)
 elif a==0x140423fb0:retfloat(m.rf(x+0x50+(y&255)*4))
 elif a==0x14055b3d0:calls.append(['creature',y&0xffffffff]);m.finish((existing if y==100 else new) if c.get('exists',True) and y in [100,101] else 0)
 elif a==0x140494e80:
  calls.append(['area',m.si(x+8)&0xffffffff]);m.finish(0 if c.get('targetNoArea') else area)
 elif a==0x140c10324:
  allocation+=1;m.finish(new if x==0xae0 else visual if x==0x110 else event if allocation<4 else message)
 elif a==0x14037a300:calls.append(['construct']);m.finish(new)
 elif a==0x1404233d0:
  u.mem_write(visual,bytes(0x110));m.wq(visual+0x48,vints);m.wi(visual+0x40,8);m.finish(visual)
 elif a==0x14035bdf0:calls.append(['visual',m.si(vints),point(z),point(w),int.from_bytes(u.mem_read(visual+0xa,2),'little')]);m.finish()
 elif a==0x1403d0410:calls.append(['associate',y&0xffffffff,z&65535]);m.finish()
 elif a==0x14055b2e0:calls.append(['areaById',y&0xffffffff]);m.finish(0 if c.get('noArea') else area)
 elif a==0x14018dea0:
  value=c.get('name','wolf').split('\0')[0][:16].lower();u.mem_write(x,value.encode().ljust(17,b'\0'));m.finish(x)
 elif a==0x140397dd0:
  calls.append(['load',bytes(u.mem_read(y,16)).split(b'\0')[0].decode(),z]);m.finish(c.get('load',1))
 elif a==0x140115890:calls.append(['warning']);m.finish()
 elif a==0x14036aa90:
  calls.append(['safe',point(y),m.xmm(UC_X86_REG_XMM2),m.si(rsp+0x28)]);u.mem_write(m.q(rsp+0x30),struct.pack('<3f',11,12,13));m.finish(c.get('safe',1))
 elif a==0x14036a210:calls.append(['height',point(y)]);retfloat(17)
 elif a==0x1404c6490:m.finish(x)
 elif a==0x1404c7290:data.setdefault('floats',{})[str(y)]=m.xmm(UC_X86_REG_XMM2);m.finish()
 elif a==0x1404c7320:data.setdefault('objectIds',{})[str(y)]=z&0xffffffff;m.finish()
 elif a==0x1404c72e0:data.setdefault('integers',{})[str(y)]=z&0xffffffff;m.finish()
 elif a in [0x14055ba10,0x14055b960]:m.finish(app)
 elif a in [0x140597010,0x140597140]:
  calls.append(['day' if a==0x140597010 else 'time',m.xmm(UC_X86_REG_XMM1)]);m.finish(2 if a==0x140597010 else 1234)
 elif a==0x1405570b0:
  calls.append(['event',y,z,w&0xffffffff,m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30),json.loads(json.dumps(data))]);m.finish()
 elif a==0x1402da770:m.finish()
 elif a==0x1403a2480:calls.append(['feedback',y&0xffffffff,m.si(new+8)&0xffffffff]);m.finish()
 elif a==0x1403daee0:calls.append(['unsummon',m.si(x+8)&0xffffffff]);m.finish()
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in [(0x140433d70,0x140434427),(0x140438ca0,0x140438cef),(0x140425210,0x14042521c),(0x140425200,0x14042520a),(0x140425300,0x140425314)]):raise AssertionError(f'Uncaptured summon lifecycle dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,remove=False):
 global c,calls,data,allocation
 c=case;calls=[];data={};allocation=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app)
 m.wq(owner,vt);m.wq(new,vt);m.wq(vt,m.stop+0x20);m.wq(vt+0x60,m.stop+0x10)
 for obj,id,pos in [(owner,99,[1,2,3]),(existing,100,[7,8,9]),(new,101,[0,0,0])]:
  m.wi(obj+8,id);m.wi(obj+0xa0,88);u.mem_write(obj+0xa4,struct.pack('<3f',*pos));m.wi(obj+0x8fc,c.get('master',0x7f000000));m.wq(obj+0x530,path)
 u.mem_write(owner+0xb0,struct.pack('<3f',4,5,6));name=c.get('name','wolf');m.wq(string,chars);m.wi(string+8,len(name));u.mem_write(chars,name.encode()+b'\0')
 m.wq(effect+0x48,ints);m.wi(effect+0x40,8);m.wi(ints,c.get('visual',100));m.wi(ints+4,c.get('appear',0))
 for i,v in enumerate([c.get('areaId',0x7f000000),c.get('removeId',101),100,0x7f000000]):m.wi(effect+0xc0+i*4,v)
 for i,v in enumerate([21,22,23,c.get('delay',.5)]):m.wf(effect+0x50+i*4,v)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x600,bytes(0x700));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[handler,owner,0 if c.get('nullEffect') else effect,c.get('loading',0)]):u.reg_write(reg,v)
 u.emu_start(0x140438ca0 if remove else 0x140433d70,m.stop,count=20000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,objects=list(struct.unpack('<4I',u.mem_read(effect+0xc0,16))),floats=list(struct.unpack('<4f',u.mem_read(effect+0x50,16))))
rows=[run(dict(name=name,visual=visual,delay=delay,appear=appear,safe=safe,areaId=areaId)) for name,visual,delay,appear,safe,areaId in itertools.product(['wolf','LongResRef0123456789',''],[-1,100],[-2,0,.5],[0,2],[0,1],[88,0x7f000000])]
rows += [run(dict(name=name,**{key:value})) for name in ['wolf',''] for key,value in [('loading',1),('loading',2),('creature',False),('nullEffect',True),('noArea',True),('targetNoArea',True),('exists',False),('master',99),('load',0)]]
removes=[run(dict(removeId=id,exists=exists),True) for id,exists in itertools.product([100,101,0x7f000000],[False,True])]
out=m.root/'backups/animations/native-summon-lifecycle-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows,removes=removes))+'\n');print(json.dumps(dict(rows=len(rows),removes=len(removes),output=str(out))))
