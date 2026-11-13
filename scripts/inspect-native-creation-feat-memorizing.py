"""Execute original FeatRequirementsMet7ee690's positive spell prerequisite,
including memorizing GetSpellGain7f6b20 and its real stat/race/prestige helpers.
Decoded native fixtures and a captured ruleset lookup service are explicit;
this is not table-loader, live draft, server, renderer or original-pixel proof.
No original prerequisite, spell gain, ability or prestige helper is replaced.
"""
import argparse
import hashlib
import importlib.util
import json
import random
import struct
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "feat_prerequisites", Path(__file__).with_name("inspect-native-creation-feat-requirements.py")
)
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RSP, UC_X86_REG_RIP, UC_X86_REG_RAX

q.ranges += [
    (0x140299E70, 0x140299FE8), (0x140299E40, 0x140299E68),
    (0x1402A1460, 0x1402A149D), (0x140299710, 0x14029978E),
    (0x1407F0F60, 0x1407F0FC6), (0x1407F1110, 0x1407F1226),
    (0x1407EC3A0, 0x1407EC50B), (0x1407F6B20, 0x1407F710A),
    (0x1407F1080, 0x1407F109F), (0x1407F69A0, 0x1407F6A06),
    (0x1402A4A30, 0x1402A4A49),
]
SERVICES = {0x1402AE870: "ruleset-key", 0x1402A4130: "ruleset-int"}
q.ranges += [(address, address + 1) for address in SERVICES]
original_start = q.u.emu_start
active = None
keys = []


def ruleset_service(u, address, _size, _data):
    if address not in SERVICES:
        return
    x, y, z = [u.reg_read(reg) for reg in (UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8)]
    if SERVICES[address] == "ruleset-key":
        key = bytes(u.mem_read(x, 128)).split(b"\0")[0].decode("ascii")
        # The original FNV seed has already consumed the initial C byte.
        key = "C" + key if key.startswith("HARGEN_") else key
        keys.append(key)
        q.m.finish(len(keys))
    else:
        assert 1 <= y <= len(keys), "Unexpected ruleset key handle"
        q.m.finish(active["settings"].get(keys[y - 1], z & 0xFFFFFFFF))


q.u.hook_add(UC_HOOK_CODE, ruleset_service)


def prepare_spell_storage(case):
    race = q.m.heap + 0x70000
    # Reached GetClass7f0f60 validates physical IDs against these original
    # rule-loader counts. The earlier prerequisite-only fixture did not need
    # them; leaving zero here would redirect every stat gain to class0.
    q.byte(q.rules + 0x105, max(cls["id"] for cls in case["classes"]) + 1)
    q.byte(q.rules + 0x106, 1)
    q.m.wq(q.rules + 0x118, race)
    q.word(q.actor + 0x50, 0)
    for offset, value in zip((0x18, 0x19, 0x1D, 0x1A, 0x1C, 0x1B), case["raceAdjust"]):
        q.byte(race + offset, value)
    q.u.mem_write(q.actor + 0x76, bytes(value & 255 for value in case["baseAbilities"]))
    q.u.mem_write(q.actor + 0x7D, bytes(value & 255 for value in case["abilityBonuses"]))
    q.byte(q.actor + 0x7C, case["dexterityAdjustment"])
    for index, cls in enumerate(case["classes"]):
        cp = q.native_classes + cls["id"] * 0x530
        spell = cls["spell"]
        for offset, name in ((0x4D8, "SpellCaster"), (0x4EC, "MemorizesSpells"),
                             (0x4F0, "SpellbookRestricted"), (0x4FC, "LearnScroll"),
                             (0x4F8, "PickSchool"), (0x500, "Arcane")):
            q.m.wi(cp + offset, spell[name])
        q.m.wi(cp + 0x4D4, 1)
        q.byte(cp + 0x4E8, spell["ability"])
        q.byte(cp + 0x525, spell["ArcSpellLvlMod"])
        q.byte(cp + 0x526, spell["DivSpellLvlMod"])
        q.byte(q.actor + index * 0x150 + 0x292, spell["school"])
        known_array = q.m.heap + 0x71000 + index * 0x1000
        known_rows = q.m.heap + 0x75000 + index * 0x1000
        gain_rows = q.m.heap + 0x79000 + index * 0x1000
        q.m.wq(cp + 0x130, known_array if spell["knownPresent"] else 0)
        for level in range(60):
            for ability, value in enumerate(spell["statGain"][level]):
                q.byte(cp + 0x2F6 + level * 6 + ability, value)
        for level in range(40):
            count = spell["NumSpellLevels"] & 255
            q.byte(cp + 0x138 + level, count)
            q.m.wq(known_array + level * 8, known_rows + level * 16 if count else 0)
            q.m.wq(cp + 0x160 + level * 8, gain_rows + level * 16 if count else 0)
            q.u.mem_write(known_rows + level * 16, bytes(value & 255 for value in spell["known"]))
            q.u.mem_write(gain_rows + level * 16, bytes(value & 255 for value in spell["gain"]))


def start(address, until, *args, **kwargs):
    prepare_spell_storage(active)
    return original_start(address, until, *args, **kwargs)


q.u.emu_start = start


