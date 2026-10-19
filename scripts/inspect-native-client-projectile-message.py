"""Original SafeProjectile sender4df550 typed-field ordering and bounded client
header7ac7d1..7ac97b, plus complete OBJECTID writer4763e0/reader9737c0.
Scalar message readers/writers, three overflow queries, version admission,
payload and transport are captured lowers. OBJECTID bodies execute. This does
not execute raw packet framing/bit streams, receiver allocation/path/model/AI.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
message,player,buffer,fromPoint,toPoint,payload,app=[m.heap+n*0x2000 for n in range(1,8)]
ranges=[(0x1404df550,0x1404df785),(0x1404763e0,0x140476436),(0x1409737c0,0x1409737e8),(0x1407ac7d1,0x1407ac97b)]
def xmm(r):return struct.unpack('<f',struct.pack('<I',u.reg_read(r)&0xffffffff))[0]
def hook(u,a,n,_):
 global guard,floatIndex,byteIndex,dwordIndex
 if a in [m.stop,0x1407ac97b,0x1407ae7fd]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404bd6d0:calls.append(['build',y,z,w]);m.finish(c.get('build',1))
 elif a==0x1402d54a0:calls.append(['create',y&0xffffffff,z&0xffffffff,w]);m.finish()
 elif a==0x140476435:
  if c['mode']=='send':fields.append(dict(type='object',value=m.si(buffer+m.si(message+0x14)-4)&0xffffffff))
 elif a==0x1402db240:assert xmm(UC_X86_REG_XMM2)==1 and w==32;fields.append(dict(type='float',value=xmm(UC_X86_REG_XMM1)));m.finish()
 elif a==0x1402db150:assert z==32;fields.append(dict(type='dword',value=y&0xffffffff));m.finish()
 elif a==0x1402da960:assert z==8 and w==1;fields.append(dict(type='byte',value=y&255));m.finish()
 elif a==0x1402d5880:m.wq(y,payload);m.wi(z,53);calls.append(['payload']);m.finish(c.get('payload',1))
 elif a==0x1404dc490:calls.append(['send',y&0xffffffff,z&255,w&255,m.si(rsp+0x30)]);m.finish(c.get('send',1))
 elif a==0x1402d9460:guard+=1;calls.append(['overflow']);m.finish(int(c.get('fail',0)==guard))
 elif a==0x1402d9c30:
  assert xmm(UC_X86_REG_XMM1)==1 and z==32;calls.append(['float',1,32]);v=(c.get('from',[1.25,-2,3.5])+c.get('to',[4,5,6]))[floatIndex];floatIndex+=1;u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',v),'little'));m.finish()
 elif a==0x1402d9bc0:calls.append(['dword',y]);value=c.get('duration',250) if dwordIndex==0 else c.get('flags',37);dwordIndex+=1;m.finish(value)
 elif a==0x1402d9630:
  assert y==8 and z==1;calls.append(['byte',8,1]);values=[c['appearance']]+([] if c['appearance']==6 else [c.get('path',5)] if c['appearance']==7 else [c.get('path',5),c.get('base',49),c.get('result',3)]);value=values[byteIndex];byteIndex+=1;m.finish(value)
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured client projectile message dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,calls,fields,guard,floatIndex,byteIndex,dwordIndex
 c=case;calls=[];fields=[];guard=floatIndex=byteIndex=dwordIndex=0;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app)
 m.wq(message+8,buffer);m.wi(message+0x10,512);m.wi(message+0x14,c.get('cursor',0));m.wi(message+0x28,0);m.wq(message+0x38,buffer);m.wi(message+0x40,c.get('available',8));m.wi(message+0x44,c.get('cursor',0));m.wi(player+0x48,1234)
 for i,v in enumerate([c.get('source',0x80000063),c.get('target',0x80000064),0x12345678,0x87654321]):m.wi(buffer+i*4,v)
 u.mem_write(fromPoint,struct.pack('<3f',1.25,-2,3.5));u.mem_write(toPoint,struct.pack('<3f',4,5,6))
 rsp=m.stack+0x1ee08;u.mem_write(rsp-0x800,bytes(0x1000));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 if c['mode']=='send':
  regs=[message,player,c.get('source',99),c.get('target',100)];start=0x1404df550
  for off,v in [(0x28,fromPoint),(0x30,toPoint)]:m.wq(rsp+off,v)
  for off,v in [(0x38,250),(0x40,c['appearance']),(0x48,c.get('flags',37)),(0x50,49),(0x58,3),(0x60,5)]:m.wi(rsp+off,v)
 elif c['mode']=='encode':regs=[message,c['source'],0,0];start=0x1404763e0
 elif c['mode']=='objectRead':regs=[message,0,0,0];start=0x1409737c0
 else:
  regs=[0,0,0,0];start=0x1407ac7d1;u.reg_write(UC_X86_REG_RSI,message);u.reg_write(UC_X86_REG_RBP,m.stack+0x10000);u.reg_write(UC_X86_REG_R13,0);u.mem_write(rsp+0x40,b'\xff')
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(reg,v)
 u.emu_start(start,m.stop,count=10000);rip=u.reg_read(UC_X86_REG_RIP);assert rip in [m.stop,0x1407ac97b,0x1407ae7fd]
 header=None
 if c['mode']=='header' and rip==0x1407ac97b:
  rbp=u.reg_read(UC_X86_REG_RBP);appearance=u.reg_read(UC_X86_REG_R12)&255
  header=dict(sourceId=u.reg_read(UC_X86_REG_RBX)&0xffffffff,targetId=m.si(rsp+0x48)&0xffffffff,from_=list(struct.unpack('<3f',u.mem_read(rbp-0x60,12))),to=list(struct.unpack('<3f',u.mem_read(rbp-0x50,12))),duration=m.si(rbp-0x74)&0xffffffff,appearance=appearance,spellId=(u.reg_read(UC_X86_REG_R15)&0xffffffff) if appearance in [6,7] else None,path=None if appearance==6 else m.si(rsp+0x44)&255,baseItem=int.from_bytes(u.mem_read(rsp+0x40,1),'little'),result=u.reg_read(UC_X86_REG_R13)&255)
 return dict(case=c,calls=calls,fields=fields,header=header,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,encoded=(m.si(buffer+c.get('cursor',0))&0xffffffff) if c['mode']=='encode' else None,readCursor=m.si(message+0x44)&0xffffffff,writeCursor=m.si(message+0x14)&0xffffffff)

rows=[run(dict(mode='header',appearance=appearance,fail=fail,source=source,target=target,flags=flags))for appearance,fail,source,target,flags in itertools.product([0,1,5,6,7,8,255],[0,1,2,3],[0,0x80000063,0x7f000000],[0xffffffff,0x80000064],[0,37,0xffffffff])]
rows += [run(dict(mode='send',appearance=appearance,build=build,payload=payload,send=sent,flags=flags))for appearance,build,payload,sent,flags in itertools.product([0,5,6,7,8,255],[0,1],[0,1],[0,1,-1],[0,37,0xffffffff])]
rows += [run(dict(mode='encode',source=source,cursor=cursor))for source,cursor in itertools.product([0,1,99,0x1000000,0x7f000000,0x7fffffff,0x80000000,0xffffffff],[0,1,4])]
rows += [run(dict(mode='objectRead',available=available,cursor=cursor))for available,cursor in itertools.product([0,3,4,7,8,16],[0,1,4,8,0xfffffffc])]
out=m.root/'backups/animations/native-client-projectile-message-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
