"""Execute the original creation/level-up feat-slot counter and its complete
level/current-class/GetBonusFeats getters. Only logging for intentionally invalid
class slots is a boundary. These are decoded rules/stat fixtures, not a 2DA
parser, full creator, server outcome, or graphical acceptance oracle.
"""
import importlib.util,json,random,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,rules,races,classes,normal,bonus=[m.heap+n for n in [0x1000,0x10000,0x20000,0x30000,0x90000,0x90008]]
ranges=[(0x1407ec290,0x1407ec399),(0x1407f5d70,0x1407f5e11),(0x1407f10a0,0x1407f1108),(0x1402997d0,0x1402997e6)]
def byte(a,v):u.mem_write(a,bytes([v&255]))
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 if a==0x140c0a1b0:raise AssertionError('Unexpected logging boundary address')
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured original feat-slot dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df8f8,rules)
 m.wq(rules+0x118,races);m.wq(rules+0x110,classes);u.mem_write(actor+0x50,struct.pack('<H',c['raceId']))
 rp=races+c['raceId']*0x68;m.wi(rp+0x58,c['period']);m.wi(rp+0x5c,c['number']);m.wi(rp+0x48,c['extra'])
 byte(actor+0x69,len(c['levels']));byte(actor+0x6a,c['current'])
 for at,entry in enumerate(c['levels']):
  byte(actor+0x295+at*0x150,entry['classId']);byte(actor+0x296+at*0x150,entry['level'])
  u.mem_write(classes+entry['classId']*0x530+0x2ba,bytes(v&255 for v in c['classBonus'][str(entry['classId'])]))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8],[actor,normal,bonus]):u.reg_write(reg,v)
 u.emu_start(0x1407ec290,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,normal=u.mem_read(normal,1)[0],bonus=u.mem_read(bonus,1)[0])
if __name__=='__main__':
 rng=random.Random(91024);cases=[]
 for index in range(288):
  levels=[dict(classId=at*3+1,level=[0,1,2,3,20,59,60,61,127,255][(index+at*3)%10])for at in range(1+index%8)]
  if index<64:levels=[dict(classId=7,level=[1,2,3,4,6,9,60,61][index%8])]
  cases.append(dict(raceId=index%9,period=[-2147483648,-3,-1,0,1,2,3,4,60,2147483647][index%10],number=[0,1,2,127,128,255,256,511,-1][index%9],extra=[0,1,2,127,255,256,-1][index%7],current=index%len(levels),levels=levels,classBonus={str(e['classId']):[rng.choice([0,1,2,127,255,256,-1])for _ in range(60)]for e in levels}))
 out=m.root/'backups/animations/native-creation-feat-slots-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 rows=[run(c)for c in cases];out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,procedures=[hex(lo)for lo,_ in ranges],rows=rows),indent=2))
 print(json.dumps(dict(output=str(out),cases=len(rows),boundaries=[],publicConnections=0,gpu=False)))
