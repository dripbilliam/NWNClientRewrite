import {creatureRoot} from './creature_rules.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native appearance ${n} is unavailable`);return v|0;};

// Decoded ExecuteCommandGetAppearanceType14051ec20: the three owners have
// different physical widths. Use the same live GFF-backed state consumed by
// rendering/rules, never cache an authored creature appearance separately.
export function scriptAppearanceType(object){
 if(!object)return -1;
 if(object.objectType===5)return integer(creatureRoot(object)?.Appearance_Type,'creature WORDa74')&65535;
 if(object.objectType===9)return integer(object.authored?.Appearance,'placeable WORD32c')&65535;
 if(object.objectType===10)return integer(object.authored?.Appearance,'door DWORD3f8');
 return -1;
}
export function scriptCreatureSize(object){return object?.objectType===5?integer(object.nativeSize718,'creature size718'):0;}
export function scriptCreatureTail(object){return object?.objectType===5&&object.stats?integer(object.stats.nativeTailE18,'stats tailE18'):0;}
// GetSubRace140531050 copies stats CExoStringD28 (or an empty string when the
// creature/stats are absent). Modern decoded GFF stores it as Subrace text.
// Legacy localized-string-to-text import is an explicit separate lower owner.
export function scriptSubrace(object){
 if(object?.objectType!==5||!object.stats)return '';
 const value=creatureRoot(object)?.Subrace??'';
 if(typeof value!=='string')throw new Error('Native legacy localized subrace import is unavailable');
 return value;
}

// Stats ctor1403ee5cf initializes E18=0. ReadStatsFromGff1404103b0..416:
// DWORD Tail_New wins; otherwise BYTE Tail, otherwise preserve current E18.
// This adapter accepts decoded integer fields; malformed GFF conversion remains
// an explicit load error rather than guessing a replacement appearance.
export function importCreatureTail(root,current=0){
 current=integer(current,'current tailE18');
 if(Object.hasOwn(root,'Tail_New'))return integer(root.Tail_New,'Tail_New');
 if(Object.hasOwn(root,'Tail'))return integer(root.Tail,'Tail')&255;
 return current;
}
