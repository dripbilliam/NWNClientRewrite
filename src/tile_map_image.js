import {objectTemplateResRef} from './create_object.js';

// ImageMap2D branch1402c7580..1402c7615 after ReadINI1402cc370. A
// missing field clears the output; an empty C string selects this native
// fallback. CResRef construction truncates at16 bytes and preserves case.
export function tileMapImageRef(value){
 if(value!==undefined&&typeof value!=='string')throw new Error('Native tile ImageMap2D string is unavailable');
 const text=(value??'').split('\0')[0];return objectTemplateResRef(text.length?text:'MIDE01_A09');
}
