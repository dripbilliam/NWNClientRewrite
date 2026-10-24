"""Whole original80bb10 mode1 selection/reuse, with synthetic tables, maximum
HP, client violence and model services. Model creation deliberately fails in
this first selector profile; no attachment/orientation/native rendering claim.
"""
import sys,importlib,json,struct,itertools,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent));t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,stats,record,rules,tables,app,caption,direction,old,vt,flags=[m.heap+n*0x800 for n in range(6,17)]
appearance=m.heap+0x9000;visuals=m.heap+0x9400
success='--success'in sys.argv;newModel=m.heap+0x9800;baseItem=m.heap+0x9c00;weapon=m.heap+0xa000;actorVt=m.heap+0xa800;mainModel=m.heap+0xb800
def rf(p):return struct.unpack('<f',u.mem_read(p,4))[0]
def xmm(reg):return struct.unpack('<f',struct.pack('<I',u.reg_read(reg)&0xffffffff))[0]
def setXmm(reg,value):u.reg_write(reg,struct.unpack('<I',struct.pack('<f',value))[0])
helperRanges=[]
for name in ['blood-normalize-current','blood-vector-normalize-current','blood-cross-current','blood-quaternion-multiply-current','blood-axis-quaternion-current','blood-vector-scale-current','blood-acos-current']:
 d=json.loads((m.root/f'backups/animations/rea-{name}.json').read_text())['structuredContent']['raw_result']['value'];helperRanges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def string(p):return bytes(u.mem_read(m.q(p),m.si(p+8)&0xffffffff)).decode('cp1252')if m.q(p)else''
