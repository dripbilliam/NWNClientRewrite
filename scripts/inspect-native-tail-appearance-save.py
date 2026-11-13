"""Execute original WORDandBYTE and verified appearance save slices unchanged.

Complete1401a3790 uses captured GFF field-table/CRT formatting boundaries. The
client807950 slice848e..8bbd writes appearance and reference-only equipped outfit;
the item46b760 model3 slice9ab..d63 writes19armor parts/six colors. Per-part
colors are authored255 (native absent). This is typed field/call proof, not full
BIC serialization, actual server loading, creator interaction or rendering.
"""
import importlib.util,json,hashlib,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
owner,record,actor,stats,appearance,item,label,ref=[m.heap+n*0x1000 for n in range(1,9)]
allocation=0;fields={};calls=[];field_nodes={};field_order=[];stop_at=m.stop;equip={}
def allocate(size):
 global allocation
 pointer=m.heap+0x10000+allocation;allocation+=(max(size,1)+15)&~15;assert allocation<0x80000
 return pointer
def text(pointer):
 data=bytearray()
 while pointer and u.mem_read(pointer,1)[0]:data.extend(u.mem_read(pointer,1));pointer+=1
 return data.decode('latin1')
def write(kind,key,value):fields[key]={'type':kind,'value':value};calls.append([kind,key,value])
def hook(_u,address,_n,_):
 if address==stop_at or address==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if address==0x1401a2a80:
  if y:write(0,text(w),z&255)
  m.finish(int(bool(y)))
 elif address in [0x1401a34f0,0x1401a36f0,0x1401a31d0]:write({0x1401a34f0:5,0x1401a36f0:2,0x1401a31d0:4}[address],text(w),z&0xffffffff);m.finish(1)
 elif address==0x140085bd0:
  assert text(z)=='%s%s' and text(w)=='x' and y==17
  original=m.q(u.reg_read(UC_X86_REG_RSP)+0x28);result=('x'+text(original)).encode('latin1')[:16];u.mem_write(x,result+b'\0');m.finish(len(result))
 elif address==0x14019fcc0:
  key=text(z);field_order.append(key) if key not in field_order else None;m.finish(field_order.index(key))
 elif address==0x14019fc20:m.finish(field_nodes.get(field_order[z],0))
 elif address==0x14019edb0:
  key=text(z);pointer=allocate(16);field_nodes[key]=pointer;u.mem_write(pointer,bytes(16));m.finish(pointer)
 elif address in [0x140c10324,0x140c10368]:m.finish(allocate(x))
 elif address in [0x140c10360,0x140c10370,0x140c10410]:m.finish()
 elif address==0x14019f1e0:equip['listName']=text(w);m.finish(1)
 elif address==0x14019f2b0:equip['structType']=w;m.finish(1)
 elif address==0x1401a2ec0:equip['field']=text(w);equip['value']=text(z);m.finish(1)
 elif address==0x140047000:
  assert text(y)=='APart_%d_Col_%d';u.mem_write(x,(f'APart_{z}_Col_{w}').encode()+b'\0');m.finish(1)
 elif address==0x14029dd60:m.finish(255)
 elif not (0x1401a3790<=address<=0x1401a387d or 0x14080884e<=address<0x140808bbd or 0x14046b9ab<=address<0x14046bd63):raise AssertionError(f'Uncaptured save dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def reset():
 global allocation,fields,calls,field_nodes,field_order,equip
 allocation=0;fields={};calls=[];field_nodes={};field_order=[];equip={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 for register in [UC_X86_REG_RAX,UC_X86_REG_RBX,UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9,UC_X86_REG_R12,UC_X86_REG_R13,UC_X86_REG_R14,UC_X86_REG_R15]:u.reg_write(register,0)
 u.reg_write(UC_X86_REG_RSP,m.stack+0x1fc00);u.reg_write(UC_X86_REG_RBP,m.stack+0x1fe00)
def finish_fields():
 for key,pointer in field_nodes.items():fields[key]={'type':2,'value':m.q(pointer+8)&0xffffffff}
 return fields.copy()
def invoke(start,end):
 global stop_at
 stop_at=end
 try:u.emu_start(start,m.stop,count=100000)
 except Exception:print(json.dumps({'rip':hex(u.reg_read(UC_X86_REG_RIP)),'calls':calls}));raise
 assert u.reg_read(UC_X86_REG_RIP)==end
def primitive(name,value):
 reset();u.mem_write(label,name.encode()+b'\0');rsp=u.reg_read(UC_X86_REG_RSP)-8;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[owner,record,value,label]):u.reg_write(r,v)
 invoke(0x1401a3790,m.stop)
 return {'label':name,'value':value,'fields':finish_fields(),'result':u.reg_read(UC_X86_REG_RAX)&0xffffffff}
def client(value):
 reset();m.wq(actor+0x3b0,stats);m.wq(actor+0x300,appearance)
 for offset,key in [(0xe6,'skin'),(0xe7,'hair'),(0xe8,'tattoo1'),(0xe9,'tattoo2'),(0xea,'phenotype')]:u.mem_write(stats+offset,bytes([value[key]]))
 for offset,key in [(0xe4,'appearanceId'),(0xec,'head')]:u.mem_write(stats+offset,value[key].to_bytes(2,'little'))
 for at,part in enumerate(value['skinParts']):u.mem_write(appearance+0x26+at*2,part.to_bytes(2,'little'))
 m.wi(stats+0xf0,value['tail']);m.wi(stats+0xf4,value['wings']);u.mem_write(ref,value['clothingResRef'].encode()+b'\0');m.wq(u.reg_read(UC_X86_REG_RSP)+0x40,ref)
 for r,v in [(UC_X86_REG_R15,actor),(UC_X86_REG_R13,appearance),(UC_X86_REG_RBX,owner)]:u.reg_write(r,v)
 invoke(0x14080884e,0x140808bbd)
 return {'input':value,'fields':finish_fields(),'equipment':equip.copy()}
def outfit(value):
 reset()
 for at,color in enumerate(value['materialColors']):u.mem_write(item+8+at,bytes([color]))
 for at,part in enumerate(value['bodyParts']):u.mem_write(item+0x3a2+at*2,part.to_bytes(2,'little'))
 for r,v in [(UC_X86_REG_RSI,item),(UC_X86_REG_R15,record),(UC_X86_REG_R14,owner),(UC_X86_REG_R12,0)]:u.reg_write(r,v)
 invoke(0x14046b9ab,0x14046bd63)
 return {'input':value,'fields':finish_fields()}
if __name__=='__main__':
 primitives=[primitive(name,value) for name in ['Appearance_Head','BodyPart_Torso','ArmorPart_Pelvis','ArmorPart_LShoul','1234567890123456'] for value in [0,1,254,255,256,300,511,65535]]
 clients=[];outfits=[]
 for seed in range(12):
  base=[0,1,255,256,300,65535][seed%6]
  value={'appearanceId':(300+seed)&65535,'head':base,'phenotype':seed,'skin':255-seed,'hair':seed,'tattoo1':seed+1,'tattoo2':seed+2,'tail':seed*3,'wings':seed*5,'skinParts':[(base+at*397)&65535 for at in range(19)],'clothingResRef':f'active_outfit{seed}'}
  clients.append(client(value));outfits.append(outfit({'bodyParts':[(base+at*577)&65535 for at in range(19)],'materialColors':[(seed*19+at)&255 for at in range(6)]}))
 output=m.root/'godot-client/reports/native-tail-appearance-save-original-v1.json';assert not output.exists(),'Preserve prior original evidence'
 output.write_text(json.dumps({'success':True,'binarySha256':m.digest,'scriptSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'scope':__doc__,'primitives':primitives,'clients':clients,'outfits':outfits},indent=2)+'\n')
 print(json.dumps({'success':True,'primitiveCases':len(primitives),'clientSlices':len(clients),'outfitSlices':len(outfits),'output':str(output),'gpu':False,'serverConnections':0}))
