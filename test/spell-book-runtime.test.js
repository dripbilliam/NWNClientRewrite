import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {NwScriptVm} from '../src/nwscript_vm.js';
import {parse2da} from '../src/area.js';
import {createSpellClassState} from '../src/spell_book.js';
test('spell queries observe canonical live uses and preserve native preliminary VM results',async()=>{
  const s=new ModuleSession(null);s.characterRules={classes:parse2da('2DA V2.0\n\nSpellCaster PlayerClass MemorizesSpells SpellTableColumn SpellcastingAbil\n0 1 1 0 Custom INT'),
    spells:parse2da('2DA V2.0\n\nCustom Master Innate MetaMagic\n0 1 0 1 63')};
  const o=s.register('creature','c',{creatureData:{ClassList:[{Class:0,ClassLevel:3}]},stats:{equippedAbilities:{Int:20},equippedBonuses:{Int:0}}});
  o.nativeTalentClasses=[createSpellClassState()];o.nativeTalentClasses[0].perDay[1]=3;o.nativeStatsIsPCb0=0;
  assert.equal(s.commands.GetSpellUsesLeft([o.id,0,0]),3);assert.equal(s.commands.GetSpellUsesLeft([o.id,256,0]),0);
  assert.equal(s.commands.GetSpellLevelByClass([0,0]),1);
  assert.equal(s.spellBook.consume(o,0,0,0,0,255),1);assert.equal(s.commands.GetSpellUsesLeft([o.id,0,0]),2);
  assert.equal(s.commands.GetSpellUsesLeft([0x7f000000,0,0]),0);
  const api=[{name:'GetSpellLevelByClass',returns:'int',args:[{type:'int'},{type:'int'}]}];
  s.vm=new NwScriptVm({api,command:name=>s.commands[name]});
  const f={self:o.id,stack:[],program:{name:'native-query-stack'},pc:13};
  s.vm.push(f,'int',0);s.vm.push(f,'int',-256);
  await s.vm.step(f,{op:5,command:0,argc:2,pc:13});
  assert.deepEqual(f.stack,[{type:3,value:-1},{type:3,value:1}]);
});
