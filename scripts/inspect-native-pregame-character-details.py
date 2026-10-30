"""Read-only complete original pregame Character SetData execution.
Original numeric/detail enumeration, save formatting, class BAB lookup and
alignment helpers execute unchanged. Allocation/string/TLK/portrait/list-layout
services are captured. Imported stats, combat bytes and active tables are
fixtures; this does not execute a complete BIC import or render the original UI.
"""
import importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,rules,page,labels,vtable,strings,classes,combat=[m.heap+n for n in [0x1000,0x10000,0x20000,0x24000,0x28000,0x30000,0x50000,0x55000]]
text_stub,clear_stub=m.stop+0x100,m.stop+0x200
ranges=[(0x1409bbfc0,0x1409beb1f),(0x1407ec3a0,0x1407ec50b),(0x1407f5e20,0x1407f5e28),(0x1407ef9c0,0x1407efa32),(0x1407f5d70,0x1407f5e11),(0x1407f3da0,0x1407f3dbc),(0x1407ef040,0x1407ef20e),(0x1407ef440,0x1407ef52f),(0x1407ef6a0,0x1407ef8a5),(0x1407ef8b0,0x1407ef925),(0x1407ef930,0x1407ef9b3),(0x1407f0900,0x1407f0ad5),(0x1402997b0,0x1402997c3),(0x1407f7450,0x1407f74c5),(0x1407f6630,0x1407f664b),(0x1407f6650,0x1407f66b1),(0x1407f66c0,0x1407f66d1)]
def q(p):return int.from_bytes(u.mem_read(p,8),'little')
def readstr(p):return bytes(u.mem_read(p,4096)).split(b'\0')[0].decode('cp1252') if p else ''
def signed32(v):return (v&0xffffffff)-0x100000000 if v&0x80000000 else v&0xffffffff
def alloc(size):
 global allocated
 out=strings+allocated;allocated+=(size+15)&~15;assert allocated<0x18000
 return out
