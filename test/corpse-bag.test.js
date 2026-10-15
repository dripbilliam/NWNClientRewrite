import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {corpseBagAppearance,getBodyBag,setBodyBag,importPlaceableBodyBag} from '../src/corpse_inventory.js';
import {parse2da} from '../src/area.js';
import {intEntry} from '../src/combat_stats.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-corpse-bag-observations.json',import.meta.url)));
test('body-bag appearance matches original creature/placeable shortcuts and distinct active-table fallback columns',async()=>{
  for(const row of oracle.selectors){const c=row.case,calls=[],actor={objectType:c.mode==='creature'?5:9,nativeLootable4e8:c.lootable,nativeBodyBag8a8:c.bag&255,nativeBodyBag59c:c.bag&255};let query=0;
    const result=await corpseBagAppearance(actor,{appearance:()=>c.appearance,entry:(...args)=>{calls.push(['entry',...args]);return c.entries[Math.min(query++,c.entries.length-1)];}});
    assert.deepEqual({result,calls},{result:row.result,calls:row.calls},JSON.stringify(c));
  }
});
test('body-bag setter queries raw physical row before canonical lookup and only truncates the write',async()=>{
  for(const row of oracle.setters){const c=row.case,calls=[],creature={objectType:5,nativeBodyBag8a8:c.bag},placeable={objectType:9,nativeBodyBag59c:c.bag};
    await setBodyBag(77,c.requested,{entry:(...args)=>{calls.push(['entry',...args]);return c.entries[0];},creature:id=>{calls.push(['creature',id]);return c.creature?creature:null;},placeable:id=>{calls.push(['placeable',id]);return c.placeable?placeable:null;}});
    assert.deepEqual({calls,creatureBag:creature.nativeBodyBag8a8,placeableBag:placeable.nativeBodyBag59c},{calls:row.calls,creatureBag:row.creatureBag,placeableBag:row.placeableBag},JSON.stringify(c));
  }
  for(const row of oracle.getters){const c=row.case,actor=c.creature?{objectType:5,nativeBodyBag8a8:c.bag&255}:c.placeable?{objectType:9,nativeBodyBag59c:c.bag&255}:null;assert.equal(getBodyBag(actor),row.result,JSON.stringify(c));}
});
test('body-bag selection uses physical override rows and placeable import retains existing BYTE fallback',async()=>{
  const tables={bodybag:parse2da('2DA V2.0\n\nAppearance\n500 42\n600 55\n'),appearance:parse2da('2DA V2.0\n\nBody_Bag BodyBag\n700 0 1\n')};
  const p={entry:(name,row,column)=>intEntry(tables[name],row,column),appearance:()=>0};
  assert.equal(await corpseBagAppearance({objectType:5,nativeLootable4e8:0,nativeBodyBag8a8:250},p),42);
  const placeable={objectType:9,nativeBodyBag59c:250};assert.equal(await corpseBagAppearance(placeable,p),55);
  importPlaceableBodyBag(placeable,{});assert.equal(placeable.nativeBodyBag59c,250);
  importPlaceableBodyBag(placeable,{BodyBag:259});assert.equal(placeable.nativeBodyBag59c,3);
});
