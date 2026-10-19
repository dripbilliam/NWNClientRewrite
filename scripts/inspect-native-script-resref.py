"""Complete original GetResRef/GetTilesetResRef shared owner and LowerCase.
Original base/CNWSObject/area/module/sound-CGameObject casts execute from native
vftables, including area's -0x138 adjustment. VM/object lookup, explicit-length
string construction/allocation/copy and CRT tolower are captured lower boundaries.
Case conversion uses the established ASCII C-locale boundary; high bytes and
native process locale/config changes are not claimed. Synthetic changing casts
exercise the owner's second-null guard and first-cast precedence separately.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
cmd,app,objectPtr,area,table,text,allocation=[m.heap+i*0x2000 for i in range(1,8)]
syntheticObject,syntheticArea=m.stop+0x80,m.stop+0x90
vtables={'base':0x140dc2ab0,'object':0x140df0fb8,'area':0x140ddad88,'module':0x140def280,'sound':0x140df6320}
castTargets={m.q(v+slot)for v in vtables.values()for slot in[0x20,0x50]}
ranges=[(0x14052fba0,0x14052fe62),(0x14016bd70,0x14016bdde)]+[(a,a+0x30)for a in castTargets]
def descriptor(ptr):return bytes(u.mem_read(m.q(ptr),m.si(ptr+8)))if m.q(ptr)else b''
def cstring(ptr):
 out=bytearray()
 while ptr:
  byte=u.mem_read(ptr,1)[0]
  if not byte:break
  out.append(byte);ptr+=1
 return bytes(out)
def allocate(data):
 global cursor
 ptr=allocation+cursor;cursor+=(len(data)+31)&~15;u.mem_write(ptr,data+b'\0');return ptr
def assign(ptr,data):
 data=data if data and data[0]else b'';m.wq(ptr,allocate(data)if data else 0);m.wi(ptr+8,len(data));m.wi(ptr+12,len(data)+1 if data else 0)
def hook(u,a,n,_):
 global output,frees,objectCasts
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140286160:calls.append(['pop','object']);m.wi(y,c['id']);m.finish(c['pop']);return
 if a==0x14055b4c0:calls.append(['object',y&0xffffffff]);m.finish(0 if c['kind']=='missing'else area+0x138 if c['kind']=='area'else objectPtr);return
 if a in castTargets:
  ret=m.q(rsp);name='asObject'if ret in[0x14052fceb,0x14052fcf9]else'asArea';calls.append([name]);return # actual original leaf executes
 if a==syntheticObject:
  calls.append(['asObject']);objectCasts+=1;m.finish(0 if c['kind']=='second-null'and objectCasts==2 else objectPtr);return
 if a==syntheticArea:calls.append(['asArea']);m.finish(area);return
 if a==0x14003d8c0:assign(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x140c10368:m.finish(allocate(bytes(x)));return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a in[0x140c10360,0x140c10370]:frees+=1;m.finish();return
 if a==0x14016bd70:calls.append(['lowercase',descriptor(x).hex()]) # execute complete original owner
 if a==0x140c7fe98:
  byte=x&255
  if byte>127:raise RuntimeError('Oracle locale-specific byte is outside its stated boundary')
  m.finish(byte+32 if 65<=byte<=90 else byte);return
 if a==0x140286550:output=descriptor(y).hex();calls.append(['push',output]);m.finish(c['push']);return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured resource-reference dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,output,frees,cursor,objectCasts
 c=case;calls=[];output=None;frees=0;cursor=0;objectCasts=0;u.mem_write(m.heap,bytes(0x30000));u.mem_write(m.stack,bytes(0x20000));m.wq(0x1412df970,app);m.wq(app+8,app)
 m.wq(objectPtr,vtables.get(c['kind'],table));m.wq(area+0x138,vtables['area']);m.wq(table+0x20,syntheticObject);m.wq(table+0x50,syntheticArea)
 data=bytes.fromhex(c['hex']);u.mem_write(text,data+b'\0');m.wq(objectPtr+0x30,0 if c.get('nullString')else text);m.wi(objectPtr+0x38,len(data));m.wi(objectPtr+0x3c,len(data)+1)
 for offset in[0x120,0x1a8]:u.mem_write(area+offset,bytes.fromhex(c['areaHex'if offset==0x120 else'tilesetHex']).ljust(17,b'\0'))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,cmd);u.reg_write(UC_X86_REG_RDX,c['command']);u.reg_write(UC_X86_REG_R8,1)
 try:u.emu_start(0x14052fba0,m.stop,count=30000)
 except Exception as error:raise RuntimeError(f'Resource oracle RIP={u.reg_read(UC_X86_REG_RIP):x} case={c} calls={calls}')from error
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,output=output,calls=calls,frees=frees)
if __name__=='__main__':
 d=dict(command=582,kind='object',hex='4d695865445f526566',areaHex='417245615f4e614d65',tilesetHex='54696c65735f4d69586544',id=0x80000001,pop=1,push=1)
 texts=['','004142','4142004344','4d695865445f526566','4142434445464748494a4b4c4d4e4f50','4142434445464748494a4b4c4d4e4f505152535455565758595a','41252f5c5f2d2030']
 rows=[run(d|dict(command=command,kind=kind,hex=text,pop=pop,push=push))for command,kind,text,pop,push in itertools.product([582,814,581],['missing','base','object','area','module','sound','second-null','both'],texts,[0,1],[0,1])]
 rows +=[run(d|dict(kind='object',nullString=True)),run(d|dict(kind='area',areaHex='410042',tilesetHex='004142'))]
 for command,reference in itertools.product([582,814],['','004142','410042','4142434445464748494a4b4c4d4e4f50']):rows.append(run(d|dict(kind='area',command=command,areaHex=reference,tilesetHex=reference)))
 out=m.root/'backups/animations/native-script-resref-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,virtualSlots={kind:{hex(slot):hex(m.q(table+slot))for slot in[0x20,0x50]}for kind,table in vtables.items()},rows=rows),indent=2)+'\n');print(json.dumps(dict(output=str(out),rows=len(rows),castTargets=[hex(a)for a in castTargets])))
