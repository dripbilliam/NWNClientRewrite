import test from 'node:test';import assert from 'node:assert/strict';
import {networkEffectIcons} from '../src/network_buff_bar.js';
import {applyPlayerState} from '../src/network_player_state_store.js';
test('server icon states zero and one are present; only explicit removal clears the aggregate icon',()=>{
 let state=applyPlayerState(null,{effectIcons:{removed:[],added:[{icon:257,state:0},{icon:1,state:1}]}});const actor={playerState:state},before=structuredClone(actor);assert.deepEqual(networkEffectIcons(actor),[{id:1,state:1},{id:257,state:0}]);assert.deepEqual(actor,before);
 state=applyPlayerState(state,{effectIcons:{removed:[],added:[{icon:257,state:1}]}});assert.equal(networkEffectIcons({playerState:state}).length,2);state=applyPlayerState(state,{effectIcons:{removed:[1],added:[]}});assert.deepEqual(networkEffectIcons({playerState:state}),[{id:257,state:1}]);
});
test('effect bar never synthesizes durations, duplicate cast stacks or icons for another creature',()=>{assert.deepEqual(networkEffectIcons({playerState:{effectIcons:{}}}),[]);assert.deepEqual(networkEffectIcons(null),[]);assert.deepEqual(networkEffectIcons({playerState:{effectIcons:{65535:0,65536:1,invalid:1}}}),[{id:65535,state:0}]);});
