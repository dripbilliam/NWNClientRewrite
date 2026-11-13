"""Execute unchanged original InitLegacyClassDefaults for every physical BYTE
class ID over two nonzero memory fills. Allocation/free and CExoString storage
are explicit providers; string pointer/length call arguments are captured.
Numeric/boolean/byte/float writes and branches execute original instructions.
No game process, server, GPU or profile is used.
"""
import importlib.util,json,hashlib
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
rules=m.heap+0x1000;classes=m.heap+0x3000;temporary=m.heap+0xf0000
entry,end=0x1402a4350,0x1402a484c
fields={'MemorizesSpells':(0x4ec,4),'SpellbookRestricted':(0x4f0,4),'PickDomains':(0x4f4,4),'PickSchool':(0x4f8,4),'LearnScroll':(0x4fc,4),'Arcane':(0x500,4),'ASF':(0x504,4),'CastingAbility':(0x4e8,1),'MinCastingLevel':(0x51c,4),'CanCastSpontaneously':(0x520,4),'MinAssociateLevel':(0x524,1),'SkipSpellSelection':(0x528,4)}
strings=[];calls=[]
def hook(_u,address,_size,_):
 if address==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(reg) for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if address==0x140c10368:
  assert 0<x<128
  calls.append(['allocate',x]);m.finish(temporary)
 elif address==0x140c10370:calls.append(['free',x]);m.finish()
 elif address==0x14003d8c0:
  assert 0<=z<=127
  value=bytes(u.mem_read(y,z)).decode('ascii');strings.append(dict(destination=x-classes,value=value,length=z));m.finish()
 elif not entry<=address<=end:raise AssertionError(f'Uncaptured original initializer dependency {address:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(class_id,fill):
 global strings,calls
 strings=[];calls=[]
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));u.mem_write(classes,bytes([fill])*0x53000)
 m.wq(rules+0x110,classes)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,rules);u.reg_write(UC_X86_REG_RDX,class_id)
 u.emu_start(entry,m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 pointer=classes+class_id*0x530
 values={key:int.from_bytes(u.mem_read(pointer+offset,size),'little') for key,(offset,size) in fields.items()}
 values['CLMultiplier']=m.rf(pointer+0x518)
 assert len(strings)==1 and strings[0]['destination']==class_id*0x530+0x508
 values['SpellTableColumn']=strings[0]['value']
 return dict(classId=class_id,fill=fill,fields=values,services=list(calls),stringWrite=dict(strings[0]))
if __name__=='__main__':
 output=m.root/'godot-client/reports/native-legacy-class-defaults-original-v1.json'
 assert not output.exists(),'Preserve existing evidence'
 rows=[run(class_id,fill) for class_id in range(256) for fill in [0xa5,0x5a]]
 for class_id in range(256):assert rows[class_id*2]['fields']==rows[class_id*2+1]['fields'],'Observed fields must be initialized, not inherited from dirty heap'
 output.write_text(json.dumps(dict(success=True,binarySha256=m.digest,scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope=__doc__,entry=hex(entry),inclusiveRange=[hex(entry),hex(end)],serviceBoundaries={'0x140c10368':'captured allocation','0x140c10370':'captured free','0x14003d8c0':'captured CExoString initialization with observed source bytes/length'},rows=rows),indent=2)+'\n')
 print(json.dumps(dict(success=True,output=str(output),cases=len(rows),seedIndependent=256,serverConnections=0,gpu=False)))
