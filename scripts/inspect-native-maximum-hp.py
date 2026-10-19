"""Original complete GetMaxHitPoints140391850 and FNV hashing. Actual installed
numeric inputs plus synthetic PC/NPC/possession/feat/rules cases. HasFeat,
GetLevel/GetLevelStats/GetNumLevelsOfClass and ruleset queries are captured lower
boundaries; no complete original BIC loader or encounter HP parity claim.
"""
import importlib,itertools,json,struct
from native_rule_fixture import ruleset_value
m=importlib.import_module('inspect-native-intratile-coordinator');u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(m.hook_handle);actor,stats,levels=[m.heap+n*0x2000 for n in range(3)]
def hook(u,a,n,_):
 if a==m.stop:u.emu_stop();return
 x,y,z=[u.reg_read(r) for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8]]
 if a==0x14040b900:m.finish(int((y&65535) in c.get('feats',[])))
 elif a==0x1403d54d0:m.finish(c.get('possessed',0))
 elif a==0x1404035c0:m.finish(c['level']&255)
 elif a==0x1404036b0:m.finish(levels+(y&255)*0x200 if (y&255)<len(c['dice']) else 0)
 elif a==0x140405570:assert(y&255)==34;m.finish(c['pale'])
 elif a==0x1402a4130:m.finish(ruleset_value(c.get('rules',{}),y,(z+2**31)%2**32-2**31))
 elif not any(lo<=a<hi for lo,hi in [(0x140391850,0x140391e70),(0x1402ae870,0x1402ae899)]):raise AssertionError(f'Unexpected max HP dependency {a:x} {c}')
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c
 c=case;u.mem_write(m.heap,bytes(0x100000));u.mem_write(m.stack,bytes(0x20000));m.wq(actor+0xad0,stats);m.wi(stats+0xb0,c['pc']);u.mem_write(stats+0xd3d,bytes([c['constitution']&255]));u.mem_write(actor+0xe4,struct.pack('<H',c['stored']&65535))
 for i,die in enumerate(c['dice']):u.mem_write(levels+i*0x200+0x15b,bytes([die&255]))
 rsp=m.stack+0x1fe08;m.wq(rsp,m.stop);u.reg_write(UC_X86_REG_RSP,rsp);u.reg_write(UC_X86_REG_RCX,actor);u.reg_write(UC_X86_REG_RDX,c.get('include',1));u.emu_start(0x140391850,m.stop,count=100000);assert u.reg_read(UC_X86_REG_RIP)==m.stop
 return dict(case=c,result=((u.reg_read(UC_X86_REG_RAX)&65535)^32768)-32768)
inputs=json.loads((m.root/'backups/animations/installed-hp-native-inputs-v1.json').read_text());rows=[]
for source in inputs['rows']:
 for include in [0,1]:rows.append(run(dict(source,include=include)))
for pc,possessed,pale,con,include,feats in itertools.product([0,1,2],[0,1],[0,4,5,10,11,15],[0,2,127,128,255],[0,1],[[],[40],[891],[40,891,755,763]]):
 rows.append(run(dict(pc=pc,possessed=possessed,pale=pale,level=20,constitution=con,stored=50,dice=[1,4,6,8]*5,include=include,feats=feats)))
for pc,rule in itertools.product([0,1],[-32769,-1,0,32768]):rows.append(run(dict(pc=pc,possessed=0,pale=15,level=20,constitution=255,stored=32767,dice=[1]*20,include=1,feats=[40,891,754],rules={'FEAT_TOUGHNESS_HP_BONUS':rule,'FEAT_DEATHLESS_VIGOR_HP_BONUS':rule,'FEAT_EPIC_DEATHLESS_VIGOR_HP_BONUS':rule,'FEAT_EPIC_TOUGHNESS_HP_BONUS_1':rule})))
out=m.root/'backups/animations/native-maximum-hp-observations.json';out.write_text(json.dumps(dict(binarySha256=m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),installed=[dict(name=r['case']['name'],saved=r['case']['saved'],computed=r['case']['computed'],native=r['result']) for r in rows if 'name'in r['case'] and r['case']['include']==1 and r['case']['saved']!=r['result']])))
