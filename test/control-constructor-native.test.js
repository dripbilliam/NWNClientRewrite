import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-control-constructor-observations-v3.json',import.meta.url)));
const names={134:'EffectKnockdown',148:'EffectParalyze',154:'EffectSleep',156:'EffectCharmed',157:'EffectConfused',158:'EffectFrightened',159:'EffectDominated',160:'EffectDazed',161:'EffectStunned',252:'EffectSilence',270:'EffectHaste',271:'EffectSlow',767:'EffectCutsceneImmobilize'};
test('live zero-argument control constructors use native effect IDs, subtypes and integer defaults',()=>{
  const s=new ModuleSession(null),actor=s.register('creature','creator',{});
  for(const row of oracle.rows){const e=s.commands[names[row.ordinal]]([],{self:actor.id});assert.deepEqual({type:e.type,subtype:e.subtype,integers:e.integers,creatorId:99},row.output);}
});
