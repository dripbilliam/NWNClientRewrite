"""Original BNCS/BNCR/BNVS/BNVR writers, captured allocation, platform,
virtual application, string copy, challenge RNG and send boundaries. All
identities/challenges are synthetic; no real credential is supplied or saved.
"""
import importlib,sys,json,struct,copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle)
owner=0x500000000;u.mem_map(owner,0x2900000)
app,vtable,net,internal,name,key,legacy=[m.heap+n*0x1000 for n in range(1,8)];fake=m.stop+0x100
ranges=[]
for label in ['network-send-bncs','network-send-bncr','network-send-bnvs','network-send-bnvr','network-platform-id']:
 d=json.loads((m.root/'backups/animations'/('rea-'+label+'.json')).read_text())['structuredContent']['normalized_result'];ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges'])

def alloc(n):
 global cursor
 assert n<0x10000;p=m.heap+cursor;cursor+=(n+31)&~15;assert cursor<0xf0000;u.mem_write(p,b'\xa5'*n);return p
def exo(p,s):
 b=s.encode('cp1252');ptr=alloc(len(b)+1);u.mem_write(ptr,b+b'\0');m.wq(p,ptr);m.wi(p+8,len(b));m.wi(p+12,len(b)+1)
def ctext(p):
 b=bytearray()
 while u.mem_read(p,1)[0]:b.append(u.mem_read(p,1)[0]);p+=1
 return b.decode('cp1252')
def hook(u,a,n,_):
 global challenge
 if a==m.stop:u.emu_stop();return
 x,y,z,w=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==fake:m.finish(1);return
 if a==fake+16:m.finish(c['applicationId']);return
 if a==fake+32:m.finish(internal);return
 if a==0x140170830:m.finish(c['port']);return
 if a==0x140113ed0:exo(y,c['platformIdentifier']);m.finish(y);return
 if a==0x140166650:
  exo(y,c['challenges'][challenge]);challenge+=1;m.finish(y);return
 if a==0x14003d8c0:
  b=bytes(u.mem_read(y,z&0xffffffff));exo(x,''if not b or b[0]==0 else b.decode('cp1252'));m.finish();return
 if a==0x140c81d54:m.finish(int(ctext(x)));return
 if a==0x140c10368:m.finish(alloc(x));return
 if a==0x140c10370:m.finish();return
 if a==0x140c417f0:u.mem_write(x,bytes(u.mem_read(y,z)));m.finish(x);return
 if a==0x1402511f0:calls.append(['send',bytes(u.mem_read(z,w)).hex()]);m.finish(7);return
 if a==0x140115890:calls.append(['warning']);m.finish();return
 if a==0x140c10410:m.finish(u.reg_read(UC_X86_REG_RAX));return
 if not any(lo<=a<hi for lo,hi in ranges):raise RuntimeError(f'Uncaptured login writer dependency {a:x}')
u.hook_add(UC_HOOK_CODE,hook)

def run(case):
 global c,cursor,calls,challenge
 c=case;cursor=0x10000;calls=[];challenge=0;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 m.wq(owner+0x50,app);m.wq(app,vtable);m.wq(vtable+0xc0,fake);m.wq(vtable+0x78,fake+16);m.wq(vtable+0x60,fake+32);m.wq(owner+0x58,net)
 for address,s in [(0x1412dfd08,str(c['build']['number'])),(0x1412dfc30,str(c['build']['revision'])),(0x1412dfca0,str(c['build']['postfix'])),(0x1412dfbb8,c['build']['commit'])]:exo(address,s)
 for off in [0x28a55f8,0x28a5608,0x28a5618]:m.wi(owner+off,c.get('passwordRequired',0))
 u.mem_write(owner+0x95788,bytes([c['connectionType']&255]));m.wi(owner+0x28a56a8,1);m.wi(owner+0x28a56c0,c['connectionType']);m.wi(owner+0x28a56d0,12)
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp)
 regs=[owner,12,c['connectionType'],c['language']]
 if c['tag']=='BNCS':
  exo(name,c['name']);exo(key,c['publicKey']);exo(legacy,c['legacyPublicKey'])
  for off,p in [(0x28,name),(0x30,key),(0x38,legacy)]:m.wq(rsp+off,p)
 elif c['tag']=='BNVS':
  for p,s in [(name,c['keyResponse']),(key,c['communityResponse']),(legacy,c['passwordResponse'])]:exo(p,s)
  regs=[owner,name,key,legacy]
 elif c['tag']=='BNCR':regs=[owner,12,c['reason'],0]
 elif c['tag']=='BNVR':regs=[owner,12,c['reason'],0]
 for r,v in zip([UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9],regs):u.reg_write(r,v)
 try:u.emu_start({'BNCS':0x1402502f0,'BNCR':0x14024ff50,'BNVS':0x140250fd0,'BNVR':0x140250e90}[c['tag']],m.stop,count=100000)
 except Exception:print(json.dumps(dict(case=c,rip=hex(u.reg_read(UC_X86_REG_RIP)),calls=calls)));raise
 assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=u.reg_read(UC_X86_REG_RAX)&0xffffffff,calls=calls)

base=dict(port=5121,applicationId=0x89abcdef,connectionType=16,language=0,name='FixturePlayer',publicKey='TESTKEY1',legacyPublicKey='',platformIdentifier='fixture-platform',build=dict(number=8193,revision=37,postfix=17,commit='26c6e573'))
cases=[]
for i,s in enumerate(['','FixturePlayer','Zo\xeb','A\0B','\0tail','n'*127,'n'*255]):cases.append(base|dict(tag='BNCS',name=s,port=[1,5121,65535][i%3],connectionType=[16,32,64][i%3],language=[0,1,255][i%3],legacyPublicKey=''if i%2 else'OLDKEY01'))
cases.extend([base|dict(tag='BNCS',applicationId=0xffffffff,build=dict(number=-1,revision=-1,postfix=-1,commit='')),base|dict(tag='BNCS',platformIdentifier='',publicKey='',legacyPublicKey='')])
for keyResponse,communityResponse,passwordResponse in [('','',''),('TESTKEY1'+'a'*32,'b'*32,''),('TESTKEY1'+'a'*32,'b'*32,'c'*32),('','A\0B',''),('x'*255,'y'*255,'z'*255)]:cases.append(base|dict(tag='BNVS',keyResponse=keyResponse,communityResponse=communityResponse,passwordResponse=passwordResponse))
for role in [16,32,64]:
 for pw in [0,1]:cases.append(base|dict(tag='BNCR',reason=0,connectionType=role,passwordRequired=pw,challenges=['password-salt','key-salt','community-salt']if pw else['key-salt','community-salt']))
for reason in [1,2,3,7,12,19,255]:cases.append(base|dict(tag='BNCR',reason=reason))
for reason in [0,1,3,19,255]:cases.append(base|dict(tag='BNVR',reason=reason))
out=m.root/'backups/animations/native-network-login-packets-observations.json';out.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=[run(c)for c in cases]),indent=2)+'\n');print(json.dumps(dict(cases=len(cases),output=str(out))))
