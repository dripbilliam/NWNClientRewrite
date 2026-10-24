"""Whole original805d20 combat sound coordinator. Real control flow/string
composition/modulo/delay arithmetic; tables, object casts, equipment/base-item
lookup, CRT draws and Play3DOneShot output are explicit captured services.
No native audio hardware, combat rolls or proprietary resource copies.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent));t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
actor,target,stats,tstats,record,vt,weapon,armor,baseitem,rules,tables=[m.heap+n*0x800 for n in range(6,17)]
tableNames=['appearance','appearancesndset','weaponsounds','defaultacsounds','doortypes','genericdoors','placeables','placeableobjsnds'];tablePointers={name:m.heap+0x9000+i*0x100 for i,name in enumerate(tableNames)};pointerNames={v:k for k,v in tablePointers.items()}
def string(ptr):
 p=m.q(ptr);return bytes(u.mem_read(p,m.si(ptr+8)&0xffffffff)).decode('cp1252')if p else''
def setString(ptr,text):
 raw=text.encode('cp1252');p=m.heap+w.cursor;w.cursor+=(len(raw)+16)&~15;assert w.cursor<0xb0000;u.mem_write(p,raw+b'\0');m.wq(ptr,p);m.wi(ptr+8,len(raw));m.wi(ptr+12,len(raw)+1)
def integer(table,row,column):
 if table=='appearance':return(True,3 if row==1 else 4)
 if table=='appearancesndset':return (case.get('missFound',False),case.get('missIndex',0))if column=='MissIndex'else(True,case.get('weapon',0))
 return(True,11)
def value(table,row,column):
 if table=='weaponsounds':return(True,f'{row}_{column}')
 if table=='appearancesndset':return(bool(case.get('custom')),case.get('custom',''))if column=='Custom'else(bool(case.get('armorType')),case.get('armorType',''))
 if table=='defaultacsounds':return(True,'plate'if row else'leather')
 if table=='placeableobjsnds':return(True,'wood')
 raise AssertionError((table,row,column))
def hook(u,a,n,data):
 global drawIndex
 x,y,z,k=[u.reg_read(r)for r in[UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1406abb60:m.finish(0 if case.get('missingTarget')else target);return
 if a==m.stop+0x18:m.finish(0 if case.get('invalidClient')else x);return
 if a in [m.stop+0x58,m.stop+0x28,m.stop+0xa0]:m.finish(x);return
 if a==0x1407630d0:m.finish(case['current']if x==actor else case['targetCurrent']);return
 if a==0x1407625d0:m.finish(case['category']);return
 if a==0x1406abc80:m.finish(armor if y&0xffffffff==33 and case.get('armorItem',True)else weapon if y&0xffffffff in [11,22]and case.get('held',True)else 0);return
 if a==0x14029ca00:m.finish(baseitem);return
 if a==0x1401a7010:
  table=pointerNames[x];column=string(z);found,v=integer(table,y&0xffffffff,column);calls.append(['int',table,y&0xffffffff,column,found,v]);m.wi(k,v);m.finish(int(found));return
 if a==0x1401a68f0:
  table=pointerNames[x];column=string(z);found,v=value(table,y&0xffffffff,column);calls.append(['string',table,y&0xffffffff,column,found,v]);setString(k,v);m.finish(int(found));return
 if a==0x14016c810:setString(x,str(struct.unpack('<i',struct.pack('<I',y&0xffffffff))[0]));m.finish(x);return
 if a==0x14016afb0:setString(x,bytes(u.mem_read(y,20)).split(b'\0')[0].decode().replace('%d',str(z&0xffffffff)));m.finish();return
 if a==0x140c7ed00:
  draw=case.get('draws',[17,31])[drawIndex%len(case.get('draws',[17,31]))];drawIndex+=1;calls.append(['random',draw]);m.finish(draw);return
 if a==0x1401d9c40:
  ref=bytes(u.mem_read(y,17)).split(b'\0')[0].decode('cp1252');height=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM3)&0xffffffff))[0];calls.append(['play',ref,list(struct.unpack('<3f',u.mem_read(z,12))),height,u.mem_read(sp+0x28,1)[0],m.si(sp+0x30)&0xffffffff,u.mem_read(sp+0x38,1)[0]]);m.finish();return
 if 0x140805d20<=a<0x140807234 or 0x14016ab00<=a<0x14016abe8 or 0x1401881e0<=a<0x14018824f:return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(c):
 global case,calls,drawIndex
 case=c;calls=[];drawIndex=0;t.reset(dict(format=1));m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tables);m.wq(rules+0x20,baseitem+0x100)
 for offset,name in [(0x100,'appearance'),(0x208,'appearancesndset'),(0x210,'weaponsounds'),(0x218,'defaultacsounds'),(0x130,'doortypes'),(0x138,'genericdoors'),(0x140,'placeables'),(0x230,'placeableobjsnds')]:m.wq(tables+offset,tablePointers[name])
 for obj,st,app in [(actor,stats,1),(target,tstats,2)]:m.wq(obj,vt);m.wq(obj+0x300,st);u.mem_write(st+0xcc,struct.pack('<H',app))
 for offset in [0x18,0x58,0x28,0xa0]:m.wq(vt+offset,m.stop+offset)
 u.mem_write(actor+0x38,struct.pack('<3f',1,2,3));m.wi(actor+0x318,11);m.wi(actor+0x31c,22);m.wi(target+0x30c,33);m.wi(weapon+0x40,0);m.wi(armor+0x1b8,case.get('armorIndex',3));u.mem_write(baseitem+0xaa,bytes([case.get('material',9)]));u.mem_write(target+0xc,bytes([case['targetType']]));m.wi(target+0x1a4,case.get('doorType',5));m.wi(target+0x1a8,6)
 if case['targetType']==9:u.mem_write(target+400,struct.pack('<H',2))
 if case.get('override'):setString(target+0x460,case['override'])
 m.wi(record+0x10,99);u.mem_write(record+8,struct.pack('<H',case.get('duration',916)));u.mem_write(record+0xc,bytes([case['result']]));m.wi(record+0x1c,case['ranged']);u.mem_write(record+0x24,bytes([case.get('weaponAttackType',1)]))
 result=w.call(0x140805d20,[actor,0 if case.get('nullRecord')else record,case['phase']]);return dict(case=case,result=result,calls=calls,draws=drawIndex)
default=dict(phase=0,ranged=0,result=1,current=200,targetCurrent=0,category=0,targetType=5)
cases=[default|dict(phase=phase,ranged=ranged,result=result,current=current,category=cat,targetType=ty,draws=draws)for phase,ranged,result,current,cat,ty,draws in itertools.product([0,1],[0,1],[0,1,2,3,4,5,9,10,11],[200,201,202,203,204,205,263,264,265,0],[0,1],[5,9,10],[[0,0],[1,32767]])]
# Keep the broad matrix tractable while retaining every result/class/clip path.
cases=cases[::7]+[default|patch for patch in [dict(nullRecord=True),dict(missingTarget=True),dict(invalidClient=True),dict(weapon=19),dict(weapon=19,result=3),dict(weapon=19,result=4,category=1),dict(custom='native_custom'),dict(override='stone'),dict(armorType='chitin'),dict(armorItem=False),dict(held=False),dict(weaponAttackType=2),dict(weaponAttackType=7),dict(phase=1,ranged=1,missFound=True,missIndex=4),dict(targetType=10,doorType=0)]]
rows=[run(c)for c in cases];out=m.root/'backups/animations/native-client-attack-sound-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
