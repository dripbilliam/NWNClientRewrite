const test=require('node:test'),assert=require('node:assert/strict');
const {snapshot,compare}=require('../tools/native-creation-export-proof.cjs');
test('export projection preserves extended values, original body order and real equipment metadata',()=>{
 const row={TemplateResRef:'native_clothes',BaseItem:16,ArmorPart_RFoot:3,ArmorPart_LFoot:4,xArmorPart_Torso:600,ArmorPart_Torso:0};
 const value=snapshot({FirstName:{entries:[{text:'Native'}]},LastName:{entries:[{text:' Source '}]},xAppearance_Head:700,Appearance_Head:0,xBodyPart_Torso:500,BodyPart_Torso:0,ArmorPart_RFoot:8,BodyPart_LFoot:9,Equip_ItemList:[row]},()=>2);
 assert.equal(value.head,700);assert.equal(value.skinParts[0],8);assert.equal(value.skinParts[1],9);assert.equal(value.skinParts[7],500);assert.equal(value.equipment[0].parts[7],600);assert.equal(value.equipment[0].template,'native_clothes');assert.equal(value.lastName,' Source ');
});
test('server export proof requires concrete admitted outfit and all accepted source fields',()=>{
 const expected={firstName:'Native',lastName:'Source',sourceTailAppearance:{value:{phenotype:0,head:1,skin:2,hair:3,tattoo1:4,tattoo2:5,skinParts:Array(19).fill(1),bodyParts:Array(19).fill(2)},choice:{resRef:'native_clothes'}},sourceTailInformation:{soundset:8,deity:'Deity'}};
 const actual={firstName:'Native',lastName:'Source',soundset:8,deity:'Deity',phenotype:0,head:1,colors:{skin:2,hair:3,tattoo1:4,tattoo2:5},skinParts:Array(19).fill(1),equipment:[{slot:2,baseItem:16,template:'native_clothes',parts:Array(19).fill(2)}]};
 assert.equal(compare(expected,actual).success,true);
 for(const mutate of [a=>a.firstName='Other',a=>a.head=2,a=>a.skinParts[7]=9,a=>a.equipment=[],a=>a.equipment[0].baseItem=null,a=>a.equipment[0].parts[7]=9]){const changed=structuredClone(actual);mutate(changed);assert.equal(compare(expected,changed).success,false);}
 assert.equal(compare({},actual).success,false);
 assert.equal(compare(expected,{}).success,false);
});
test('an upload reference-only equipped row is not authoritative outfit creation',()=>{
 const actual=snapshot({Equip_ItemList:[{EquippedRes:'native_clothes'}]},()=>2);
 assert.equal(actual.equipment[0].baseItem,null);assert.equal(actual.equipment[0].template,'native_clothes');
});