def invoke(address, args):
    rsp = q.m.stack + 0x1FE08
    q.m.wq(rsp, q.m.stop)
    q.u.reg_write(UC_X86_REG_RSP, rsp)
    for reg, value in zip((UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9), args):
        q.u.reg_write(reg, value)
    original_start(address, q.m.stop, count=300000)
    assert q.u.reg_read(UC_X86_REG_RIP) == q.m.stop, "Original execution exceeded its finite instruction budget"
    return q.u.reg_read(UC_X86_REG_RAX) & 255


def make_cases():
    rng = random.Random(91037)
    cases = []
    for index in range(384):
        classes = []
        for at in range(1 + index % 3):
            caster = not (index % 4 == 3 and at == 1)
            spell = dict(
                SpellCaster=int(caster), MemorizesSpells=int(at == 0 or index % 3 != 0),
                SpellbookRestricted=int((index + at) % 3 != 0), LearnScroll=int((index + at) % 4 == 0),
                PickSchool=int((index + at) % 3 == 0), Arcane=int(at % 2 == 0),
                ability=(index + at) % 6, ArcSpellLvlMod=(index % 3) + 1 if not caster else 0,
                DivSpellLvlMod=(index % 2) + 1 if not caster else 0,
                school=index % 3, knownPresent=index % 7 != 0,
                NumSpellLevels=[0, 1, 2, 5, 10][(index // 3 + at) % 5],
                known=[rng.choice([0, 0, 1, 2, 255]) for _ in range(10)],
                gain=[rng.choice([0, 0, 1, 2, 255]) for _ in range(10)],
                statGain=[[rng.choice([-2, 0, 0, 1, 2]) if level < 3 else 0 for _ in range(6)] for level in range(60)],
            )
            classes.append(dict(id=at * 2 + 1, level=[1, 2, 3, 8, 20, 40][(index + at) % 6], skills=[], feats=[], spell=spell))
        feat = dict(MINSPELLLVL=[0, 1, 2, 3, 5, 9, 10, 255][index % 8],
                    MinLevelClass=255, PREREQFEAT1=65535, PREREQFEAT2=65535,
                    REQSKILL=65535, REQSKILL2=65535, ReqSkillMinRanks=0,
                    ReqSkillMinRanks2=0, PreReqEpic=0, OrReqFeats=[65535] * 5)
        cases.append(dict(
            featId=2, feat=feat, current=index % len(classes), classes=classes,
            scores=[rng.choice([3, 8, 10, 14, 18, 24, 127, 255]) for _ in range(6)],
            baseAttack=0, fortitude=0, skills=[], owned=[], secondary=[], selected=[],
            baseAbilities=[rng.choice([0, 3, 8, 11, 18, 127, 128, 255]) for _ in range(6)],
            raceAdjust=[rng.choice([-128, -2, 0, 2, 127]) for _ in range(6)],
            abilityBonuses=[rng.choice([-128, -2, 0, 0, 1, 2, 127]) for _ in range(6)],
            dexterityAdjustment=rng.choice([-2, 0, 1, 2]),
            settings=[{}, {"CHARGEN_BASE_ABILITY_MIN_PRIMARY": 9, "CHARGEN_ABILITY_NEUTRAL_VALUE": 11, "CHARGEN_ABILITY_MODIFIER_INCREMENT": 3}, {"CHARGEN_BASE_ABILITY_MIN_PRIMARY": 12}][index % 3],
        ))
    return cases


def main():
    global active, keys
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    report = Path(args.report).resolve()
    report.relative_to(q.m.root.resolve())
    if report.exists():
        raise FileExistsError("Preserve existing evidence: " + str(report))
    rows = []
    for case in make_cases():
        active = case
        keys = []
        outcome = q.run(case)
        required = case["feat"]["MINSPELLLVL"] & 255
        outcome["memorizingGains"] = [
            {"index": index, "gain": invoke(0x1407F6B20, [q.actor, index, required])}
            for index, cls in enumerate(case["classes"])
            if cls["spell"]["SpellCaster"] and cls["spell"]["MemorizesSpells"]
        ]
        outcome["abilityGains"] = [invoke(0x1407F1110, [q.actor, ability]) for ability in range(6)]
        outcome["rulesetKeys"] = sorted(set(keys))
        rows.append(outcome)
    sources = [Path(__file__), Path(q.__file__), Path(q.m.__file__)]
    packet = dict(
        target=q.m.digest, scope=__doc__, rows=rows,
        sourceSha256={str(path.relative_to(q.m.root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
        procedures=[dict(address=hex(lo), endExclusive=hex(hi), sha256=hashlib.sha256(q.m.data[q.m.pe.get_offset_from_rva(lo - q.m.base):q.m.pe.get_offset_from_rva(lo - q.m.base) + hi - lo]).hexdigest()) for lo, hi in q.ranges if lo not in SERVICES],
        boundaries=[dict(address=hex(address), service=name) for address, name in SERVICES.items()],
        publicConnections=0, gpu=False, nativeBuilds=0,
    )
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(packet, indent=2))
    print(json.dumps(dict(output=str(report), cases=len(rows), accepted=sum(row["accepted"] for row in rows), publicConnections=0, gpu=False)))


if __name__ == "__main__":
    main()
