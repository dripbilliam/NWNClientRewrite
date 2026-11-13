"""Execute unchanged original CalculateRadius with synthetic child ownership.

Synthetic part transform and AsChunkyParticle virtual providers, plus the CRT
sqrt provider, are inherited explicit boundaries. This observes current active
child contribution only; it is not a game replay or FPS measurement.
"""
from pathlib import Path
import sys, importlib, hashlib, json

root = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(root / 'scripts'))
h = importlib.import_module('inspect-native-emitter-admission')
m, u = h.m, h.u
from unicorn import UC_HOOK_MEM_READ, UC_HOOK_CODE

base = dict(mass=0, lifeexp=2, velocity=1, randvel=.25,
            sizestart=1, sizeend=2, sizemid=.5,
            sizestart_y=0, sizeend_y=0, sizemid_y=0,
            origin=[1, 2, 3], source_flags=4)
free_items, free_particle, free_child = [m.heap + x for x in (0x20000, 0x21000, 0x22000)]
future_child = m.heap + 0x23000
reads, visits = [], set()

def memory_hook(uc, access, address, size, value, unused):
    if (h.emitter + 0x130 <= address < h.emitter + 0x140 or
            free_items <= address < future_child + 0x200):
        reads.append([hex(address), size])

def code_hook(uc, address, size, unused):
    if 0x140061710 <= address < 0x1400619ee:
        visits.add(address)

u.hook_add(UC_HOOK_MEM_READ, memory_hook)
u.hook_add(UC_HOOK_CODE, code_hook)

def run(name, active, free=False, future=False, active_views=None):
    global reads, visits
    case = base | dict(chunks=active)
    if active_views is not None:
        case['chunk_views'] = active_views
    h.reset(case)
    m.wq(h.emitter + 0x50, h.source)
    m.wq(h.source + 0x68, h.model)
    u.mem_write(h.model + 0x92, bytes([case['source_flags']]))
    m.wq(h.emitter + 0x188, h.items)
    m.wi(h.emitter + 0x190, len(active))
    for j, child_data in enumerate(active):
        particle, child = h.particles + j * 0x100, h.children + j * 0x200
        m.wq(h.items + j * 8, particle)
        m.wq(particle, h.vt)
        if child_data is not None:
            m.wq(particle + 0x78, child)
            h.vec(child + 0xa8, child_data[:3])
            m.wf(child + 0x178, child_data[3])
    if free:
        # Retained native free-pool field +0x130 is intentionally not an input
        # to CalculateRadius. A very distant real child makes accidental reads visible.
        m.wq(h.emitter + 0x130, free_items)
        m.wi(h.emitter + 0x138, 1)
        m.wq(free_items, free_particle)
        m.wq(free_particle, h.vt)
        m.wq(free_particle + 0x78, free_child)
        h.vec(free_child + 0xa8, [10000, 20000, 30000])
        m.wf(free_child + 0x178, 1234)
    if future:
        # Allocation not yet referenced by any active particle at this boundary.
        h.vec(future_child + 0xa8, [40000, 50000, 60000])
        m.wf(future_child + 0x178, 2345)
    reads, visits = [], set()
    h.call(0x140061710, [h.emitter])
    return dict(name=name, input=case, freeChildPopulated=free,
                futureChildNotInActiveList=future,
                radius=m.rf(h.emitter + 0x20c),
                radius_word=bytes(u.mem_read(h.emitter + 0x20c, 4)).hex(),
                unrelatedFreeAndFutureReads=reads,
                executedOriginalInstructionAddresses=[hex(a) for a in sorted(visits)])

rows = [
    run('empty_active', []),
    run('one_nil_active_child', [None]),
    run('three_nil_active_children', [None, None, None]),
    run('free_child_only_empty_active', [], free=True),
    run('free_child_with_nil_active', [None, None], free=True),
    run('future_child_not_yet_active', [], future=True),
    run('future_and_free_children_not_active', [None], free=True, future=True),
    run('positive_live_child_becomes_active', [[101, 2, 3, 7]]),
    run('nil_then_live_child', [None, [101, 2, 3, 7]]),
    run('nonchunk_view_terminates_before_later_live_child', [None, [101, 2, 3, 7]], active_views=[0, 1]),
]
for row in rows[:7]:
    assert row['radius_word'] == rows[0]['radius_word'], row['name']
    assert not row['unrelatedFreeAndFutureReads'], row['name']
assert rows[7]['radius'] == 107
assert rows[8]['radius_word'] == rows[7]['radius_word']
assert rows[9]['radius_word'] == rows[0]['radius_word']

function_bytes = bytes(u.mem_read(0x140061710, 734))
file_offset = m.pe.get_offset_from_rva(0x61710)
assert function_bytes == m.data[file_offset:file_offset + 734], 'Original instructions changed'
output = root / 'godot-client/.cache/native-render-gap/original/chunk-childless-radius-a.json'
assert not output.exists(), 'Preserve prior observations'
result = dict(version=1, binarySha256=m.digest,
              function=dict(address='0x140061710', endInclusive='0x1400619ed',
                            bytes=734, sha256=hashlib.sha256(function_bytes).hexdigest(),
                            unchangedComparedToExactPE=True),
              harness=dict(source='scripts/inspect-native-emitter-admission.py',
                           sha256=hashlib.sha256((root/'scripts/inspect-native-emitter-admission.py').read_bytes()).hexdigest()),
              scope=__doc__, radii=rows,
              assertions=dict(childlessMatchesEmpty=7, positiveActiveChild=True,
                              nilChildContinues=True, nonchunkViewEarlyReturn=True,
                              populatedFreeAndFutureMemoryNotRead=True),
              limitations=['Synthetic transform/virtual/CRT providers are explicit lower boundaries.',
                           'An allocation absent from the current active array is ignored; this does not execute future creation callbacks.',
                           'This is instruction-level functional evidence, not a visual or performance result.'])
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(dict(output=str(output), rows=len(rows), binarySha256=m.digest,
                      functionSha256=result['function']['sha256'],
                      outputSha256=hashlib.sha256(output.read_bytes()).hexdigest())))
