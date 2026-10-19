"""Execute complete original SafeProjectile receiver7ac670 for synthetic ranged
messages. Real scalar readers, string/resref helpers, vector magnitude/normalize
execute. Object/rules/model/scene/projectile allocation and path/AI owners are
captured lower boundaries; traces retain metadata and resulting fields only.
No native renderer, live mutation, gameplay resolution or copied game assets.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
source,target,svt,tvt,model,mvt,projectile,pvt,base,ammoTable,appearanceTable,rules,tableOwner,config,area,input_=[m.heap+n*0x1000 for n in range(3,19)]
state=m.heap+0x30000;commands=[];case={};calls=0
receiver=json.loads((m.root/'backups/animations/rea-client-safe-projectile-callees-complete.json').read_text())['structuredContent']['normalized_result']['item']
ranges=[(0x1407ac670,0x1407ae8c5),(0x1409737c0,0x1409737e8),(0x140230920,0x1402309f6),(0x14022fba0,0x14022fbfa)]
for name in ['rea-network-ranged-vector-magnitude','rea-network-ranged-sqrt','rea-network-ranged-impact-settings','rea-network-ranged-string-find','rea-network-ranged-resref-assignment','rea-network-ranged-vector-add']:
 d=json.loads((m.root/f'backups/animations/{name}.json').read_text())['structuredContent']['raw_result']['value'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])
def s(p):return bytes(u.mem_read(p,256)).split(b'\0')[0].decode('ascii')if p else ''
def string(p):return s(m.q(p))
def vec(p):return list(struct.unpack('<3f',u.mem_read(p,12)))
def wh(p,v):u.mem_write(p,struct.pack('<H',v&65535))
def wb(p,v):u.mem_write(p,bytes([v&255]))
def text(p,value):
 global cursor
 b=value.encode();q=state+cursor;cursor+=len(b)+16;u.mem_write(q,b+b'\0');m.wq(p,q);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def hook(u,a,n,data):
 global calls
 x,y,z,v=[u.reg_read(q)for q in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]];sp=u.reg_read(UC_X86_REG_RSP)
 if a==0x1406abb60:m.finish(source if y&0xffffffff==0x80000011 and case['source']else target if y&0xffffffff==0x80000012 and case['target']else 0);return
 if a==m.stop+0x18:m.finish(x);return
 if a==m.stop+0x58:m.finish(x if x==source or case['targetType']==5 else 0);return
 if a==m.stop+0x140:m.finish(model if case['model']else 0);return
 if a==m.stop+0x138:
  commands.append(dict(kind='pose',part=s(y)));u.mem_write(z,struct.pack('<3f',7,8,9));m.finish(case['pose']);return
 if a==m.stop+0x258:m.finish(state+0x9000);return
 if a==0x14029ca00:m.finish(base if case['baseValid']else 0);return
 if a==0x1401a6a80:m.finish(-1 if case['legacy']else 0);return
 if a==0x1401a7010:
  col=string(z);value=case['ammo']if col=='AmmunitionType'else case['appearance']if col=='DamageRangedProjectile'else 0;m.wi(v,value);m.finish(1);return
 if a==0x1401a68f0:
  col=string(z);row=y&0xffffffff;value=case['sourceModelType']if x==appearanceTable and col=='modeltype'else {'Model':f'fixture_{row}','ShotSound':'shot','ImpactSound':'impact'}.get(col,'');commands.append(dict(kind='cell',column=col,row=row,value=value));text(v,value);m.finish(int(bool(value)));return
 if a==0x1401a6c70:m.wf(v,case['scale']);m.finish(1);return
 if a==0x1406ab9b0:m.finish(config);return
 if a==0x1406abea0:m.finish(area);return
 if a==0x1407630a0:m.finish(model if case['model']else 0);return
 if a==0x14008ae10:commands.append(dict(kind='track'));m.finish();return
 if a==0x140c7ed00:m.finish(case['random']);return
 if a==0x1409832a0:
  m.wq(x,pvt);m.wi(x+0x1e0,1);m.wi(x+0x1fc,1);commands.append(dict(kind='construct'));m.finish(x);return
 if a==m.stop+0xf0:commands.append(dict(kind='load',model=s(y)));m.finish(case['load']);return
 if a==m.stop+0x1b0:
  value=struct.unpack('<f',struct.pack('<I',u.reg_read(UC_X86_REG_XMM1)&0xffffffff))[0];commands.append(dict(kind='scale',value=value));m.finish();return
 if a==m.stop+0x168:commands.append(dict(kind='material',name=s(m.q(sp+0x28))));m.finish();return
 if a==0x1409873d0:commands.append(dict(kind='target',id=y&0xffffffff,part=string(z)));m.wi(x+0x198,y);m.finish();return
 if a==0x140985510:commands.append(dict(kind='stage',value=y&65535));m.finish(1);return
 if a==m.stop+0x128:commands.append(dict(kind='position',value=vec(y)));m.finish();return
 if a==m.stop+0x120:commands.append(dict(kind='orientation',value=vec(y)));m.finish();return
 if a==0x1409873c0:commands.append(dict(kind='duration',value=y&0xffffffff));m.finish();return
 if a==0x140987770:commands.append(dict(kind='path',value=y&0xffffffff));m.finish();return
 if a==m.stop+0x380:commands.append(dict(kind='scene'));m.finish();return
 if a==m.stop+0x888:commands.append(dict(kind='destroy'));m.finish();return
 if a==0x1401d9c40:commands.append(dict(kind='sound',resource=s(y),position=vec(z)));m.finish();return
 if a in [0x140c10324,0x140c10368] and x==0x240:m.finish(projectile);return
 if a==0x140c43180:
  raw=bytes(u.mem_read(x,256)).split(b'\0')[0]+b'\0';index=raw.find(bytes([y&255]));m.finish(x+index if index>=0 else 0);return
 if a in [0x140c10360]:m.finish();return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
defaults=dict(ammo=1,appearance=0,source=True,target=False,targetType=5,model=True,pose=1,baseValid=True,load=1,legacy=False,scale=1,sourceModelType='P',config=0,random=1,result=3,path=2)
cases=[defaults|dict(ammo=ammo,result=result,path=path,source=source_)for ammo,result,path,source_ in itertools.product([1,2,3,4,5,6],[1,2,3,4],[2,13],[False,True])]
cases += [defaults|dict(target=True,targetType=5,config=config,random=random,scale=scale,sourceModelType=modelType)for config,random,scale,modelType in itertools.product([0,1],[0,1],[.5,1.5],['P','C'])]
cases += [defaults|dict(ammo=ammo,appearance=appearance,legacy=True)for ammo,appearance in itertools.product([1,6,127,128,255],[0,5,8,255])]
rows=[]
for case in cases:
 t.reset(dict(format=1));commands=[];cursor=0;m.wq(0x1412df8f8,rules);m.wq(rules+0x130,tableOwner);m.wq(tableOwner+0x220,ammoTable);m.wq(tableOwner+0x100,appearanceTable);m.wi(ammoTable+0x50,1);wb(base+0xac,case['ammo']);wb(config+0x40,case['config']);m.wq(area+0xf8,area+0x400);m.wq(area+0x400+0x248,area+0x800)
 for o,vt in [(source,svt),(target,tvt)]:
  m.wq(o,vt);m.wq(vt+0x18,m.stop+0x18);m.wq(vt+0x58,m.stop+0x58);m.wq(vt+0x140,m.stop+0x140);m.wq(o+0x300,o+0x500);wh(o+0x500+0xcc,0)
 m.wq(model,mvt);m.wq(mvt+0x138,m.stop+0x138);m.wq(mvt+0x258,m.stop+0x258);m.wq(mvt+0x1b0,m.stop+0x1b0);u.mem_write(state+0x9000,b'fixture_impact\0')
 for offset,fn in [(0,0x888),(0xf0,0xf0),(0x140,0x140),(0x168,0x168),(0x128,0x128),(0x120,0x120),(0x138,0x380)]:m.wq(pvt+offset,m.stop+fn)
 m.wi(m.stack+0x1fe08+0x28,1);w.call(0x1402d54a0,[w.message,0x29,0xffffffff,1])
 for value in [0x80000011 if case['source']else 0x7f000000,0x80000012 if case['target']else 0x7f000000]:w.call(0x1404763e0,[w.message,value])
 for value in [1.25,-2,3.5,4,5,6]:w.call(0x1402db240,[w.message,0,0,32],[value,1])
 w.call(0x1402db150,[w.message,250,32])
 for value in [case['appearance'],case['path'],49,case['result']]:w.call(0x1402da960,[w.message,value,8,1])
 packet=bytes.fromhex(w.snapshot()['hex']);u.mem_write(input_,packet[3:]);m.wi(m.stack+0x1fe08+0x28,1);w.call(0x1402da7b0,[w.message,input_,len(packet)-3,0xffffffff])
 try:result=w.call(0x1407ac670,[w.message])
 except Exception:print(json.dumps(dict(case=case,rip=hex(u.reg_read(UC_X86_REG_RIP)),commands=commands)));raise
 fields=dict(result=u.mem_read(projectile+0x1e4,1)[0],rangedEffect=u.mem_read(projectile+0x170,1)[0],impactCritical=m.si(projectile+0x184),impactDuration=m.si(projectile+0x1fc),facing=u.mem_read(projectile+0x239,1)[0],impactSound=s(projectile+0x1c1))
 rows.append(dict(case=case,commands=commands,fields=fields,result=result))
out=m.root/'backups/animations/native-client-ranged-projectile-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(out))))
