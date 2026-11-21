import {test} from 'node:test';
import assert from 'node:assert/strict';
import {bicSemantics,normalizePregame,normalReleaseArguments} from '../native-release-functional-lib.mjs';

test('existing raw release entry uses bootstrap argument without forbidden path override',()=>{
 const args=normalReleaseArguments('tests/a.gd','C:/owned/report','C:/owned/log','C:/install','C:/fixture');
 assert.ok(args.includes('--release-entry=res://tests/a.gd'));assert.ok(!args.includes('--path'));assert.ok(!args.includes('--main-pack'));
 assert.ok(args.includes('--entity-api-rest=false'));assert.throws(()=>normalReleaseArguments('native_session_world.gd','','','',''));
});
test('menu parity retains exact intent ordering/counts and rejects network claims',()=>{
 const value={success:true,publicConnections:0,gameServerConnections:0,checks:24,failures:[],recorded_intents:[{kind:'browser-input',connection:1,operation:'join'}]};
 assert.deepEqual(normalizePregame(value).recorded_intents,value.recorded_intents);
 assert.throws(()=>normalizePregame({...value,gameServerConnections:1}));
});
test('independent BIC projection keeps all values, GFF field types and struct types',()=>{
 const types=new WeakMap(),structs=new WeakMap(),getTypes=value=>types.get(value),getStruct=value=>structs.get(value);
 const a={FamiliarName:'One',Appearance_Head:44,xAppearance_Head:300,Equip_ItemList:[{EquippedRes:'cloth'}]};
 const b={FamiliarName:'Two',Appearance_Head:44,xAppearance_Head:300,Equip_ItemList:[{EquippedRes:'cloth'}]};
 for(const root of [a,b]){types.set(root,{FamiliarName:10,Appearance_Head:0,xAppearance_Head:2});types.set(root.Equip_ItemList[0],{EquippedRes:11});structs.set(root.Equip_ItemList[0],2);}
 assert.deepEqual(bicSemantics(a,getTypes,getStruct),bicSemantics(b,getTypes,getStruct));
 b.xAppearance_Head=301;assert.notDeepEqual(bicSemantics(a,getTypes,getStruct),bicSemantics(b,getTypes,getStruct));b.xAppearance_Head=300;
 types.get(b).xAppearance_Head=0;assert.notDeepEqual(bicSemantics(a,getTypes,getStruct),bicSemantics(b,getTypes,getStruct));
});
