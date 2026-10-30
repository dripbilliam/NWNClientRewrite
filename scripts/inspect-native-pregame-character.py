"""Read-only original pregame Character numeric prefix, not a full UI oracle.
Executes unchanged SetData1409bbfc0 through its XP/next-level labels and stops
before portrait/details. Original modifier, HP/AC, level and XP getters execute.
CExoString formatting, TLK and label writes are captured service boundaries.
Initial imported stats/scores are fixtures; score fixtures come from the earlier
unchanged original class/race skill oracle. No process or server connection.
"""
import importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,rules,page,labels,vtable,strings=[m.heap+n for n in [0x1000,0x10000,0x20000,0x24000,0x28000,0x30000]]
text_stub=m.stop+0x100
ranges=[(0x1409bbfc0,0x1409bcf6b),(0x1407ec3a0,0x1407ec50b),(0x1407f5e20,0x1407f5e28),(0x1407ef9c0,0x1407efa32),(0x1407f5d70,0x1407f5e11),(0x1407f3da0,0x1407f3dbc),(0x1407ef2f0,0x1407ef43c)]
def readstr(p):
 return bytes(u.mem_read(p,512)).split(b'\0')[0].decode('cp1252') if p else ''
def signed32(v):return (v&0xffffffff)-0x100000000 if v&0x80000000 else v&0xffffffff
def string(p,text):
 global allocated
 data=text.encode('cp1252');out=strings+allocated;allocated+=len(data)+1
 u.mem_write(out,data+b'\0');m.wq(p,out);m.wi(p+8,len(data));m.wi(p+12,len(data)+1)
def hook(u,a,n,_):
 if a in [m.stop,0x1409bcf6b]:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1402ae870:
  key=readstr(x);key='C'+key if key.startswith('HARGEN_')else key;keys.append(key);m.finish(len(keys))
 elif a==0x1402a4130:m.finish(settings.get(keys[y-1],z&0xffffffff))
 elif a in [0x140c10370,0x140c10410,0x140115890]:m.finish()
 elif a==0x14016afb0:
  fmt=readstr(y);rsp=u.reg_read(UC_X86_REG_RSP);args=[z,w,int.from_bytes(u.mem_read(rsp+40,8),'little')];at=0;out='';pos=0
  while pos<len(fmt):
   if fmt[pos]=='%':
    kind=fmt[pos+1];value=args[at];at+=1;out+=readstr(value) if kind=='s' else str(signed32(value)) if kind=='d' else (_ for _ in ()).throw(AssertionError(kind));pos+=2
   else:out+=fmt[pos];pos+=1
  string(x,out);m.finish()
 elif a==0x140198c60:string(z,{314:'XP label',315:'Next label',10335:'Maximum label'}[y&0xffffffff]);m.finish(1)
 elif a==0x14081b220:captured[str(x-page)]=readstr(y);m.finish()
 elif a==0x1409bef10:captured['ac']=str(signed32(y));m.finish()
 elif a==text_stub:captured[str(x-labels)]=readstr(y);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured pregame Character dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=1000000)
 assert u.reg_read(UC_X86_REG_RIP) in [m.stop,0x1409bcf6b]
 return u.reg_read(UC_X86_REG_RAX)
def run(row,index):
 global settings,keys,captured,allocated
 settings=row['case']['settings'];keys=[];captured={};allocated=0
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 source=dict(stats=row['case']['source'],armorClass=[0,19,-7,32767,-32768][index%5],maximumHP=[0,38,-1,32767,-32768][index%5],currentHP=[0,17,-12,32767,-32768][index%5],experience=[0,23456,0xffffffff,0x80000000][index%4],lawChaos=[0,30,31,50,69,70,100][index%7],goodEvil=[100,70,69,50,31,30,0][index%7])
 m.wq(0x1412df8f8,rules);m.wq(0x1412df968,strings+0x20000);m.wq(vtable+0xd0,text_stub)
 for offset in [0x188,0x940,0xf30,0xfc8]:
  label=labels+offset;m.wq(page+offset,label);m.wq(label,vtable)
 for at,xp in enumerate(xptable):m.wi(rules+0x28+at*4,xp)
 for offset,key in [(0x8c,'armorClass'),(0x8a,'maximumHP'),(0x88,'currentHP'),(0xc6,'goodEvil'),(0xc8,'lawChaos')]:u.mem_write(actor+offset,struct.pack('<h',source[key]))
 m.wi(actor+0x94,source['experience']);u.mem_write(actor+0x70,bytes(row['scores']))
 u.mem_write(actor+0x69,bytes([len(source['stats']['classes'])]))
 for at,item in enumerate(source['stats']['classes']):u.mem_write(actor+0x296+at*0x150,bytes([item['level']]))
 call(0x1409bbfc0,[page,actor,8]);alignment=call(0x1407ef2f0,[actor,0])
 return dict(source=source,tables=dict(row['case']['tables'],exptable=dict(orderedRows=[dict(XP=x)for x in xptable])),scores=row['scores'],captured=dict(captured),alignmentRef=alignment)
if __name__=='__main__':
 prior=json.loads((m.root/'backups/animations/native-pregame-skill-observations-v1.json').read_text())
 xptable=[at*999+37 for at in range(41)]
 rows=[run(row,index)for index,row in enumerate(prior['rows'])]
 out=m.root/'backups/animations/native-pregame-character-observations-v1.json';assert not out.exists(),'Preserve prior evidence'
 out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
