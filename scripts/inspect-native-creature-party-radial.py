"""Extend pinned normal-self oracle with original party role4 precedence.

Loads only the pinned authored base fixture definitions (before its execution
loop), not a prior observation as output. Target98ec00 executes unchanged. TLK
fetch and CExoString formatting are bounded captured services with authored text.
DM and possession are absent; no received polymorph mapping is claimed.
"""
from pathlib import Path
import hashlib, itertools, json
root=Path(__file__).resolve().parents[1]
fixture=Path(__file__).with_name('inspect-native-creature-radial.py')
source=fixture.read_text()
proof=json.loads((root/'godot-client/reports/native-creature-radial-original-v1.json').read_text())
assert hashlib.sha256(fixture.read_bytes()).hexdigest()==proof['scriptSha256']
assert source.count('\nrows=[]\n')==1
prefix=source.split('\nrows=[]\n')[0]
assert prefix.count('u.hook_add(UC_HOOK_CODE, hook)')==1
prefix=prefix.replace('u.hook_add(UC_HOOK_CODE, hook)','hook_handle=u.hook_add(UC_HOOK_CODE, hook)')
ns={'__file__':str(fixture),'__name__':'_pinned_authored_radial_fixture'}
exec(compile(prefix,str(fixture),'exec'),ns)
u,heap=ns['u'],ns['heap']
u.hook_del(ns['hook_handle'])
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import *
active_case=None
captured_fetch=[]
def hook(_u,address,size,data):
    if address==0x14098ec00:
        party=heap+0xb000
        if active_case['party'] is not None:
            ns['wq'](ns['actor']+0x3d0,party)
            for at,value in enumerate(active_case['party']):ns['wi'](party+at*4,value)
            ns['wi'](party+0x14,100)
            ns['wq'](party+0x18,heap+0xc000)
            u.mem_write(heap+0xc000,b'SourceInviter\0')
        ns['wq'](0x1412df968,heap+0xd000)
    if address==0x140c10370:ns['finish']()
    elif address==0x140198c60:
        ref=u.reg_read(UC_X86_REG_RDX)&0xffffffff
        assert ref==6386
        captured_fetch.append(ref)
        ns['wq'](u.reg_read(UC_X86_REG_R8),heap+0xc100)
        u.mem_write(heap+0xc100,b'Accept\0');ns['finish'](1)
    elif address==0x14016afb0:
        assert ns['text'](u.reg_read(UC_X86_REG_RDX))=='%s %s'
        label=(ns['text'](u.reg_read(UC_X86_REG_R8))+' '+ns['text'](u.reg_read(UC_X86_REG_R9))).encode('ascii')+b'\0'
        u.mem_write(heap+0xc200,label);ns['wq'](u.reg_read(UC_X86_REG_RCX),heap+0xc200);ns['finish']()
    elif address==0x1401fa250:
        sp=u.reg_read(UC_X86_REG_RSP)
        ns['entries'].append(dict(slot=u.reg_read(UC_X86_REG_RDX),icon=ns['text'](u.reg_read(UC_X86_REG_R8)),label=ns['text'](u.reg_read(UC_X86_REG_R9)),kind='entry',callback=hex(ns['q'](sp+0x30)),argument=ns['q'](sp+0x38)))
        ns['finish']()
    else:ns['hook'](_u,address,size,data)
u.hook_add(UC_HOOK_CODE,hook)
rows=[]
for party,poly,locked in itertools.product([None]+list(itertools.product([0,1],repeat=5)),[0,1],[0,1]):
    active_case=dict(party=None if party is None else list(party),polymorph=poly,locked=locked)
    value=ns['execute'](0x14098ec00,0x14098f0a2,polymorph=poly,locked=locked)
    # SetEntryx replaces an existing physical sector. Keep the final observed
    # publication, including original polymorph's later override of party4.
    slot4=next((r for r in reversed(value['entries']) if r['slot']==4),None)
    expected=None
    if party is not None:
        player,field6,singleton,leader,pending=party
        if player and field6:
            if leader and pending:expected='IR_ACCEPT'
            elif not leader or not singleton:expected='IR_LEAVE'
    if poly and not locked:expected='IR_SKILLSELF'
    assert (slot4['icon'] if slot4 else None)==expected,(active_case,slot4,expected)
    rows.append(dict(input=active_case,role4=slot4))
output=ns['output']
report=dict(success=True,binarySha256=ns['digest'],scriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),fixtureSha256=proof['scriptSha256'],cases=len(rows),rows=rows,scope=__doc__,capturedTlkRefs=sorted(set(captured_fetch)),limits=['Party fields use the verified781e80 mask4000 offset mapping; raw source is stored in a separate REA excerpt.','No possession/DM role and no native+408/+40c replicated-field publication is accepted.','Authored Accept/SourceInviter strings test source formatting/callback selection, not an installedTLK or pixels.'])
output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(success=True,cases=len(rows),report=str(output))))
