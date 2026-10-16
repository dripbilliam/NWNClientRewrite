import test from 'node:test';
import assert from 'node:assert/strict';
import {parse2da} from '../src/area.js';
import {featRadialProviders} from '../src/feat_radial_rules.js';
import {collectClassAbilities,classAbilityPage} from '../src/feat_radial.js';
const rules=()=>({
 classes:parse2da('2DA V2.0\n\nName FeatsTable\n0 100 custom\n1 101 custom\n2 102 custom'),
 feat:parse2da('2DA V2.0\n\nFeat SUCCESSOR SpellId ReqAction TargetSelf ICON\n0 123 **** -1 1 0 icon0\n1 124 2 10 1 -1 icon1\n2 125 **** 10 0 0 icon2'),
 spells:parse2da('2DA V2.0\n\nName FeatID\n0 200 1'),
 domains:parse2da('2DA V2.0\nDEFAULT:7\n\nName GrantedFeat CastableFeat\n0 301 1 1\n1 **** 2 1'),
 classTables:new Map([['custom',parse2da('2DA V2.0\n\nFeatIndex OnMenu\n0 1 1\n1 2 1')]])
});
const actor=()=>({id:99,objectType:5,combatMode:0,creatureData:{ClassList:[{Class:0}],FeatList:[{Feat:1}]} });
const p={remaining:()=>5,warning:()=>{}};
test('radial metadata reads active custom class tables, raw successor/self flags and separate bonus pool',()=>{
 const o=actor(),r=rules(),v=featRadialProviders(o,o,r,p);assert.deepEqual(collectClassAbilities(v),[{group:0,classIndex:0,firstFeat:1}]);
 assert.equal(v.feat(1).successor,2);assert.equal(v.feat(1).targetSelf,-1);assert.equal(v.feat(2).successor,-1);
 o.nativeBonusFeats20=[2];assert.deepEqual(collectClassAbilities(v),[{group:1,classIndex:0,firstFeat:1}]);
 assert.deepEqual(classAbilityPage(0,0,v),[{slot:0,featId:2,classIndex:255}]);
 r.classTables.set('custom',parse2da('2DA V2.0\n\nFeatIndex OnMenu\n0 2 2'));
 assert.deepEqual(collectClassAbilities(featRadialProviders(o,o,r,p)),[]);
});
test('domain projection uses byte row count and Name validity with native constructor defaults',()=>{
 const r=rules(),o=actor();o.creatureData.ClassList[0].Class=2;
 const v=featRadialProviders(o,o,r,p);assert.deepEqual(v.domain(0),{featId:1,castable:1});assert.equal(v.domain(1),null);
 assert.deepEqual(collectClassAbilities(v),[{group:1,classIndex:0,firstFeat:65535}]);
 r.domains=parse2da('2DA V2.0\nDEFAULT:7\n\nName\n0 100');
 assert.deepEqual(featRadialProviders(o,o,r,p).domain(0),{featId:65535,castable:0});
});
test('invalid native class feat input preserves dynamic count and diagnoses untouched allocation reads',()=>{
 const r=rules(),o=actor();r.classTables.set('custom',parse2da('2DA V2.0\n\nFeatIndex OnMenu\n0 9 1\n1 1 1\n2 2 1'));
 const v=featRadialProviders(o,o,r,p),cls=v.classInfo(0);assert.equal(cls.featCount,2);assert.deepEqual(v.classFeat(cls,0),{id:1,onMenu:1});
 assert.throws(()=>v.classFeat(cls,1),/uninitialized loader storage/);
});
