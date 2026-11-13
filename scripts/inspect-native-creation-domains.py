"""Execute original domain add/remove/list-selection/help and OK/Cancel
callbacks plus domain setters/getters. GUI list mutation, button construction,
tab selection, font/color/lifetime and final class coordinator are explicit
service boundaries. This does not execute GUI geometry/pixels or table loading.
No live process, server connection, credential access or GPU work.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('image',Path(__file__).with_name('inspect-native-intratile-coordinator.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
panel,actor,stats,vtable,list_ids,list_buttons,help_rows,domain_table,rule,objects=[m.heap+n for n in[0x1000,0x5000,0x9000,0xd000,0xe000,0xf000,0x10000,0x18000,0x20000,0x30000]]
ranges=[(0x1409c7010,0x1409c71b0),(0x1409ca100,0x1409ca311),(0x1409ca840,0x1409ca8f4),(0x1409cb440,0x1409cb4f5),(0x1409c8730,0x1409c88e1),(0x1409c7be0,0x1409c7c3b),(0x1407f9c40,0x1407f9ca3),(0x1407f9cb0,0x1407f9d13)]
case={};texts={};calls=[];available=[];serial=0
def sync():
 m.wq(panel+0xaa8,list_ids);m.wq(panel+0x720,list_buttons);m.wi(panel+0x728,len(available))
 for n,id in enumerate(available):m.wi(list_ids+n*4,id);m.wq(list_buttons+n*8,objects+0x10000+id*0x200)
def make(id,chosen,index=-1):
 global serial
 if not chosen:
  if index<0:available.append(id)
  else:available.insert(index,id)
  sync();return
 ptr=objects+serial*0x200;serial+=1;m.wq(ptr,vtable);m.wi(ptr+0x198,id)
 if m.q(panel+0xe60)==0:m.wq(panel+0xe60,ptr)
 else:m.wq(panel+0xe68,ptr)
 m.wi(panel+0xe70,m.si(panel+0xe70)+1)
def hook(_u,a,_n,_):
 x,y,z,w=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==m.stop:u.emu_stop();return
 if a==0x1409c5980:make(y&0xffffffff,z&0xffffffff,w if w<0x80000000 else w-0x100000000);m.finish()
 elif a==0x1401edf40:
  index=y&0xffffffff;available.pop(index);sync();m.wi(panel+0x718,-1);m.finish()
 elif a==0x1401eff30:m.wi(x+0x10,y);m.finish()
 elif a==0x1401efd10:m.finish()
 elif a==0x1401e5ae0:m.finish()
 elif a==0x1401fb890:texts[hex(x-panel)]=y&0xffffffff;m.finish()
 elif a==0x1401eb800:m.wi(x+8,(m.si(x+8)&~1)|(0 if y else 1));m.finish()
 elif a in[0x1401fb540,0x1401fafa0,0x1401fb630,0x1401eb5c0]:m.finish()
 elif a==m.stop+0x10:m.finish()
 elif a==0x140800c90:m.finish(actor if case['present'] else 0)
 elif a in[0x1407f3cc0,0x1407f3d30]:m.finish(int(u.mem_read(stats+(0x293 if a==0x1407f3cc0 else 0x294),1)[0]))
 elif a==0x1402a3ba0:m.finish(domain_table+(y&65535)*0x50)
 elif a==0x140837cb0:calls.append(['grant',y&65535]);m.finish()
 elif a==0x1409c69a0:calls.append(['coordinator',w&0xffffffff]);m.finish()
 elif a==0x1407edcc0:calls.append(['reset-derived']);m.finish()
 elif a==0x1401fc440:calls.append(['deactivate',y&0xffffffff]);m.finish()
 elif not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured domain dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def invoke(address,*args):
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,value in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],args):u.reg_write(reg,value&0xffffffffffffffff)
 try:u.emu_start(address,m.stop,count=100000)
 except Exception:
  print(json.dumps(dict(entry=hex(address),rip=hex(u.reg_read(UC_X86_REG_RIP)),registers={str(r):hex(u.reg_read(r))for r in[UC_X86_REG_RAX,UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_RSP]},case=case,available=available,calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
def view():
 return dict(available=available.copy(),chosen=[m.si(m.q(panel+off)+0x198)for off in[0xe60,0xe68]if m.q(panel+off)],help=dict(texts),enabled=not bool(m.si(panel+0xc90)&1))
def run(sequence,present=True,mode=0,finish='ok'):
 global case,texts,calls,available,serial
 case=dict(present=present);texts={'0x228':6011,'0x2d0':5985};calls=[];available=[0,2,3,5];serial=0
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(panel,vtable);m.wq(vtable,m.stop+0x10);m.wq(vtable+0x78,m.stop+0x10);m.wq(vtable+0x800,vtable);m.wq(panel+0xd68,vtable+0x800);m.wq(actor+0x3b0,stats);m.wq(panel+0xe78,help_rows);m.wi(panel+0xe5c,mode);m.wi(panel+0x718,-1);m.wi(panel+0x668,-1);m.wi(panel+0xc90,1);sync()
 for id in range(8):
  m.wi(help_rows+id*8,1000+id);m.wi(help_rows+id*8+4,2000+id);u.mem_write(domain_table+id*0x50+0x44,(65535 if id%2==0 else 300+id).to_bytes(2,'little'))
 observations=[]
 for action,id in sequence:
  if action=='add':
   m.wi(panel+0x718,available.index(id));invoke(0x1409c7010,panel)
  elif action=='remove':
   m.wi(panel+0x668,id);invoke(0x1409ca100,panel)
  elif action=='list':m.wi(panel+0x718,available.index(id));invoke(0x1409ca840,panel,available.index(id))
  elif action=='chosen':m.wi(panel+0x668,id);invoke(0x1409cb440,panel,id)
  observations.append(view())
 if finish=='ok' and m.si(panel+0xe70)==2:invoke(0x1409c8730,panel)
 elif finish=='cancel':invoke(0x1409c7be0,panel)
 return dict(sequence=sequence,present=present,mode=mode,finish=finish,observations=observations,calls=calls,domains=list(u.mem_read(stats+0x293,2)))
if __name__=='__main__':
 out=m.root/'godot-client/reports/native-creation-domains-original-v1.json';assert not out.exists(),'Preserve evidence'
 sequences=[]
 for a,b in itertools.permutations([0,2,3,5],2):
  base=[['list',a],['add',a],['list',b],['add',b],['add',next(i for i in[0,2,3,5]if i not in[a,b])],['chosen',0],['chosen',1]]
  sequences.append(base)
  for removed in[0,1]:sequences.append(base+[['remove',removed],['add',[a,b][removed]]])
 rows=[run(seq,present,mode,finish)for seq,present,mode,finish in itertools.product(sequences,[False,True],[0,1],['ok','cancel'])]
 out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,ranges=[[hex(a),hex(b)]for a,b in ranges],rows=rows),indent=2)+'\n')
 print(json.dumps(dict(output=str(out),cases=len(rows),serverConnections=0,gpu=False)))
