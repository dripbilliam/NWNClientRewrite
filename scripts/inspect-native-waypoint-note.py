"""Read-only original LoadWaypoint note commit block14050a222..14050a2e8
and real BYTEasBOOL reader. GFF localized read/copy/ctor/dtor are captured lower
logical string boundaries; their full ownership isn't claimed by this block.
Canonical object identity/position are not changed. No process modification.
"""
import importlib,sys,json,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
p=importlib.import_module('inspect-native-area-properties');g=p.g;a=p.a;w=p.w;m=p.m;u=p.u;u.hook_del(p.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
object_=a.objectBase;valuePtr=object_+0x1000

def populate(ptr,data):a.populateName(ptr,[[e['languageId'],e['text'].encode('latin1').hex()]for e in data.get('entries',[])],data.get('strRef',0xffffffff))
def hook(u,at,n,_):
 x,y,z,q=[u.reg_read(reg)for reg in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if at==0x140169560:m.wq(x,0);m.wi(x+8,0xffffffff);m.finish(x);return
 if at==0x1401695b0:m.finish();return
 if at==0x140169600:m.wq(x,m.q(y));m.wi(x+8,m.si(y+8));m.finish(x);return
 if at==0x1401a0f80:
  data=p.context(z);found='MapNote'in data and data['MapNote'] is not None
  if found:populate(valuePtr,data['MapNote']);m.wq(y,m.q(valuePtr));m.wi(y+8,m.si(valuePtr+8))
  else:m.wq(y,0);m.wi(y+8,0xffffffff)
  m.wi(m.q(u.reg_read(UC_X86_REG_RSP)+0x28),int(found));m.finish(y);return
 if 0x14050a222<=at<0x14050a2e8:return
 p.hook(u,at,n,_)
u.hook_add(UC_HOOK_CODE,hook)

def snapshot():
 loc=object_+0x310;entries=[];private=m.q(loc)
 if private:
  node=m.q(m.q(private))
  while node:
   record=m.q(node+0x10);entries.append(dict(key=m.si(record)&0xffffffff,hex=p.cbytes(record+8).hex()));node=m.q(node+8)
 return dict(has=m.si(object_+0x308),enabled=m.si(object_+0x30c),strRef=m.si(loc+8)&0xffffffff,entries=entries)

def run(c):
 g.reset({});m.wq(object_+0x308,0);populate(object_+0x310,c.get('initial',dict(strRef=0xffffffff,entries=[])))
 m.wi(object_+0x308,c.get('has',0));m.wi(object_+0x30c,c.get('enabled',0));observations=[]
 for step in c['steps']:
  p.contexts={1:step};p.reads=[];p.nextToken=[10];m.wi(a.client,1);u.reg_write(UC_X86_REG_RSP,m.stack+0x1fc00);u.reg_write(UC_X86_REG_RBP,m.stack+0x1fd00);u.reg_write(UC_X86_REG_R14,object_);u.reg_write(UC_X86_REG_R13,a.array);u.reg_write(UC_X86_REG_RBX,a.client);u.reg_write(UC_X86_REG_R12,0)
  u.emu_start(0x14050a222,0x14050a2e8,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x14050a2e8;observations.append(snapshot())
 return dict(case=c,observations=observations)

if __name__=='__main__':
 rows=[]
 for has,enabled,note,old in itertools.product([None,0,1,2,256,-1],[None,0,1,2,256,-1],[None,dict(strRef=123,entries=[]),dict(strRef=0xffffffff,entries=[dict(languageId=0,text='Note')])],[False,True]):
  data={}
  if has is not None:data['HasMapNote']=has
  if enabled is not None:data['MapNoteEnabled']=enabled
  if note is not None:data['MapNote']=note
  initial=dict(has=1,enabled=1,initial=dict(strRef=456,entries=[])) if old else {}
  rows.append(run(dict(initial,steps=[data,{}])))
 out=m.root/'backups/animations/native-waypoint-note-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows),executions=sum(len(row['observations'])for row in rows))))
