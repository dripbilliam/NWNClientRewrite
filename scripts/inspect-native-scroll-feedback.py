"""Original feedback formatter6cb2e0 scroll-learning branches, including222.
Reuse the existing formatter harness definitions without running its broad sweep.
Spell lookup/name, TLK, GUI audio and final publication are captured boundaries;
original executable instructions run unchanged. No game process/network is used.
"""
import hashlib,itertools,json
from pathlib import Path
source=Path(__file__).with_name('inspect-native-feedback-format.py')
prefix=source.read_text().split('u.hook_add(UC_HOOK_CODE,hook);rows=[]')[0]
assert 'def hook(u,a,n,_)' in prefix and 'profiles=' not in prefix
scope={'__file__':str(source),'__name__':'native_scroll_feedback_harness'}
exec(compile(prefix,str(source),'exec'),scope)
m,u=scope['m'],scope['u']
original_hook=scope['hook'];rules=m.heap+0x8000;spell=m.heap+0x9000;spell_name=m.heap+0xa000
def hook(u,a,n,data):
 if a==0x1402af4a0:
  scope['calls'].append(['spell',u.reg_read(scope['UC_X86_REG_RDX'])&0xffffffff]);m.finish(0 if scope['missing'] else spell);return
 if a==0x1402af780:
  scope['put'](spell_name,scope['spellName']);scope['calls'].append(['spellName',scope['spellName']]);m.finish(spell_name);return
 original_hook(u,a,n,data)
u.hook_add(scope['UC_HOOK_CODE'],hook)
rows=[]
for code,spell_id,missing,name in itertools.product([78,79,80,81,219,220,221,222,224],[0,50,321,-1],[False,True],['Learned spell','']):
 scope.update(ints=[spell_id]+[0]*9,calls=[],outputs=[],strings={},tokens={0:'old0',99:'unrelated'},cursor=0x30000,names=1,world=1,missing=missing,spellName=name)
 u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000))
 for addr,value in [(0x1412df970,scope['app']),(scope['app'],scope['owner']),(0x1412df968,scope['table']),(0x1412df960,scope['table']),(0x1412df8f0,scope['table']),(0x1412df8f8,rules),(rules+0xd0,rules),(scope['owner'],scope['app']),(scope['owner']+0x90,scope['gui'])]:m.wq(addr,value)
 m.wi(scope['app']+0x28,1);m.wi(scope['owner']+0x48,0x80000063);m.wi(scope['actor']+8,0x80000063)
 scope['put'](scope['color'],'<c\xff\xff\x01>');sp=m.stack+0x1fe08;m.wq(sp,m.stop)
 for reg,value in [(scope['UC_X86_REG_RSP'],sp),(scope['UC_X86_REG_RCX'],scope['owner']),(scope['UC_X86_REG_RDX'],code),(scope['UC_X86_REG_R8'],scope['data']),(scope['UC_X86_REG_R9'],scope['color'])]:u.reg_write(reg,value)
 u.emu_start(0x1406cb2e0,m.stop,count=100000);assert u.reg_read(scope['UC_X86_REG_RIP'])==m.stop
 rows.append(dict(type=code,spellId=spell_id,missingSpell=missing,spellName=name,calls=scope['calls'],outputs=scope['outputs'],tokens=scope['tokens']))
output=m.root/'backups/animations/native-scroll-feedback-observations-v1.json'
assert not output.exists(),'Do not overwrite retained evidence'
output.write_text(json.dumps(dict(binarySha256=m.digest,harnessSha256=hashlib.sha256(source.read_bytes()).hexdigest(),limits=__doc__,cases=rows),indent=2)+'\n')
print(json.dumps(dict(cases=len(rows),output=str(output))))
