import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
test('session floating text invokes the native recipient/message owner rather than the obsolete HUD-only override',async()=>{
 const calls=[],s=new ModuleSession({}),actor={objectType:5};s.registry.addInternalObject(actor);
 const client={object:actor};s.combat.broadcastProviders=()=>({client:id=>id===actor.id?client:null,send:(c,type,data)=>calls.push({c,type,data})});
 await s.commands.FloatingTextStringOnCreature(['text',actor.id,0,7]);assert.equal(calls.length,1);
 assert.equal(calls[0].c,client);assert.equal(calls[0].type,11);assert.equal(calls[0].data.integers[0],7);assert.equal(calls[0].data.integers[9],94);
 assert.deepEqual(calls[0].data.strings,['text']);assert.deepEqual(calls[0].data.objectIds,[actor.id]);
});
