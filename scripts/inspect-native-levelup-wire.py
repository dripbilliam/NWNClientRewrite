"""Unchanged native manual level-up writer and real scalar/string codecs.
Synthetic before/after stats, feat-membership and transport capture. Native
class/level/known-spell/domain/school getters execute; no live process writes.
This proves wire layout, not the full wizard or server validation.
"""
import importlib,json,itertools,struct
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle)
before,after,rules,classes=m.heap+0x3000,m.heap+0x5000,m.heap+0x9000,m.heap+0xa000
d=json.loads((m.root/'backups/animations/rea-levelup-client-writer-v1.json').read_text())['structuredContent']['raw_result']['value']
ranges=[]
allowed=['0x1407c4280','0x1407f0f60','0x1407f5d70','0x1407f3dc0','0x1407f5c50','0x1407f66e0','0x1407f3cc0','0x1407f3d30','0x1407f69a0']
for entry in [d['procedure'],*d['callees']]:
 if entry['address']in allowed or 'WriteCHAR'in entry['name']:
  ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in entry['body']['ranges'])
def hook(u,a,n,data):
 if a==0x1407c25c0:
  sp=u.reg_read(UC_X86_REG_RSP);size=m.si(sp+0x28)&0xffffffff;ptr=u.reg_read(UC_X86_REG_R9);packets.append(bytes([112,u.reg_read(UC_X86_REG_RDX)&255,u.reg_read(UC_X86_REG_R8)&255])+(bytes(u.mem_read(ptr,size))[3:]if size else b''));m.finish(1);return
 if a==0x1407ee620:
  ptr=u.reg_read(UC_X86_REG_RCX);feat=u.reg_read(UC_X86_REG_RDX)&65535;count=m.si(ptr+0x120);items=m.q(ptr+0x118);m.finish(int(feat in [int.from_bytes(u.mem_read(items+i*2,2),'little')for i in range(count)]));return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def spellLists(owner,offset,lists):
 for l,values in lists.items():
  ptr=m.heap+offset+l*0x80;u.mem_write(ptr,b''.join(struct.pack('<I',v)for v in values));m.wq(owner+0x148+l*0x10,ptr);m.wi(owner+0x150+l*0x10,len(values))
def run(c):
 global packets
 packets=[];t.reset({'format':1});m.wq(0x1412df8f8,rules);u.mem_write(rules+0x107,bytes([c['skillCount']]));m.wq(rules+0x110,classes);m.wi(classes+c['classId']*0x530+0x4f4,int(c['pickDomains']));m.wi(classes+c['classId']*0x530+0x4f8,int(c['pickSchool']))
 for ptr,total,skills,feats in [(before,c['level'],[0]*c['skillCount'],[1]),(after,c['level']+1,c['skills'],[1]+c['feats'])]:
  u.mem_write(ptr+0x69,b'\1\0');u.mem_write(ptr+0x295,bytes([c['classId'],total]));u.mem_write(ptr+0x76,bytes([12]*6));m.wq(ptr+0xd8,m.heap+(0x7000 if ptr==before else 0x7100));u.mem_write(m.q(ptr+0xd8),bytes(skills));listPtr=m.heap+(0x7200 if ptr==before else 0x7400);m.wq(ptr+0x118,listPtr);m.wi(ptr+0x120,len(feats));u.mem_write(listPtr,b''.join(struct.pack('<H',f)for f in feats))
 if c['ability']<6:u.mem_write(after+0x76+c['ability'],b'\x0d')
 u.mem_write(after+0x84,struct.pack('<H',c['hitDie']));u.mem_write(after+0x10e,struct.pack('<H',c['skillPoints']));u.mem_write(after+0x292,bytes([c['school'],*c['domains']]))
 # Deliberate old/new spell sets make both additions and removals observable.
 spellLists(before,0x7600,{int(l):v for l,v in c['removed'].items()});spellLists(after,0x8000,{int(l):v for l,v in c['known'].items()})
 m.wi(after+0xbf0,c['fieldE34']);m.wi(after+0xbec,c['fieldE30'])
 for field,off,text in [(0xc08,0x8800,c['fieldE48']),(0xbf8,0x8900,c['fieldE38'])]:
  raw=text.encode('cp1252');u.mem_write(m.heap+off,raw+b'\0');m.wq(after+field,m.heap+off);m.wi(after+field+8,len(raw))
 w.call(0x1407c4280,[w.message,before,after]);assert len(packets)==1
 return dict(case=c,packet=packets[0].hex())
cases=[]
for level,count,domains,school in itertools.product([1,3,20,39],[0,28,40],[False,True],[False,True]):
 skills=[0]*count
 if count:skills[1]=2;skills[-1]=1
 c=dict(level=level,skillCount=count,classId=2,ability=3 if(level+1)%4==0 else 6,hitDie=8,skills=skills,skillPoints=257,feats=[2,13,1001],known={'0':[0,7],'1':[15]},removed={'2':[16]},fieldE34=255,fieldE48='Familiar',fieldE30=2,fieldE38='Animal',domains=[1,2],school=3,pickDomains=domains,pickSchool=school);cases.append(run(c))
out=m.root/'backups/animations/native-levelup-wire-v1.json';out.write_text(json.dumps(dict(target=m.digest,scope=__doc__,cases=cases),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),success=True)))
