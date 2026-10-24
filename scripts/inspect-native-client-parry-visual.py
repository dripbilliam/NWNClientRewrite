"""Whole original SpawnHitVisuals80bb10 mode0 branch. Lookup/model-node
pose,2DA float, empty transform-map allocator and area-visual creation are
captured services. No blood-mode execution, native rendering or asset copies.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent));t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);actor,target,stats,model,vt,rules,tables,area,caption,head,direction=[m.heap+n*0x800 for n in range(6,17)]
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1406ab9e0:calls.append(['target',y&0xffffffff]);m.finish(0 if case.get('missingTarget')else target);return
 if a==0x1401a6c70:calls.append(['space']);m.wf(k,case['space']);m.finish(1);return
 if a==m.stop+0x140:m.finish(model);return
 if a==m.stop+0x138:
  calls.append(['impact']);u.mem_write(z,struct.pack('<3f',*case['impact']));m.finish(0 if case.get('missingImpact')else 1);return
 if a==0x140115890:calls.append(['warning']);m.finish();return
 if a==0x140368530:m.wq(head,head);m.wq(head+8,head);m.wq(head+16,head);m.finish(head);return
 if a==0x1407da460:calls.append(['area',y&65535,list(struct.unpack('<3f',u.mem_read(z,12)))]);m.finish(case.get('areaResult',1));return
 if 0x14080bb10<=a<0x14080e266:return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[];base=dict(position=[1,2,3],orientation=[.6,.8,0],target=[5,8,2],targetId=0x80000012)
cases=[base|dict(space=s,impact=[10,20,h])for s,h in itertools.product([-.1,0,.2,.5,.5001,1,3],[0,1,2,3,7,7.01,9])]
cases +=[base|dict(space=.4,impact=[0,0,3],**patch)for patch in[dict(missingTarget=True),dict(missingImpact=True),dict(areaResult=0)]]
for case in cases:
 calls=[];t.reset(dict(format=1));m.wq(actor,vt);m.wq(model,vt);m.wq(vt+0x140,m.stop+0x140);m.wq(vt+0x138,m.stop+0x138);m.wq(actor+0x30,area);m.wi(actor+0x3a8,case['targetId']);m.wq(target+0x300,stats);u.mem_write(stats+0xcc,struct.pack('<H',2));u.mem_write(actor+0x38,struct.pack('<3f',*case['position']));u.mem_write(actor+0x44,struct.pack('<3f',*case['orientation']));u.mem_write(target+0x38,struct.pack('<3f',*case['target']));m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x100,tables+0x400)
 sp=m.stack+0x1fe08;m.wq(sp,m.stop);m.wq(sp+0x28,caption);u.reg_write(UC_X86_REG_RSP,sp)
 for reg,v in[(UC_X86_REG_RCX,actor),(UC_X86_REG_RDX,0),(UC_X86_REG_R8,0),(UC_X86_REG_R9,direction)]:u.reg_write(reg,v)
 u.emu_start(0x14080bb10,m.stop+1,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 rows.append(dict(case=case,calls=calls,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff))
out=m.root/'backups/animations/native-client-parry-visual-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
