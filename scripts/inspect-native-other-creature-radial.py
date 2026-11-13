"""Unchanged original993790 normal other-creature menu decisions.

Authored controlled/target/player lookup, skill-admission result, portrait/UI
services and target visibility fixtures. Party owners are absent and DM isfalse.
This does not implement the replacement, prove received fields or run a server.
"""
from pathlib import Path
import hashlib, itertools, json
root=Path(__file__).resolve().parents[1]
fixture=Path(__file__).with_name('inspect-native-creature-radial.py')
source=fixture.read_text();proof=json.loads((root/'godot-client/reports/native-creature-radial-original-v1.json').read_text())
assert hashlib.sha256(fixture.read_bytes()).hexdigest()==proof['scriptSha256']
assert source.count('\nrows=[]\n')==1
prefix=source.split('\nrows=[]\n')[0]
assert prefix.count('u.hook_add(UC_HOOK_CODE, hook)')==1
prefix=prefix.replace('u.hook_add(UC_HOOK_CODE, hook)','hook_handle=u.hook_add(UC_HOOK_CODE, hook)')
ns={'__file__':str(fixture),'__name__':'_pinned_authored_radial_fixture'}
exec(compile(prefix,str(fixture),'exec'),ns)
u,heap=ns['u'],ns['heap'];u.hook_del(ns['hook_handle'])
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
active=None
target=heap+0x10000
def hook(_u,address,size,data):
    if address==0x140993790:
        ns['wi'](ns['menu']+0x7f8,100);u.mem_write(ns['menu']+0x814,bytes([active['reaction']]))
        ns['wi'](target+8,100);ns['wi'](target+0x37c,active['targetFlags']);ns['wi'](target+0x22c,active['loot'])
        u.mem_write(target+0x388,bytes([active['reaction']]));ns['wq'](target+0x3b0,heap+0x11000)
        u.mem_write(heap+0x11050,active['racialType'].to_bytes(2,'little'))
        if active['castVisible'] is not None:
            ns['wq'](ns['actor']+0x3f0,heap+0x12000);ns['wi'](ns['actor']+0x3f8,1);ns['wq'](heap+0x12000,heap+0x12100)
            ns['wi'](heap+0x12100,100);u.mem_write(heap+0x12104,bytes([active['castVisible']]))
    if address==0x1406ab9e0:
        ident=u.reg_read(UC_X86_REG_RDX)&0xffffffff
        assert ident==100;ns['finish'](target)
    elif address==0x1406ac100:
        assert u.reg_read(UC_X86_REG_RDX)&0xffffffff==100
        ns['finish'](heap+0x13000 if active['isPlayer'] else 0)
    elif address==0x1400931f0:ns['finish'](heap+0x14000)
    elif address in (0x14084c550,0x1401f9ee0):ns['finish']()
    elif address==0x1407f0bf0:
        skill=u.reg_read(UC_X86_REG_RDX)&65535
        assert skill in (0,13)
        ns['finish'](int(bool(active['skills']&(1<<skill))))
    else:ns['hook'](_u,address,size,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for flags,mode,related,target_flags,player,reaction,skills,race,loot,visible in itertools.product([0,128],[0,2],[ns['INVALID'],100],[0,1],[False,True],[0,1,2],[0,8193],[0,8],[0,1],[None,0,1]):
    active=dict(controlledFlags=flags,mode=mode,related=related,targetFlags=target_flags,isPlayer=player,reaction=reaction,skills=skills,racialType=race,loot=loot,castVisible=visible)
    value=ns['execute'](0x140993790,0x140993f70,flags=flags,mode=mode,related=related)
    byslot={entry['slot']:entry for entry in value['entries']}
    assert 0 in byslot and byslot[0]['icon']=='IR_EXAMINE' and 1 in byslot
    if player and target_flags==0:assert set(byslot)=={0,1}
    else:
        assert 3 in byslot and 6 in byslot
        assert (2 in byslot)==bool(mode==2 and related==100 or flags&128)
        if mode==2 and related==100:assert byslot[2]['icon']=='IR_DISENGAGE'
        if not player or reaction==2:
            assert (5 in byslot)==bool(skills&8192) and (4 in byslot)==bool(skills&1)
            if loot and target_flags==0:assert byslot[7]['icon']=='IR_USE'
            elif reaction!=2:assert byslot[7]['icon']=='IR_DIALOG'
            else:assert 7 not in byslot
        else:assert byslot[7]['icon']=='IR_BARTER'
    rows.append(dict(input=active,**value))
output=ns['output']
report=dict(success=True,binarySha256=ns['digest'],scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),fixtureSha256=proof['scriptSha256'],cases=len(rows),rows=rows,scope=__doc__,limits=['The skill service result is authored; source7f0bf0 additionally checks active skill-count and stats110 override, whose full normal/DM owner still needs integration proof.','No replacement policy, actual native input, transport outcome, party-role or DM-role acceptance is implied.'])
output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(success=True,cases=len(rows),report=str(output))))
