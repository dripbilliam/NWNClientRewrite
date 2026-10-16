"""Read-only complete recursive InterTileDFSExploreArea14036ce60.
Original coordinate rotations execute too. Graph manager, surface-region
queries, canonical door lookup/open state and active 2DA reads are captured
lower boundaries. Synthetic tiles/doors exercise the visibility coordinator;
they are not an installed-map or complete surface-region parity claim.
"""
from pathlib import Path
import importlib,sys,json,itertools
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator')
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u=m.u;u.hook_del(m.hook_handle)
area,tiles,visited,app,rules,table,doorids=[m.heap+i*0x1000 for i in range(7)]
graphs=json.loads((m.root/'backups/animations/native-tile-path-node-observations.json').read_text())['graphs']
def signed(v):return m.struct.unpack('<i',m.struct.pack('<I',v&0xffffffff))[0]
def tileid(ptr):return (ptr-tiles)//0x68
def hook(u,a,n,_):
 global cursor
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];rsp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1404fdd20:m.finish(m.q(x+0x30))
 elif a==0x1402bebe0:m.finish(c['path'])
 elif a==0x1402bebf0:m.finish(c['pathOrientation'])
 elif a==0x1402ca830:
  key=(y&255,z&255);calls.append(['graph',*key]);ptr=0
  if key[0]:
   if key not in cache:
    graph=graphs[str(key[0])][key[1]];ptr=m.heap+cursor;cursor+=0x400;cache[key]=ptr
    m.wi(ptr,len(graph['centres']));m.wi(ptr+4,len(graph['entrances']));m.wq(ptr+0x10,ptr+0x40);m.wq(ptr+0x18,ptr+0x140)
    for i,point in enumerate(graph['entrances']):
     for axis,v in enumerate(point):m.wf(ptr+0x40+i*8+axis*4,v)
    for i,region in enumerate(graph['regions']):m.wi(ptr+0x140+i*4,region)
   ptr=cache[key]
  m.finish(ptr)
 elif a==0x1402becd0:
  calls.append(['entrance',tileid(surface_tiles[x]),m.xmm(UC_X86_REG_XMM1),m.xmm(UC_X86_REG_XMM2),w&255,m.si(rsp+0x28)&255]);m.finish(c['entrance'])
 elif a==0x1402bcd10:
  calls.append(['closest',tileid(y),m.xmm(UC_X86_REG_XMM2),m.xmm(UC_X86_REG_XMM3),m.si(rsp+0x28)&255,m.si(rsp+0x30)&255]);m.finish(c['region'])
 elif a==0x14055b430:
  id=y&0xffffffff;calls.append(['door',id]);m.finish(doors.get(id,0))
 elif a==0x1404207f0:
  id=m.si(x+8);calls.append(['open',id]);m.finish(c['door']['open'])
 elif a==0x1401a7010:
  calls.append(['block',77]);m.wi(w,c['door']['block']);m.finish(c['door'].get('found',1))
 elif a in [0x140c10368,0x140c10324]:ptr=m.heap+cursor;cursor+=max(16,x);m.finish(ptr)
 elif a==0x140c10370:m.finish()
 elif not any(lo<=a<hi for lo,hi in [(0x14036ce60,0x14036d557),(0x1402c5760,0x1402c57ca),(0x1402c5630,0x1402c569a)]):raise RuntimeError(f'Unmapped exploration dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,calls,cache,cursor,doors,surface_tiles
 c=case;calls=[];cache={};cursor=0x30000;doors={};surface_tiles={};u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(0x1412df970,app);m.wq(app+8,app);m.wq(app+16,app);m.wq(0x1412df8f8,rules);m.wq(rules+0x130,table);m.wq(table+0x138,table)
 m.wi(area+12,c['width']);m.wi(area+16,c['height']);m.wq(area+0x1c8,tiles)
 for i in range(c['width']*c['height']):
  tile=tiles+i*0x68;info=m.heap+0x10000+i*0x200;surface=info+0x80;surface_tiles[surface]=tile;m.wq(tile+0x30,info);m.wq(info+8,surface);m.wi(tile+0x24,c['rotation']);u.mem_write(info+0x32,bytes([c['tileDoors']]))
  for offset,key in [(0x40,'visibility'),(0x44,'visibilityOrientation'),(0x48,'doorVisibility'),(0x4c,'doorVisibilityOrientation')]:u.mem_write(surface+offset,bytes([c[key]]))
  m.wq(tile+0x48,doorids);m.wi(tile+0x50,len(c['ids']))
 for i,id in enumerate(c['ids']):m.wi(doorids+i*4,id)
 if c.get('door'):
  ptr=m.heap+0x8000;doors[77]=ptr;m.wi(ptr+8,77);m.wi(ptr+0x3f8,c['door']['appearance']);m.wi(ptr+0x3fc,5)
  for i,v in enumerate(c['door']['position']):m.wf(ptr+0xa4+i*4,v)
  for i,v in enumerate(c['door']['orientation']):m.wf(ptr+0xb0+i*4,v)
 u.mem_write(visited,bytes(c.get('visited',[0]*(c['width']*c['height']))));rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 for reg,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],[area,visited,c['depth'],c['x']]):u.reg_write(reg,v&0xffffffffffffffff)
 m.wi(rsp+0x28,c['y']);m.wf(rsp+0x30,c['local'][0]);m.wf(rsp+0x38,c['local'][1])
 try:u.emu_start(0x14036ce60,m.stop,count=500000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,calls=calls,visited=list(u.mem_read(visited,c['width']*c['height'])))
if __name__=='__main__':
 default=dict(width=4,height=3,depth=3,x=1,y=1,local=[5,5],path=65,pathOrientation=0,visibility=0,visibilityOrientation=0,doorVisibility=0,doorVisibilityOrientation=0,tileDoors=0,ids=[],rotation=0,entrance=-1,region=0);rows=[]
 for depth,xy,rotation,kind,entrance in itertools.product([0,1,2,3,9,256],[[-1,0],[0,0],[1,1],[4,0]],[0,1,2,3],[0,65,78,85],[-1,0,1]):rows.append(run(default|dict(depth=depth,x=xy[0],y=xy[1],rotation=rotation,path=kind,entrance=entrance)))
 for appearance,open_,block,axis,position,kind in itertools.product([0,1],[0,1],[0,1,2,-1],[[1,0,0],[0,1,0],[.707,0,0],[.7069999,0,0]],[[20,15,0],[15,20,0],[20.5,15,0]],[0,78]):
  rows.append(run(default|dict(tileDoors=1,ids=[999,77],doorVisibility=kind,doorVisibilityOrientation=3,door=dict(appearance=appearance,open=open_,block=block,position=position,orientation=axis))))
 out=m.root/'backups/animations/native-automap-exploration-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2));print(json.dumps(dict(output=str(out),rows=len(rows))))
