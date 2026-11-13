"""Execute unchanged original MdlNodeLightCreateInstance for Gob+f0 proof.

Heap allocation and Gob+470 light-list append are explicit lower providers.
All constructor control flow/field copies/owner flag writes execute unchanged.
This is not scene admission, renderer, live game or performance evidence.
Do not execute while parent holds an FPS reservation.
"""
from pathlib import Path
import sys, importlib, hashlib, json, struct
root = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(root / 'scripts'))
m = importlib.import_module('inspect-native-intratile-coordinator')
u = m.u
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_RAX, UC_X86_REG_RSP, UC_X86_REG_RIP
assert m.digest == '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'
u.hook_del(m.hook_handle)
light, gob, part = [m.heap + n for n in (0, 0x2000, 0x4000)]
start, end = 0x140092b10, 0x140092c74
calls, visits = [], set()
def hook(uc, pc, size, unused):
    if pc == m.stop:
        uc.emu_stop(); return
    x, y = [uc.reg_read(reg) for reg in (UC_X86_REG_RCX, UC_X86_REG_RDX)]
    if pc == 0x140c10324:
        assert x == 0xc0
        calls.append(['allocate', x]); m.finish(part)
    elif pc == 0x14007db60:
        assert x == gob + 0x470 and y == part
        calls.append(['append_gob_light_470', x, y]); m.finish()
    elif start <= pc < end:
        visits.add(pc)
    else:
        raise RuntimeError('Unexpected original light constructor dependency ' + hex(pc))
u.hook_add(UC_HOOK_CODE, hook)
def run(dynamic, affect, initial=0, has_owner=True):
    calls.clear(); visits.clear()
    u.mem_write(m.heap, bytes(0x100000)); u.mem_write(m.stack, bytes(0x20000))
    m.wi(light + 0x100, dynamic); m.wi(light + 0x104, affect); m.wi(gob + 0xf0, initial)
    rsp = m.stack + 0x1fe08; m.wq(rsp, m.stop)
    u.reg_write(UC_X86_REG_RSP, rsp); u.reg_write(UC_X86_REG_RCX, light); u.reg_write(UC_X86_REG_RDX, gob if has_owner else 0)
    u.emu_start(start, m.stop, count=20000)
    assert u.reg_read(UC_X86_REG_RIP) == m.stop
    expected = 1 if has_owner and (dynamic != 0 or affect != 0) else initial
    actual = m.si(gob + 0xf0)
    assert actual == expected and u.reg_read(UC_X86_REG_RAX) == part
    assert any(call[0] == 'append_gob_light_470' for call in calls) == (has_owner and dynamic == 0)
    return dict(dynamic=dynamic, affect=affect, initialF0=initial, ownerPresent=has_owner, expectedF0=expected, observedF0=actual, calls=list(calls), originalInstructionAddresses=[hex(pc) for pc in sorted(visits)])
rows = [run(dynamic, affect) for dynamic, affect in [(0,0),(0,1),(1,0),(1,1),(2,0),(0,2),(-1,0),(0,-1)]]
rows += [run(0,0,7),run(1,0,7),run(0,1,7),run(1,1,0,False),run(0,1,0,False),run(0,0,7,False)]
def rip_string(pc, expected):
    code = bytes(u.mem_read(pc, 7)); assert code[:3] == bytes.fromhex('488d0d')
    target = pc + 7 + struct.unpack('<i', code[3:])[0]
    data = bytearray()
    for n in range(64):
        value = u.mem_read(target+n, 1)[0]
        if value == 0: break
        data.append(value)
    text = data.decode('ascii'); assert text.lower() == expected.lower()
    return dict(instruction=hex(pc), codeHex=code.hex(), target=hex(target), text=text)
mapping = [dict(fieldOffset='0x100', destinationInstruction='0x14009e1cb', string=rip_string(0x14009e1b7,'isdynamic')),dict(fieldOffset='0x100', destinationInstruction='0x14009e230', string=rip_string(0x14009e21c,'nDynamicType')),dict(fieldOffset='0x104', destinationInstruction='0x14009e297', string=rip_string(0x14009e287,'affectdynamic'))]
functions = [dict(address=hex(a),end=hex(b),sha256=hashlib.sha256(bytes(u.mem_read(a,b-a))).hexdigest()) for a,b in [(start,end),(0x14009db90,0x14009e611),(0x140087640,0x140087733)]]
out = root / 'godot-client/.cache/native-render-gap/original/admission-chain/light-exemption-instructions-a.json'
assert not out.exists(), 'Preserve prior instruction observations'
out.write_text(json.dumps(dict(version=1,success=True,subjectSha256=m.digest,limits=__doc__,functions=functions,parserFieldMapping=mapping,rows=rows,scope='Owner flag is set at light construction if isdynamic/nDynamicType OR affectdynamic is nonzero; not based on admitted/visible/budgeted lights. Existing nonzero flag survives constructing a nonqualifying light. Other producers/clearers and live room coverage remain separate audits.'),indent=2))
print(json.dumps(dict(output=str(out),sha256=hashlib.sha256(out.read_bytes()).hexdigest(),cases=len(rows))))
