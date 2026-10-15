import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {enumerateItemProperty,validItemProperty,itemPropertyValue,itemHasProperty} from '../src/item_property_query.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-property-query-observations.json',import.meta.url)));
test('item property cursor, validity, scalar reads and native INT pool membership match original wrappers',()=>{
  for(const row of oracle.rows){const c=row.case,item={objectType:c.objectType??6,effectCursor:c.cursor??0,effects:structuredClone(c.effects??[]),
    activeProperties:(c.active??[]).map(type=>type===null?null:{type}),passiveProperties:(c.passive??[]).map(type=>type===null?null:{type})},
    effect={type:c.type??91,integers:c.integers??[-1,2,3,4,5,6,7,8]};let output;
    if(c.mode==='enumerate'){item.effects.forEach((e,i)=>e.index=i);const result=enumerateItemProperty(c.exists===false?null:item,c.ordinal===612,()=>({type:0,index:null}));output={type:result.type,index:result.index};}
    else if(c.mode==='valid')output=validItemProperty(c.exists===false?null:effect);
    else if(c.mode==='value')output=itemPropertyValue(c.exists===false?null:effect,c.ordinal);
    else output=itemHasProperty(c.exists===false?null:item,c.query);
    assert.deepEqual(output,row.output,JSON.stringify(c));assert.equal(item.effectCursor,row.cursor,JSON.stringify(c));
  }
});
