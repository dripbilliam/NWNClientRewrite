import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptCopyItemAndModify} from '../src/script_item_copy.js';
import {modifyCopiedItemAppearance} from '../src/item_appearance_modify.js';
import {baseItemReference} from '../src/base_item_references.js';
import {setItemPartColor} from '../src/item_part_colors.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-appearance-modify-observations.json',import.meta.url))),INVALID=0x7f000000;
const info=c=>({modelType:c.modelType??2,category:c.category??0,itemClass:c.itemClass??'Sword',genderSpecific:c.genderSpecific??0,defaultModel:'DefaultModel',defaultIcon:'FallbackIcon'});
test('both complete resource-reference owners match native SHORT model, BYTE component, gender and16-byte truncation',()=>{
 const rows=data.rows.filter(r=>r.case.reference);assert.ok(rows.length>500);
 for(const row of rows){const c=row.case;assert.equal(baseItemReference(info(c),c.icon,c.component??0,c.model??0,c.gender??109),row.reference,JSON.stringify(c));}
});
test('complete CopyItemAndModify matches native field validation, warnings, resources, colors, armor/weight and all placement paths',async()=>{
 const rows=data.rows.filter(r=>!r.case.reference);assert.ok(rows.length>700);
 for(const row of rows){const c=row.case,trace=[],source={...structuredClone(row.before),id:42,baseItem:c.base??22,possessorId:c.possessor??INVALID},destination={id:c.id??43,modelParts:Array(3).fill(0),armorParts:Array(19).fill(0),colors:Array(6).fill(0),partColors:Array(6).fill(null),nativeBaseArmor35c:0,nativeUnitWeight45c:0},target={id:101},existing={id:44},base=info(c);let cursor=0,output;
  const appearance={baseInfo:o=>{trace.push(['base',o.baseItem]);return base;},warning:line=>trace.push(['warning',line]),
   modelReference:(b,p,m,g)=>{trace.push(['model',p,m,g]);return baseItemReference(b,false,p,m,g);},iconReference:(b,p,m,g)=>{trace.push(['icon',p,m,g]);return baseItemReference(b,true,p,m,g);},
   exists:(name,type)=>{trace.push(['exists',name,type]);return name==='FallbackIcon'?c.fallbackExists??1:type===2002?c.modelExists??1:c.iconExists??1;},partTable:index=>index<19&&!c.missingPartTable?{}:null,rowCount:()=>c.rows??12,
   armor:()=>{trace.push(['armor']);return c.computedArmor??17;},weight:o=>{trace.push(['weight']);o.nativeUnitWeight45c=c.computedWeight??99;},partColor:(o,ch,p,v)=>{trace.push(['partColor',ch,p,v]);setItemPartColor(o,ch,p,v);},cloakTable:()=>c.missingCloakTable?null:{},cloakIcon:(_t,i)=>{trace.push(['cloakIcon',i>>>0]);return c.cloakIcon??3;}};
  const cast=name=>o=>{trace.push(['cast',name]);return(name==='world'?c.world!==false:(c.kind??5)==={creature:5,placeable:9,item:6,store:14}[name])?o:null;},acquire=(kind,o,ref,...args)=>{trace.push(['acquire',kind,...args]);if(c.mutation==='existing'&&kind!==14)ref.item=existing;return c.acquire??1;};
  const result=await scriptCopyItemAndModify(c.argc??5,{pop:type=>{trace.push(['pop',type]);const i=cursor++;return{ok:i!==c.failPop,value:[c.sourceId??42,c.type??4,c.index??0,c.value??1,c.variables??0][i]};},push:id=>{output=id;trace.push(['push',id]);return c.push??1;},warning:appearance.warning,item:id=>{trace.push(['item',id]);return c.source===false?null:source;},construct:()=>{trace.push(['allocate',1136],['construct',INVALID]);return destination;},
   copy:(d,s,v)=>{trace.push(['copy',v]);for(const key of['modelParts','armorParts','colors'])d[key]=structuredClone(s[key]);d.nativeBaseArmor35c=s.armor;d.nativeUnitWeight45c=s.weight;return c.copy??1;},destroy:(o,n)=>trace.push(['destroy',o.id,n]),modify:(...args)=>modifyCopiedItemAppearance(...args,appearance),setPossessor:(o,...args)=>trace.push(['possessor',o.id,...args]),
   object:id=>{trace.push(['object',id]);return c.target===false?null:target;},asWorld:cast('world'),asCreature:cast('creature'),asPlaceable:cast('placeable'),asItem:cast('item'),asStore:cast('store'),position:o=>o===source?[1.25,-2.5,3.75]:[2.5,-5,7.5],area:o=>{trace.push(['area',o===source?'source':'target']);return c.area===false?null:{};},addToArea:(o,a,...args)=>trace.push(['addArea',o.id,Number(Boolean(a)),...args]),acquireCreature:(...args)=>acquire(5,...args),acquirePlaceable:(...args)=>acquire(9,...args),acquireContainer:(...args)=>acquire(6,...args),acquireStore:(...args)=>acquire(14,...args)});
  const after={modelParts:destination.modelParts,armorParts:destination.armorParts,colors:destination.colors,partColors:destination.partColors,armor:destination.nativeBaseArmor35c,weight:destination.nativeUnitWeight45c};assert.equal(result>>>0,row.result,JSON.stringify(c));assert.equal(output,row.output??undefined,JSON.stringify(c));assert.deepEqual(after,row.after,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
