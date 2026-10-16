"""Original first-client object predicate14035bc80..14035bd23 and
placeable static import1404b4f07..1404b4f6e. Bounded owner blocks, not the full
area insertion or placeable loader. Virtual casts/GFF BYTE reads are captured;
the door GetScriptName leaf executes unchanged. Type slots checked via RTTI.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle);actor,vt=[m.heap+i*0x1000 for i in range(2)]
assert m.q(0x140df7608+0x80)==0x1404ff920
assert m.q(0x140df6858+0xa8)==0x1404f6b20
assert m.q(0x140de7288+0x1e0)==0x140420880
casts={m.stop+0x100:('asCreature',5),m.stop+0x110:('asAreaEffect',11),m.stop+0x120:('asTrigger',7),m.stop+0x130:('asDoor',10),m.stop+0x140:('asPlaceable',9)}
def hook(u,a,n,_):
 global result
 if a in [0x14035bd12,0x14035bd23,0x1404b4f6e]:result=a==0x14035bd12;u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a in casts:
  name,kind=casts[a];calls.append([name]);m.finish(x if c['type']==kind else 0)
 elif a==0x140420880:calls.append(['scriptName',y&0xffffffff])
 elif a==0x1401a0f60:
  label=bytes(u.mem_read(z,16)).split(b'\0')[0].decode('ascii');value=c.get(label);m.wi(w,int(value is not None));m.finish(int((value&255)!=0) if value is not None else 0)
 elif not any(lo<=a<hi for lo,hi in [(0x14035bc80,0x14035bd23),(0x140420880,0x140420899),(0x1404b4f07,0x1404b4f6e)]):raise RuntimeError(f'Unmapped activation dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,result
 c=case;calls=[];result=None;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));rsp=m.stack+0x1fe08;u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RBX,actor);u.reg_write(UC_X86_REG_R13,0)
 m.wq(rsp+0x40,actor);m.wq(actor,vt);m.wi(actor+0x360,c.get('length',0));m.wi(actor+0x5a0,c.get('static',0));m.wi(actor+0x5a4,c.get('override',0))
 for offset,address in [(0x60,m.stop+0x100),(0xa8,m.stop+0x110),(0x80,m.stop+0x120),(0x30,m.stop+0x130),(0x98,m.stop+0x140),(0x1e0,0x140420880)]:m.wq(vt+offset,address)
 start=0x14035bc80 if c['operation']=='predicate' else 0x1404b4f07
 u.emu_start(start,m.stop,count=5000);assert result is not None
 return dict(case=c,calls=calls,result=result,static=m.si(actor+0x5a0),usable=m.si(actor+0x264))
rows=[run(dict(operation='predicate',type=kind,static=static,length=length)) for kind,static,length in itertools.product(range(3,17),[0,1,2],[0,1,16])]
rows += [run(dict(operation='static',Useable=usable,Static=static,override=override)) for usable,static,override in itertools.product([None,0,1,2,256],[None,0,1,2,256],[0,1,2])]
out=m.root/'backups/animations/native-first-client-activation-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
