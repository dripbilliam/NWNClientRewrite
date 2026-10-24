"""Original CreateBodyParts palette loop and robe-hide branch only.
Native table lookup is captured; model creation, resources and GPU are not run.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
actor,parts,rules,tables,table,out=[m.heap+n*0x1000 for n in range(1,7)]
bp=m.stack+0x10000
def hook(u,a,n,data):
 if a in [0x140974660,0x1409749b5,0x14097600a]:u.emu_stop();return
 if a==0x1401a7120:
  reads.append(dict(row=u.reg_read(UC_X86_REG_RDX),column=u.reg_read(UC_X86_REG_R8)))
  m.wi(u.reg_read(UC_X86_REG_R9),hide);m.finish(int(found));return
 if not(0x140974570<=a<0x140974660 or 0x14097494d<=a<0x1409749b5):raise RuntimeError(hex(a))
u.hook_add(UC_HOOK_CODE,hook)
def reset():
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(bp-0x100,bytes(0x1000));u.reg_write(UC_X86_REG_RBP,bp);u.reg_write(UC_X86_REG_RSP,bp-0x200)
paletteRows=[]
for seed in range(8):
 reset();base=[(seed*23+c*31)&255 for c in range(6)];overrides=[[(255 if(i+c+seed)%3 else(i*17+c+seed)&255)for c in range(6)]for i in range(19)]
 u.mem_write(actor+0x4c,bytes(base));u.mem_write(actor+0x52,bytes(v for row in overrides for v in row));m.wq(bp-0x50,actor)
 skin,hair,t1,t2=[(seed*19+i*37)&255 for i in range(4)]
 for reg,value in [(UC_X86_REG_R8,actor),(UC_X86_REG_RDI,actor+0x52),(UC_X86_REG_R14,0),(UC_X86_REG_RBX,out+16),(UC_X86_REG_R15,skin),(UC_X86_REG_R12,hair|0x100),(UC_X86_REG_R13,t1|0x600),(UC_X86_REG_RSI,t2|0x600)]:u.reg_write(reg,value)
 u.emu_start(0x140974570,m.stop,count=10000)
 paletteRows.append(dict(base=base,overrides=overrides,skin=skin,hair=hair,tattoo1=t1,tattoo2=t2,palettes=[list(struct.unpack('<10H',bytes(u.mem_read(out+i*20,20))))for i in range(19)]))
hideRows=[]
for index,robe,found,hide in itertools.product(range(19),[0,1,2,3,321,65535],[False,True],[-1,0,1,2]):
 reset();reads=[];u.mem_write(parts,struct.pack('<19H',*([7]*18+[robe])));m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(tables+0x380,table)
 for reg,value in [(UC_X86_REG_RCX,parts),(UC_X86_REG_RBX,index),(UC_X86_REG_R12,index),(UC_X86_REG_R15,robe if index==18 else 7),(UC_X86_REG_RDI,index)]:u.reg_write(reg,value)
 u.emu_start(0x14097494d,m.stop,count=1000)
 hideRows.append(dict(index=index,robe=robe,found=found,hide=hide,part=u.reg_read(UC_X86_REG_R15)&65535,absent=u.reg_read(UC_X86_REG_RIP)==0x14097600a,reads=reads))
output=m.root/'backups/animations/native-robe-part-plan-v1.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,palettes=paletteRows,visibility=hideRows),indent=2)+'\n');print(json.dumps(dict(palettes=len(paletteRows)*19,visibility=len(hideRows))))
