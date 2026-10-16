"""Complete ApplyRegeneration1404725f0 with actual original effect base ctor
and SetInteger. SetCreator/item ownership and nested ApplyEffect captured; not
the equipment traversal/tick/healing owners (independently tested elsewhere).
"""
import importlib,itertools,json
m=importlib.import_module('inspect-native-item-property-materializers')
rows=[m.run(dict(kind='regeneration',type=51,costValue=amount,slot=slot,loading=loading))for amount,slot,loading in itertools.product([-1,0,1,19,20,21,65535,65536],[1,16,32],[0,1,3])]
out=m.m.root/'backups/animations/native-item-regeneration-observations.json';out.write_text(json.dumps(dict(binarySha256=m.m.digest,limits=__doc__,rows=rows),indent=2)+'\n');print(json.dumps(dict(rows=len(rows),output=str(out))))
