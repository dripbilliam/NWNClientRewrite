"""Read-only original live CCharPageFeats1409c0920 and Spells1409c1810.
Actual instructions enumerate and admit rows, including minimum/slot/gain and
known-spell getters. Object lookup, raw tables/stats, UI/TLK/row insertion and
allocation are explicit fixture boundaries. Not live-client/visual acceptance
or proof of full original draft initialization, child panes or saving.
"""
import importlib.util,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def module(name,file):
 spec=importlib.util.spec_from_file_location(name,Path(__file__).with_name(file));value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
if __name__=='__main__':
 out=root/'backups/animations/native-creation-summary-list-observations-v2.json'
 assert not out.exists(),'Preserve prior evidence'
 feat=module('feat','inspect-native-pregame-feats.py')
 prior=json.loads((root/'backups/animations/native-record-feat-observations-v1.json').read_text())
 feats=[feat.run(row['case'],live=True)for row in prior['rows']]
 assert [row['selected']for row in feats]==[row['selected']for row in prior['rows']]
 spell=module('spell','inspect-native-pregame-spells.py')
 prior=json.loads((root/'backups/animations/native-pregame-spell-observations-v2.json').read_text())
 assert prior['target']==feat.m.digest==spell.m.digest
 spells=[spell.run(row['case'],live=True)for row in prior['rows']]
 out.write_text(json.dumps(dict(target=feat.m.digest,procedures=['0x1409c0920','0x1409c1810'],scope=__doc__,feats=feats,spells=spells),indent=2))
 print(json.dumps(dict(output=str(out),featCases=len(feats),spellCases=len(spells))))
