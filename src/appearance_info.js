import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
import {nativeFloatEntry} from './movement_rate.js';
import {nativeStringEntry} from './spell_metadata.js';

// Full UpdateAppearanceDependantInfo1403a69f0..1403a6dc7, including the
// unconditional failed-query outputs and weapon scale's distinct fallback1.
export function updateAppearanceInfo(o,rules){
 const id=creatureRoot(o).Appearance_Type&65535,table=rules.appearance;
 if(!table)throw new Error('Native appearance table is unavailable');
 o.nativeField710=intEntry(table,id,'haslegs').value;
 o.nativeField70c=intEntry(table,id,'hasarms').value;
 o.nativeSize718=intEntry(table,id,'sizecategory').value;
 o.modelType=nativeStringEntry(table,id,'modeltype').value;
 const scale=nativeFloatEntry(table,id,'weaponscale');o.nativeWeaponScale720=scale.found?scale.value:Math.fround(1);
 o.nativeAttackRange71c=nativeFloatEntry(table,id,'PREFATCKDIST').value;
 o.nativeEncumbranceDirty53c=1;
}
