import {nativeFloatEntry} from './movement_rate.js';
// Spell target setup704720 and range lookup704a50. P/T share the native
// touch range; dimensions/shape are active-table values, never spell-ID rules.
export function spellTargetPreview(spell,ranges,override){
 if(!spell)return null;const index=({P:1,T:1,S:2,M:3,L:4})[spell.range];
 return{shape:override?.shape??spell.targetShape??0,sizeX:override?.sizeX??spell.targetSizeX??0,sizeY:override?.sizeY??spell.targetSizeY??0,flags:override?.flags??spell.targetFlags??0,range:index===undefined||!ranges?0:nativeFloatEntry(ranges,index,'PrimaryRange').value,spellId:spell.id??-1,featId:-1};
}
// Native graphics.spell-targeting-effect.color schema defaults: dangerous,
// harmful, helpful, other. Selection follows704bd0's five flag branches.
export function targetPreviewColor(flags){return flags&1?flags&2?[1,0,0,1]:[0,0,1,1]:flags&4?[0,1,0,1]:[1,1,1,1];}
