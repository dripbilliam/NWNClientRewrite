"""Read-only execution of original GetAbilityModifier1407ec3a0 instructions.
Reuses the pinned original-client constructor harness. Only hash/ruleset lookup
services are captured; the original arithmetic and branches execute unchanged.
These are display-oracle cases, not server-authoritative ability mutations.
"""
import importlib.util,itertools,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('native_hp',Path(__file__).with_name('inspect-native-client-presentation-hp.py'))
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
variants=[{},dict(CHARGEN_ABILITY_NEUTRAL_VALUE=11,CHARGEN_ABILITY_MODIFIER_INCREMENT=3),dict(CHARGEN_ABILITY_NEUTRAL_VALUE=12,CHARGEN_ABILITY_MODIFIER_INCREMENT=3),dict(CHARGEN_ABILITY_NEUTRAL_VALUE=0,CHARGEN_ABILITY_MODIFIER_INCREMENT=1),dict(CHARGEN_ABILITY_NEUTRAL_VALUE=10,CHARGEN_ABILITY_MODIFIER_INCREMENT=-2)]
rows=[]
for rules,score in itertools.product(variants,list(range(256))+[-1,256,511]):
 h.c=rules;h.keys=[];h.queries=[];h.m.wq(0x1412df8f8,h.rules)
 result=h.call(0x1407ec3a0,[h.actor,score&0xffffffffffffffff])
 byte=result&255
 rows.append(dict(rules=rules,score=score,modifier=byte-256 if byte>=128 else byte,raw32=result,queries=list(dict.fromkeys(h.queries))))
out=h.m.root/'backups/animations/native-record-ability-observations-v1.json'
assert not out.exists(),'Preserve prior evidence'
out.write_text(json.dumps(dict(target=h.m.digest,scope=__doc__,rows=rows),indent=2))
print(json.dumps(dict(output=str(out),rows=len(rows),target=h.m.digest)))
