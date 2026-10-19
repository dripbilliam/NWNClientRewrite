"""Original AIUpdate impact branch983e2e..9841d2, including exact field28
admission, body/shield selection, root get/set pose, vector yaw/pitch/quaternion
math and remaining duration. Object/equipment/baseitem lookups, model virtuals,
string/CRT RNG, sqrtf and FP notifications are captured lower boundaries.
No actual Gob attachment, native full AI/scene, hardware audio or packet claim.
Ranged visual170 is tested clear; its separate creature effect owner is excluded.
"""
import importlib.util,itertools,json,struct,math
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,target,vt,tvt,app,creature,item,ivt,baseitem,model,mvt,anchor=[m.heap+n*0x1000 for n in range(1,13)]
targetModel,projectileModel,parent,readPose,writePose,asCreature=[m.stop+n*0x10 for n in range(1,7)]
ranges=[(0x140983e2e,0x1409841d2),(0x1407630a0,0x1407630a8),(0x1402303d0,0x14023040d),(0x140230920,0x1402309f6),(0x14022ab00,0x14022ac34),(0x140c7a2b0,0x140c7a9a8),(0x140c7ac70,0x140c7b16f),(0x140c79d30,0x140c7a2aa),(0x140c92d20,0x140c93360),(0x140c8f29c,0x140c8f6ad)]
for file in ['client-vector-pitch','client-vector-yaw-vector','client-yaw-pitch-roll']:
 r=json.loads((m.root/f'backups/animations/rea-{file}.json').read_text())['structuredContent']['normalized_result']['procedure']['body'];ranges += [(int(e['start'],16),int(e['end'],16)+1)for e in r['ranges']]
def ui(p):return m.si(p)&0xffffffff
def text(p):return bytes(u.mem_read(p,100)).split(b'\0')[0].decode('ascii')if p else ''
def bits(p,n):return list(struct.unpack('<'+'I'*n,u.mem_read(p,n*4)))
def hook(u,a,n,_):
 if a in [m.stop,0x1409841d2]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406abb70:m.finish(app)
 elif a==0x140296470:calls.append(['lookup',y&0xffffffff]);m.wq(z,target);m.finish(c['lookup'])
 elif a==targetModel:calls.append(['targetModel',y&255,z&0xffffffff]);m.finish(anchor if c['anchor']else 0)
 elif a==projectileModel:calls.append(['projectileModel',y&255,z&0xffffffff]);m.finish(model if c['model']else 0)
 elif a==asCreature:calls.append(['creature']);m.finish(creature if c['creature']else 0)
 elif a==0x140800dd0:calls.append(['equipped',y&0xffffffff]);m.finish(0x80000077)
 elif a==0x1406abc80:calls.append(['item',y&0xffffffff]);m.finish(item if c['item']else 0)
 elif a==0x14029ca00:calls.append(['baseItem',y&0xffffffff]);m.finish(baseitem)
 elif a==0x140c7ed00:calls.append(['random']);m.finish(c['random'])
 elif a==0x14016afb0:
  assert text(y)=='imp_shield_%d';s=('imp_shield_'+str(z&0xffffffff)).encode();u.mem_write(m.heap+0xd000,s+b'\0');m.wq(x,m.heap+0xd000);m.wi(x+8,len(s));m.wi(x+12,len(s)+1);m.finish(x)
 elif a==parent:calls.append(['attach',text(z),w&0xffffffff]);m.finish(c['attach'])
 elif a==readPose:
  calls.append(['getPose',text(y)])
  if c['pose']:u.mem_write(z,struct.pack('<3f',7,8,9));u.mem_write(w,struct.pack('<4f',.5,.5,.5,.5))
  m.finish(c['pose'])
 elif a==writePose:calls.append(['setPose',text(y),bits(z,3),bits(w,4)]);m.finish(1)
 elif a==0x140c10370:m.finish()
 elif a==0x140c7d6d8:
  value=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM0)&0xffffffff))[0];u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',math.sqrt(value)),'little'));m.finish()
 elif a==0x140cae8e0:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured impact dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls
 c=case;calls=[];u.mem_write(m.heap,bytes(0x20000));rsp=m.stack+0x1fe08;rbp=rsp-0x300;u.mem_write(rsp-0x1000,bytes(0x1100));m.wq(rsp,m.stop)
 m.wq(0x1412df970,app);m.wq(app,app);m.wq(0x1412df8f8,app);m.wq(actor,vt);m.wq(target,tvt);m.wq(vt+0x140,projectileModel);m.wq(tvt+0x140,targetModel);m.wq(tvt+0x58,asCreature);m.wq(item+0x48,ivt);m.wq(ivt+0x140,targetModel);m.wq(model,mvt);m.wq(mvt+0x98,parent);m.wq(mvt+0x138,readPose);m.wq(mvt+0x130,writePose)
 m.wq(target+0x78,anchor if c['handle']else 0);m.wi(target+0x28,c['field28']);m.wi(item+0x40,42);u.mem_write(baseitem+8,bytes([c['weaponType']]));u.mem_write(actor+0x1e4,bytes([c['result']]));m.wi(actor+0x198,0x80000063);m.wi(actor+0x1fc,c['duration']);m.wi(actor+0x194,0)
 m.wq(actor+0x1a0,m.heap+0xe000);u.mem_write(m.heap+0xe000,b'authored_impact\0');u.mem_write(actor+0x44,struct.pack('<3f',*c['vector']));m.wi(0x1415d8224,0);u.reg_write(UC_X86_REG_MXCSR,0x1f80)
 for reg,value in [(UC_X86_REG_RSP,rsp),(UC_X86_REG_RBP,rbp),(UC_X86_REG_RDI,actor),(UC_X86_REG_RSI,1),(UC_X86_REG_R15,0),(UC_X86_REG_R13,0x140d80070)]:u.reg_write(reg,value)
 try:u.emu_start(0x140983e2e,m.stop,count=15000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==0x1409841d2
 return dict(case=c,calls=calls,remaining=ui(actor+0x194),duration=ui(actor+0x1fc))
default=dict(lookup=0,result=0,handle=1,field28=0,anchor=1,model=1,creature=0,item=1,weaponType=7,random=1,attach=1,pose=1,vector=[1,2,3],duration=25)
rows=[run(default|dict(lookup=lookup,result=result,handle=handle,field28=flag,anchor=anchorOk,model=modelOk,creature=isCreature,item=itemOk,weaponType=weapon))for lookup,result,handle,flag,anchorOk,modelOk,isCreature,itemOk,weapon in itertools.product([0,1],[0,1,2,3,4,255],[0,1],[0,1,-1],[0,1],[0,1],[0,1],[0,1],[6,7])]
rows +=[run(default|dict(result=result,random=random,pose=pose,attach=attach,vector=list(vector)))for result,random,pose,attach,vector in itertools.product([0,2],[0,1,32767],[0,1],[0,1],[[0,0,0],[.00001,0,0],[0,0,1],[-1,0,0],[1,0,0],[.5,.25,.75],[2,-3,4]])]
out=m.root/'backups/animations/native-projectile-impact-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows))+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
