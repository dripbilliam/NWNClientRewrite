"""Original area base constructor, bounded scalar LoadAreaHeader1403600df..
140360525 and tile metadata loader140362bb4..140362d19 with real setters and
BYTEasBOOL conversion. Typed GFF getters are captured lower boundaries; this
does not claim malformed-GFF parsing or full renderer/resource loading.
"""
import importlib,sys,json,itertools,random,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
a=importlib.import_module('inspect-native-area-pack');t=a.t;w=a.w;m=a.m;u=m.u;u.hook_del(a.hook_handle)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
ranges=[(0x140296a40,0x140296b51),(0x1403600df,0x140360525),(0x140362bb4,0x140362d19),(0x1401a0f60,0x1401a0f80),
 (0x1402c5890,0x1402c589c),(0x1402c58a0,0x1402c58a4),(0x1402c58c0,0x1402c58c4),(0x1402c58d0,0x1402c5936),(0x1402c5940,0x1402c5944),(0x1402c58b0,0x1402c58b8),(0x1402c5950,0x1402c5958)]
getters={0x1401a1510:'dword',0x1401a1770:'int',0x1401a0ee0:'byte',0x1401a1650:'float',0x1401a1950:'word'}

def hook(u,at,n,_):
 if at in getters:
  kind=getters[at];rsp=u.reg_read(UC_X86_REG_RSP);ptr=u.reg_read(UC_X86_REG_R8);name=bytes(u.mem_read(ptr,60)).split(b'\0')[0].decode('ascii');default=m.rf(rsp+0x28) if kind=='float' else m.si(rsp+0x28)&0xffffffff
  if kind=='byte':default&=255
  if kind=='word':default&=65535
  if kind=='int' and default>=1<<31:default-=1<<32
  value=inputs.get(name,default);reads.append([kind,name,default,value]);m.wi(u.reg_read(UC_X86_REG_R9),int(name in inputs))
  if kind=='float':u.reg_write(UC_X86_REG_XMM0,int.from_bytes(struct.pack('<f',value),'little'));m.finish()
  else:m.finish(value)
  return
 if any(lo<=at<hi for lo,hi in ranges):return
 a.hook(u,at,n,_)
hook_handle=u.hook_add(UC_HOOK_CODE,hook)
byteOffsets=[0xa4,0xc4,0xe0,0xe1,0xe2,0xe3,0xe4,0x104,0x346,0x347]
uintOffsets=[8,0x98,0x9c,0xa0,0xb8,0xbc,0xc0]
intOffsets=[0xa8,0xc8,0xd8,0xdc,0x100,0x10c,0x218,0x21c,0x220,0x34c,0x368,0x380]
floatOffsets=[0xac,0xb0,0xb4,0xcc,0xd0,0xd4,0xe8,0xec,0xf0,0xf4,0xf8,0xfc,0x108]

def reset(values):
 global inputs,reads
 inputs=values;reads=[];t.reset(dict(format=1));w.call(0x140296a40,[a.area,0,0,0]);m.wi(a.area+0x34c,0);m.wi(a.area+0x368,0);m.wi(a.area+0x380,0);u.mem_write(a.area+0x347,b'\1');m.wq(a.area+0x118,a.array)
def runHeader(c):
 reset(c['values']);a.fields(a.area,c['initial']);u.reg_write(UC_X86_REG_RSP,m.stack+0x1fc00);u.reg_write(UC_X86_REG_RBP,m.stack+0x1fd00);u.reg_write(UC_X86_REG_RSI,a.area);u.reg_write(UC_X86_REG_R15,a.client);u.reg_write(UC_X86_REG_R12,0)
 u.emu_start(0x1403600df,0x140360525,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x140360525
 fields={str(o):u.mem_read(a.area+o,1)[0] for o in byteOffsets};fields.update({str(o):m.si(a.area+o)&0xffffffff for o in uintOffsets});fields.update({str(o):m.si(a.area+o) for o in intOffsets});fields.update({str(o):m.rf(a.area+o) for o in floatOffsets});fields[str(0x350)]=struct.unpack('<H',u.mem_read(a.area+0x350,2))[0]
 return dict(case=c,fields=fields,reads=reads)
def runTile(c):
 reset(c);tile=a.tiles;m.wq(a.area+0x1c8,tile);m.wq(tile,a.rules);m.wq(a.rules+0x10,0x1402c5950)
 w.call(0x1402c58a0,[tile,c.get('Tile_ID',0),0,0]);w.call(0x1402c58c0,[tile,c.get('Tile_Orientation',0),0,0]);m.wf(m.stack+0x1fe30,2.);w.call(0x1402c58d0,[tile,3,4,c.get('Tile_Height',0)])
 u.reg_write(UC_X86_REG_RSP,m.stack+0x1fc00);u.reg_write(UC_X86_REG_RBP,m.stack+0x1fd00);u.reg_write(UC_X86_REG_R15,a.area);u.reg_write(UC_X86_REG_RDI,tile);u.reg_write(UC_X86_REG_RSI,0x1402c58b0);u.reg_write(UC_X86_REG_R13,0);u.reg_write(UC_X86_REG_R14,0)
 u.emu_start(0x140362bb4,0x140362d19,count=100000);assert u.reg_read(UC_X86_REG_RIP)==0x140362d19
 fields={str(o):u.mem_read(tile+o,1)[0]for o in range(0x28,0x30)};fields.update({str(o):m.si(tile+o) for o in [0x14,0x18,0x24]});return dict(case=c,fields=fields,reads=reads)

if __name__=='__main__':
 headers=[];tiles=[];names=['Flags','ChanceRain','ChanceSnow','ChanceFog','ChanceLightning','WindPower','MoonAmbientColor','MoonDiffuseColor','MoonFogColor','MoonFogAmount','MoonShadows','SunAmbientColor','SunDiffuseColor','SunFogColor','SunFogAmount','SunShadows','SkyBox','DayNightCycle','IsNight','PlayerVsPlayer','NoRest','ShadowOpacity','LightingScheme','ModSpotCheck','ModListenCheck','LoadScreenID','TileBrdrDisabled'];rng=random.Random(8193)
 for flags,value,initial in itertools.product([0,1,2,0xffffffff],[0,1,2,255,256,-1],[{}, {'e0':['byte',77],'100':['int',0x12340002],'104':['byte',200],'10c':['int',3],'ac':['float',1.25]}]):
  values={name:value for name in names};values['Flags']=flags;values['FogClipDist']=float(value)+.25;headers.append(runHeader(dict(values=values,initial=initial)))
 for i in range(48):headers.append(runHeader(dict(values={name:rng.choice([0,1,2,256,-1])for name in names if rng.random()<.4},initial={})))
 headers.append(runHeader(dict(values={},initial={})))
 tileNames=['Tile_ID','Tile_Orientation','Tile_Height','Tile_MainLight1','Tile_MainLight2','Tile_SrcLight1','Tile_SrcLight2','Tile_ReplaceTex','Tile_AnimLoop1','Tile_AnimLoop2','Tile_AnimLoop3']
 for value in [0,1,2,255,256,-1]:tiles.append(runTile({name:value for name in tileNames}))
 for i in range(48):tiles.append(runTile({name:rng.choice([0,1,2,255,256,-1])for name in tileNames if rng.random()<.5}))
 tiles.append(runTile({}));out=m.root/'backups/animations/native-area-message-fields-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,headers=headers,tiles=tiles),indent=2));print(json.dumps(dict(output=str(out),headers=len(headers),tiles=len(tiles))))