def string(p,text):
 data=text.encode('cp1252');out=alloc(len(data)+1);u.mem_write(out,data+b'\0');m.wq(p,out);m.wi(p+8,len(data));m.wi(p+12,len(data)+1)
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1402ae870:
  key=readstr(x);key='C'+key if key.startswith('HARGEN_')else key;keys.append(key);m.finish(len(keys))
 elif a==0x1402a4130:m.finish(settings.get(keys[y-1],z&0xffffffff))
 elif a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX))
 elif a in [0x140c10370,0x140115890,0x14084c550,0x1409befc0]:m.finish()
 elif a==0x140c10368:m.finish(alloc(x))
 elif a==0x14016afb0:
  fmt=readstr(y);rsp=u.reg_read(UC_X86_REG_RSP);args=[z,w]+[q(rsp+offset)for offset in range(40,88,8)];at=0;out='';pos=0
  while pos<len(fmt):
   if fmt[pos]=='%':
    kind=fmt[pos+1];pos+=2
    if kind=='%':out+='%';continue
    value=args[at];at+=1;out+=readstr(value) if kind=='s' else str(signed32(value)) if kind in ['d','i'] else (_ for _ in ()).throw(AssertionError(kind))
   else:out+=fmt[pos];pos+=1
  string(x,out);m.finish()
 elif a==0x14016ab00:string(y,readstr(q(x))+readstr(q(z)));m.finish(y)
 elif a==0x140044840:
  assert m.stack<=y<m.stack+0x20000 or m.heap<=y<m.heap+0x100000,f'Invalid string wrapper at {x:x}/{y:x}; rows={captured}'
  u.mem_write(x,bytes(u.mem_read(y,16)));u.mem_write(y,bytes(16));m.finish()
 elif a==0x14016c810:string(x,str(signed32(y)));m.finish(x)
 elif a==0x14003d8c0:string(x,readstr(y) if z&0xffffffff==0xffffffff else readstr(y)[:z&0xffffffff]);m.finish(x)
 elif a==0x140198c60:string(z,lookup[str(y&0xffffffff)]);m.finish(1)
 elif a==0x14018ded0:u.mem_write(x,readstr(y).encode('cp1252')[:16].ljust(17,b'\0'));m.finish(x)
 elif a==0x14081b220:m.finish()
 elif a==0x1409bef10:m.finish()
 elif a==0x14084c2f0:u.mem_write(y,bytes(17));m.finish(y)
 elif a==0x1409d0820:captured.append(readstr(q(w)));m.finish()
 elif a==0x1401e9660:m.finish(len(captured))
 elif a==text_stub:m.finish()
 elif a==clear_stub:captured.clear();m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured Character detail dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def call(address,args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value)
 u.emu_start(address,m.stop,count=1000000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
def run(row,index):
 global settings,keys,captured,allocated,lookup
 settings={};keys=[];captured=[];allocated=0
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 alignments=[(law,good)for law in [0,50,100]for good in [0,50,100]]+[(30,70),(31,69),(69,31),(70,30),(15,85),(85,15)];law,good=alignments[index%len(alignments)]
 source=dict(stats=row['source']['stats'],goodEvil=good,lawChaos=law,savingThrows=[[-128,0,1,127,-1][(index+at)%5]for at in range(3)],combatPreview=[[0,1,127,128,255][index%5],(index*17)&255,(index*9)&255])
 tables=json.loads(json.dumps(row['tables']))
 for at,data in enumerate(tables['classes']['orderedRows']):
  data['AttackBonusTable']='fixturebab'+str(at);tables[data['AttackBonusTable']]=dict(orderedRows=[dict(BAB=(level*(at+1)+index)&255)for level in range(60)])
 lookup={str(ref):'Label'+str(ref)+(': ' if ref not in [317,318,319,314,315,10335,264,265,266,267,268] else '')for ref in [317,318,319,40424,58348,58349,58350,58351,58352,66198,314,315,10335,264,265,266,267,268,10500,10502,10503,10504,10505,10506,10507,10508,10509]}
 if index%3==1:lookup['58349']='Server resistance=';lookup['317']='Server save: '
 m.wq(0x1412df8f8,rules);m.wq(0x1412df968,strings+0x1f000);m.wq(rules+0x110,classes);u.mem_write(rules+0x105,bytes([len(tables['classes']['orderedRows'])]));m.wq(actor+0xa8,combat)
 m.wq(vtable+0xd0,text_stub);m.wq(vtable+0x110,clear_stub);m.wq(page+0xfd0,vtable)
 for offset in [0x188,0x940,0xf30,0xfc8]:label=labels+offset;m.wq(page+offset,label);m.wq(label,vtable)
 for at in range(41):m.wi(rules+0x28+at*4,777)
 for offset,key in [(0xc6,'goodEvil'),(0xc8,'lawChaos')]:u.mem_write(actor+offset,struct.pack('<h',source[key]))
 for offset,value in zip([0x98,0x9a,0x99],source['savingThrows']):u.mem_write(actor+offset,bytes([value&255]))
 u.mem_write(combat+5,bytes(source['combatPreview']));u.mem_write(actor+0x9b,b'\xff');u.mem_write(actor+0x70,bytes(row['scores']));u.mem_write(actor+0x69,bytes([len(source['stats']['classes'])]))
 for at,item in enumerate(source['stats']['classes']):u.mem_write(actor+0x295+at*0x150,bytes([item['id'],item['level'],0]))
 for at,data in enumerate(tables['classes']['orderedRows']):u.mem_write(classes+at*0x530+0x38,bytes(entry['BAB']for entry in tables[data['AttackBonusTable']]['orderedRows']))
 call(0x1409bbfc0,[page,actor,8])
 return dict(source=source,tables=tables,lookup=lookup,captured=list(captured))
if __name__=='__main__':
 prior=json.loads((m.root/'backups/animations/native-pregame-character-observations-v1.json').read_text())
 rows=[run(row,index)for index,row in enumerate(prior['rows'])]
 out=m.root/'backups/animations/native-pregame-character-detail-observations-v2.json';assert not out.exists(),'Preserve prior evidence';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),cases=len(rows))))
