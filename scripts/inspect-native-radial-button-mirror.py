"""Execute unchanged original left/right radial button handlers.
Mouse-move hit calculation, parent activation, final menu action and GUI
capture/modal cleanup are captured lower boundaries. This isolates the input
preference/state transitions, not complete GUI routing or original rendering.
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
radial,parent,gui,vt=[m.heap+n*0x1000 for n in range(4)];move=m.stop+0x100
addresses={'ldown':0x1401f9270,'lup':0x1401f9300,'rdown':0x1401f9ad0,'rup':0x1401f9b10}
ranges=[(0x1401f9270,0x1401f92f1),(0x1401f9300,0x1401f931b),(0x1401f9ad0,0x1401f9b06),(0x1401f9b10,0x1401f9b50)]
def byte(ptr,value):u.mem_write(ptr,bytes([value]))
def state(ptr):return dict(click=bool(u.mem_read(ptr+0x7d8,1)[0]),started=bool(u.mem_read(ptr+0x7e4,1)[0]),mirror=bool(u.mem_read(ptr+0x7f0,1)[0]),action=m.si(ptr+0x7c8),position=[m.si(ptr+0x7dc),m.si(ptr+0x7e0)])
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==move:
  calls.append(['move',y&0xffffffff,z&0xffffffff]);m.wi(x+0x7c8,c['move_action']);m.wi(x+0x7cc,1);m.finish()
 elif a==0x1401f7f00:calls.append(['activate_parent']);m.finish()
 elif a==0x1401f9350:calls.append(['menu_action',m.si(x+0x7c8),m.si(x+0x7cc)]);m.finish()
 elif a==0x1401f6440:calls.append(['release_mouse']);m.finish()
 elif a==0x1401f7080:calls.append(['unset_modal']);m.finish()
 elif not any(low<=a<high for low,high in ranges):raise RuntimeError(f'Unexpected radial button dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
original_default=m.si(0x14128f4a4);rows=[]
for mirror,click,started,action,move_action,has_parent,events in itertools.product([0,1],[0,1],[0,1],[0,2,3,5],[0,2,3],[0,1],[['ldown'],['lup'],['rdown'],['rup'],['ldown','lup']]):
 c=dict(mirror=mirror,click=click,started=started,action=action,move_action=move_action,parent=has_parent,events=events)
 u.mem_write(m.heap,bytes(0x10000));u.mem_write(m.stack,bytes(0x20000));m.wq(radial,vt);m.wq(vt+0xb0,addresses['rdown']);m.wq(vt+0xb8,addresses['rup']);m.wq(vt+0x88,move)
 m.wq(0x1412df8b0,gui);m.wi(gui+0xd4,123);m.wi(gui+0xd8,456);m.wq(radial+0x2d8,parent if has_parent else 0)
 m.wi(radial+0x7dc,300);m.wi(radial+0x7e0,400);m.wi(radial+0x7e8,100);m.wi(radial+0x7ec,200)
 byte(radial+0x7f0,mirror);byte(radial+0x7d8,click);byte(radial+0x7e4,started);m.wi(radial+0x7c8,action);m.wi(radial+0x7cc,1);byte(parent+0x7f0,1)
 calls=[]
 for event in events:
  rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,radial)
  u.emu_start(addresses[event],m.stop,count=10000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 rows.append(dict(input=c,calls=calls,state=state(radial),parent_state=state(parent)))
out=m.root/'backups/animations/native-radial-button-mirror-v1.json'
assert not out.exists(),'Preserve original observations'
out.write_text(json.dumps(dict(binarySha256=m.digest,scope=__doc__,default=original_default,rows=rows),indent=2))
print(json.dumps(dict(output=str(out),rows=len(rows),default=original_default)))
