"""Full original item/waypoint/store/placeable AddToArea and paired item,
waypoint/placeable RemoveFromArea owners. Area cast, collision array methods,
spatial/trap membership, mesh lookup, ComputeBoundingBox and displacement are
captured lower boundaries. This does not prove collision transforms, nearby
creature displacement or placeable action-point calculation themselves.
"""
import importlib.util,itertools,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('inspect-native-intratile-coordinator.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
actor,oldarea,newarea,app,mesh,vertices,faces=[m.heap+n*0x1000 for n in range(1,8)]
ranges=[(0x1404b1a40,0x1404b1bd4),(0x1404b6930,0x1404b69c9),(0x140464bb0,0x140464c34),(0x14046b1d0,0x14046b238),(0x140508fa0,0x140509097),(0x14050a470,0x14050a4c9),(0x1404fa540,0x1404fa5ee)]
entries={'addPlaceable':0x1404b1a40,'removePlaceable':0x1404b6930,'addItem':0x140464bb0,'removeItem':0x14046b1d0,'addWaypoint':0x140508fa0,'removeWaypoint':0x14050a470,'addStore':0x1404fa540}
def vec(ptr):return list(struct.unpack('<3f',u.mem_read(ptr,12)))
def wvec(ptr,values):u.mem_write(ptr,struct.pack('<3f',*values))
def aid(ptr):return None if ptr==0 else 88 if ptr==oldarea else 89 if ptr==newarea else f'unknown{ptr:x}'
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x140494e80:
  calls.append(['area']);id=m.si(x+0xa0)&0xffffffff;m.finish(oldarea if id==88 else newarea if id==89 else 0);return
 if a==0x14049ae60:calls.append(['setArea',aid(y)]);m.wi(x+0xa0,0x7f000000 if y==0 else aid(y));m.finish();return
 if a==0x140364cc0:calls.append(['removeObject',aid(x),y&0xffffffff]);m.finish();return
 if a==0x14035ba90:calls.append(['addObject',aid(x),y&0xffffffff,z&0xffffffff]);m.finish(1);return
 if a==0x140298b70:calls.append(['removeStatic',aid(x),y]);m.finish();return
 if a==0x1400b5450:calls.append(['removeTrap',aid(x-0x158),y&0xffffffff]);m.finish();return
 if a==0x14055b880:m.finish(app);return
 if a==0x1402cd9b0:calls.append(['mesh',y]);m.finish(0 if c['mesh']=='null' else mesh);return
 if a==0x140296e60:calls.append(['addStatic',aid(x),y&0xffffffff,vec(z),vec(w),m.si(rsp+0x28),m.si(rsp+0x38)]);m.finish(c.get('newSlot',4));return
 if a==0x1404b1bf0:calls.append(['bbox']);m.finish();return
 if a==0x1402973d0:calls.append(['bounds',aid(x),y]);wvec(z,[-1,-2,-3]);wvec(w,[4,5,6]);m.finish();return
 if a==0x14035c260:calls.append(['displace',aid(x),vec(y),vec(z),vec(w),m.si(rsp+0x28)&0xffffffff,m.si(rsp+0x30)]);m.finish();return
 if a==0x140c10370:m.finish();return
 if not any(lo<=a<hi for lo,hi in ranges):raise AssertionError(f'Uncaptured world area dependency {a:x}: {operation}, {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case,mode):
 global c,calls,operation
 c=case;calls=[];operation=mode;u.mem_write(m.heap,bytes(0x100000));m.wq(0x1412df970,app);m.wq(app+8,app)
 base=actor+0x48 if 'Item' in mode else actor;m.wi(base+8,99);m.wi(base+0xa0,88 if c['oldArea'] else 0x7f000000);m.wi(actor+0x50c,c.get('slot',-1));u.mem_write(actor+0x32c,struct.pack('<H',c.get('appearance',50)&65535));wvec(base+0xa4,[1,2,3]);wvec(base+0xb0,[.6,.8,0]);m.wq(mesh+0x28,vertices);m.wq(mesh+0x30,faces);m.wi(mesh+0x3c,3 if c['mesh']=='full' else 0);m.wi(mesh+0x38,1 if c['mesh']=='full' else 0)
 rsp=m.stack+0x1fe08;u.mem_write(rsp-0x400,bytes(0x500));m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor)
 u.reg_write(UC_X86_REG_RDX,newarea if c['destination']=='new' else oldarea if c['destination']=='same' else 0)
 for reg,value in [(UC_X86_REG_XMM2,6.125),(UC_X86_REG_XMM3,-7.25)]:u.reg_write(reg,int.from_bytes(struct.pack('<f',value),'little'))
 m.wf(rsp+0x28,8.5);m.wi(rsp+0x30,c['flag'])
 try:u.emu_start(entries[mode],m.stop,count=15000)
 except Exception:print(json.dumps(dict(mode=mode,case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(mode=mode,case=c,calls=calls,areaId=m.si(base+0xa0)&0xffffffff,position=vec(base+0xa4),slot=m.si(actor+0x50c))
rows=[]
for mode,oldArea,destination,flag in itertools.product(entries,[False,True],['null','same','new'],[0,1,2]):
 for slot,meshKind in itertools.product([-1,0,3],['null','empty','full']) if 'Placeable' in mode else [(-1,'null')]:
  rows.append(run(dict(oldArea=oldArea,destination=destination,flag=flag,slot=slot,mesh=meshKind),mode))
for appearance,newSlot in itertools.product([0,65535,65536,65586],[-1,0,7]):rows.append(run(dict(oldArea=True,destination='new',flag=1,slot=2,mesh='full',appearance=appearance,newSlot=newSlot),'addPlaceable'))
out=m.root/'backups/animations/native-world-object-area-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
