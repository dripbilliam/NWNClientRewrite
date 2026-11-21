import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {createSpellClassState} from '../src/spell_book.js';
import {parse2da} from '../src/area.js';
function fixture(){
 const s=new ModuleSession(null,{runStartupScripts:false});s.characterRules={classes:parse2da('2DA V2.0\n\nSpellCaster MemorizesSpells SpellTableColumn\n0 1 1 Custom'),
  spells:parse2da('2DA V2.0\n\nCustom Innate MetaMagic Master\n0 1 1 63 ****')};
 const o=s.register('creature','caster',{authored:{ClassList:[{Class:0,ClassLevel:3}],FeatList:[]},stats:{feats:[]}}),target=s.register('creature','target',{authored:{},stats:{}});
 o.nativeTalentClasses=[createSpellClassState()];o.nativeTalentClasses[0].memorized[1]=[{id:0,metamagic:16,domain:0,ready:1}];
 const casts=[];s.spells.add=async(o,r)=>{casts.push({actorId:o.id,...r});return 1;};return{s,o,target,casts};
}
test('script casting selects real prepared metamagic and uses class index with canonical IDs',async()=>{
 const {s,o,target,casts}=fixture();await s.commands.ActionCastSpellAtObject([0,target.id],{self:o.id});
 assert.equal(casts.length,1);assert.equal(casts[0].metamagic,16);assert.equal(casts[0].classIndex,0);assert.equal(casts[0].targetId,target.id);
 assert.equal(o.nativeTalentClasses[0].memorized[1][0].ready,1,'Queue admission does not consume the spell');
 await s.commands.ActionCastSpellAtLocation([0,{areaId:3,position:[2,3,4]},255,0,4],{self:o.id});
 assert.deepEqual(casts[1].position,[2,3,4]);assert.equal(casts[1].location,1);assert.equal(casts[1].path,5);
});
test('script cast commandability and explicit class gates reject before queue mutation',async()=>{
 const {s,o,target,casts}=fixture();o.nativeFieldEc=0;await s.commands.ActionCastSpellAtObject([0,target.id],{self:o.id});assert.equal(casts.length,0);
 o.nativeFieldEc=1;await s.commands.ActionCastSpellAtObject([0,target.id,255,0,0,0,0,0,0],{self:o.id});assert.equal(casts.length,0);
 await s.commands.ActionCastFakeSpellAtObject([0,target.id,4],{self:o.id});assert.equal(casts.length,1);assert.equal(casts[0].cheat,1);assert.equal(casts[0].path,5);
});
