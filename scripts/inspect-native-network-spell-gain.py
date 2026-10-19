"""Complete original client spell-gain7f6b20 with real byte/class/race fields.
Class lookup/level/school helpers, ability-gain/modifier queries and final class
spell table query are captured lower boundaries. Native score/bonus arithmetic,
ruleset hash and prestige/rival scans execute. This is client wheel eligibility,
not server spell slots or gameplay resolution.
"""
import sys,importlib,json,struct,itertools
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
t=importlib.import_module('inspect-native-message-text');w=t.w;m=w.m;u=m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
u.hook_del(t.hook_handle);stats,rules,defs,races=[m.heap+n for n in [0x20000,0x30000,0x40000,0x60000]]
d=json.loads((m.root/'backups/animations/rea-network-spell-wheel-gain-owner.json').read_text())['structuredContent']['raw_result']['value'];ranges=[(int(r['start'],16),int(r['end'],16)+1)for r in d['procedure']['body']['ranges']]
for f in d['callees']:
 if int(f['address'],16)in[0x1402ae870,0x1402a4a30]:ranges.extend((int(r['start'],16),int(r['end'],16)+1)for r in f['body']['ranges'])
def six(value):return value if isinstance(value,list)else[value]*6
def hook(u,a,n,data):
 x,y,z,k=[u.reg_read(r)for r in [UC_X86_REG_RCX,UC_X86_REG_RDX,UC_X86_REG_R8,UC_X86_REG_R9]]
 if a==0x1407f0f60:m.finish(c['classes'][y&255]['id']);return
 if a==0x1407f1080:m.finish(c['classes'][y&255]['level']);return
 if a==0x1407f69a0:m.finish(c['classes'][y&255].get('school',0));return
 if a==0x1407f1110:m.finish(six(c['gain'])[y]&255);return
 if a==0x1407ec3a0:m.finish(six(c['modifier'])[c['ability']]&255);return
 if a==0x1402a4130:m.finish(c['minimum']);return
 if a==0x140299e40:queries.append(dict(id=(x-defs)//0x530,level=y&255,spellLevel=z&255));m.finish(c['returnGain']);return
 if any(lo<=a<hi for lo,hi in ranges):return
 t.hook(u,a,n,data)
u.hook_add(UC_HOOK_CODE,hook)
def run(case):
 global c,queries
 c=case;queries=[];t.reset(dict(format=1));m.wq(0x1412df8f8,rules);m.wq(rules+0x110,defs);m.wq(rules+0x118,races);u.mem_write(stats+0x69,bytes([len(c['classes'])]));u.mem_write(stats+0x50,struct.pack('<H',2))
 for i,v in enumerate(six(c['base'])):u.mem_write(stats+0x76+i,bytes([v&255]))
 for i,v in enumerate(six(c['bonus'])):u.mem_write(stats+0x7d+i,bytes([v&255]))
 for i,v in enumerate(six(c['race'])):u.mem_write(races+2*0x68+[0x18,0x19,0x1d,0x1a,0x1c,0x1b][i],bytes([v&255]))
 u.mem_write(stats+0x7c,bytes([c['dex']&255]));u.mem_write(stats+0x70,bytes([18]*6))
 for index,cls in enumerate(c['classes']):
  u.mem_write(stats+index*0x150+0x295,bytes([cls['id']]));u.mem_write(stats+index*0x150+0x296,bytes([cls['level']]));info=c['defs'][str(cls['id'])];p=defs+cls['id']*0x530;u.mem_write(p+0x4e8,bytes([c['ability']]));m.wi(p+0x4d8,info['spellCaster']);m.wi(p+0x500,info['arcane']);m.wi(p+0x4f8,info.get('pickSchool',0));u.mem_write(p+0x525,bytes([info['arcaneModifier']&255,info['divineModifier']&255]))
 result=w.call(0x1407f6b20,[stats,c['index'],c['level']])&255;return dict(case=c,result=result,queries=list(queries))
caster=dict(spellCaster=1,arcane=1,arcaneModifier=0,divineModifier=0,pickSchool=1)
base=dict(index=0,ability=3,level=1,base=18,bonus=0,race=0,gain=0,modifier=5,dex=0,minimum=11,returnGain=1,classes=[dict(id=10,level=10,school=1)],defs={'10':caster})
cases=[]
for i,(ability,score,bonus,level,modifier,gain)in enumerate(itertools.product(range(6),[8,18,120],[-20,0,20],[0,1,9],[-2,5,12],[0,1,255])):cases.append(base|dict(ability=ability,base=score,bonus=bonus,level=level,modifier=modifier,returnGain=gain,race=i%3-1,gain=i%5-2,dex=i%5-2))
for index,rivalLevel,prestigeLevel,divisor,arcane,school in itertools.product([0,2],[5,10,15],[1,5,255],[0,1,2,255],[0,1],[0,1]):
 cases.append(base|dict(index=index,classes=[dict(id=10,level=10,school=school),dict(id=29,level=prestigeLevel,school=0),dict(id=11,level=rivalLevel,school=school)],defs={'10':caster,'29':dict(spellCaster=0,arcane=0,arcaneModifier=divisor,divineModifier=divisor),'11':caster|dict(arcane=arcane)}))
for ability in range(6):cases.append(base|dict(ability=ability,base=[9,11,13,15,17,19],bonus=[1,2,3,4,5,6],race=[-1,2,3,-2,5,6],gain=[-4,3,1,2,0,-3],modifier=[-2,-1,0,1,2,3]))
for change in [dict(base=127,race=127,gain=127,bonus=127,modifier=127),dict(base=-128,race=-128,gain=-128,bonus=-128,modifier=-128),dict(minimum=8),dict(minimum=128)]:cases.append(base|change)
rows=[run(c)for c in cases];output=m.root/'backups/animations/native-network-spell-gain-observations.json';output.write_text(json.dumps(dict(target=m.digest,limits=__doc__,cases=rows),indent=2)+'\n');print(json.dumps(dict(cases=len(rows),output=str(output))))