def setString(p,value):
 raw=value.encode('cp1252');ptr=m.heap+w.cursor;w.cursor+=(len(raw)+16)&~15;u.mem_write(ptr,raw+b'\0');m.wq(p,ptr);m.wi(p+8,len(raw));m.wi(p+12,len(raw)+1)
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406ab9b0:m.finish(app);return
 if a==0x140260680:m.finish(int(string(x)==bytes(u.mem_read(y,64)).split(b'\0')[0].decode('cp1252')));return
 if a==0x1401a68f0:
  column=string(z);table='appearance'if x==appearance else'visualeffects';value=case['blood']if table=='appearance'else f'blood_{y&0xffffffff}';calls.append(['string',table,y&0xffffffff,column]);setString(k,value);m.finish(1);return
 if a==0x1401a7010:
  calls.append(['int',y&0xffffffff,string(z)]);m.wi(k,(y&0xffffffff)+1000);m.finish(int(case.get('lowViolence',True)));return
 if a==0x1407f5e20:calls.append(['maximum']);m.finish(case.get('maximum',100));return
 if a==0x140115890:calls.append(['warning']);m.finish();return
 if a==0x1400931f0:calls.append(['create',bytes(u.mem_read(x,64)).split(b'\0')[0].decode('cp1252')]);m.finish(newModel if success else 0);return
 if a==m.stop+0x140:m.finish(mainModel);return
 if a==m.stop+0x98:calls.append(['parent',bytes(u.mem_read(z,32)).split(b'\0')[0].decode('cp1252'),k]);m.finish();return
 if a==m.stop+0xb8:calls.append(['orientation',list(struct.unpack('<4f',u.mem_read(z,16)))]);u.mem_write(y,bytes(u.mem_read(z,16)));m.finish(y);return
 if a==m.stop+0x30:calls.append(['play',bytes(u.mem_read(y,32)).split(b'\0')[0].decode('cp1252'),xmm(UC_X86_REG_XMM2),k]);m.finish(1);return
 if a==0x140800c30:calls.append(['weapon',y&255]);m.finish(99);return
 if a==0x1406abc80:m.finish(weapon if case.get('weapon',True)else 0);return
 if a==0x14029ca00:m.finish(baseItem);return
 if a==0x1407630d0:m.finish(case.get('animation',200));return
 if a in[0x140c7ac70,0x140c7a2b0,0x140c7d6d8]:setXmm(UC_X86_REG_XMM0,({0x140c7ac70:math.cos,0x140c7a2b0:math.sin,0x140c7d6d8:math.sqrt}[a])(xmm(UC_X86_REG_XMM0)));m.finish();return
 if a==0x140cae8e0:m.finish();return
 if a in[0x140caeb60,0x140caecb0]:setXmm(UC_X86_REG_XMM0,float('nan'));m.finish();return
 if a==m.stop+0x38:
  index=(x-old)//0x100;calls.append(['info',index]);m.wf(z,-1 if case.get('finished')==index else .25);m.finish();return
 if a==m.stop+0x80:calls.append(['destroy',(x-old)//0x100]);m.finish();return
 if 0x14080bb10<=a<0x14080e266 or any(lo<=a<hi for lo,hi in helperRanges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
base=dict(violence=1,blood='R',damage=1,result=1)
cases=[base|dict(violence=v,blood=b,damage=d,result=r)for v,b,d,r in itertools.product([0,1,2,3],['R','G','Y','W','N','','X','r','RR'],[-1,0,1,9,10,11,32767,32768,65535],[1,3,10])]
cases +=[base|dict(violence=v,**patch)for v,patch in itertools.product([0,1,2],[dict(attackType=867),dict(attackType=868),dict(attackType=866),dict(killing=1),dict(killing=2),dict(weaponAttackType=7),dict(white=True),dict(maximum=-100),dict(maximum=9),dict(maximum=65535),dict(kind=1),dict(lowViolence=False),dict(slots=3),dict(slots=3,finished=0),dict(slots=3,finished=1),dict(slots=3,finished=2)])]
if success:cases=[base|dict(direction=d,orientation=o,animation=a,weaponType=wt)for d,o,a,wt in itertools.product([[1,0,0],[0,1,0],[0,-1,0],[-1,0,0],[1,2,3],[0,0,0]],[[1,0,0],[0,1,0],[.6,.8,0]],[0,200,201],range(7))]+[base|dict(weapon=False),base|dict(part='')]
rows=[]
for case in cases:
 calls=[];t.reset(dict(format=1));m.wq(actor+0x300,stats);u.mem_write(stats+0xcc,struct.pack('<H',2));m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x100,appearance);m.wq(tables+0x280,visuals);u.mem_write(app+0x40,bytes([case['violence']]));m.wi(actor+0x28,case.get('kind',0));m.wq(actor+0x18,flags);m.wi(actor+0x20,int(case.get('white',False)));m.wi(flags,1)
 m.wq(actor,actorVt);m.wq(actorVt+0x140,m.stop+0x140);m.wq(newModel,vt);m.wq(vt+0x98,m.stop+0x98);m.wq(vt+0xb8,m.stop+0xb8);m.wq(vt+0x30,m.stop+0x30);u.mem_write(baseItem+9,bytes([case.get('weaponType',1)]));u.mem_write(direction,struct.pack('<3f',*case.get('direction',[1,0,0])));u.mem_write(actor+0x44,struct.pack('<3f',*case.get('orientation',[1,0,0])));setString(caption,case.get('part','impact'))
 u.mem_write(record+0xa,struct.pack('<H',case['damage']&65535));u.mem_write(record+0xc,bytes([case['result']]));u.mem_write(record+0x1a,struct.pack('<H',case.get('attackType',0)));m.wi(record+0x20,case.get('killing',0));u.mem_write(record+0x24,bytes([case.get('weaponAttackType',1)]))
 for i in range(case.get('slots',0)):p=old+i*0x100;m.wq(actor+0x178+i*8,p);m.wq(p,vt)
 m.wq(vt,m.stop+0x80);m.wq(vt+0x38,m.stop+0x38)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);m.wq(sp+0x28,caption);u.reg_write(UC_X86_REG_RSP,sp)
 for reg,v in[(UC_X86_REG_RCX,actor),(UC_X86_REG_RDX,1),(UC_X86_REG_R8,record),(UC_X86_REG_R9,direction)]:u.reg_write(reg,v)
 u.emu_start(0x14080bb10,m.stop+1,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 result=u.reg_read(UC_X86_REG_RAX)&0xffffffff;assert result in[0,1];rows.append(dict(case=case,calls=calls,result=result))
limits=__doc__ if not success else 'Whole80bb10 mode1 success path with original normalize/cross/axis-quaternion/multiply/acos control flow. Tables/HP/model/weapon/animation services and CRT sin/cos/sqrt/FP-status/domain handling are captured boundaries; no native rendering. Synthetic actors/outcome/directions; byte string helpers execute.'
out=m.root/('backups/animations/native-client-blood-visual-success-observations.json'if success else'backups/animations/native-client-blood-visual-observations.json');out.write_text(json.dumps(dict(target=m.digest,limits=limits,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
