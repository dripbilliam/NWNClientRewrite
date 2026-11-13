import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {decodeResourceText} from '../../src/resource_archive.js';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';
import {owned,scriptFloatingScript,SCRIPT_FLOATING_CASES} from '../tools/native-script-floating-server.mjs';
import {scriptFloatingServerReady} from '../tools/query-native-script-floating-server.mjs';
test('actual installed API signatures and parsed authored NCS contain four original script calls with exact echo/broadcast fields',async()=>{
 const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),bytes=scriptFloatingScript(api),script=parseNcs(bytes),instructions=[...script.instructions.values()],actions=instructions.filter(row=>row.op===5),byName=name=>api.find(row=>row.name===name);
 assert.equal(actions.filter(row=>row.command===byName('FloatingTextStrRefOnCreature').id&&row.argc===4).length,2);assert.equal(actions.filter(row=>row.command===byName('FloatingTextStringOnCreature').id&&row.argc===4).length,2);assert.equal(actions.filter(row=>row.command===byName('GetPCChatSpeaker').id).length,5);
 for(let index=0,found=0;index<instructions.length;index++)if(instructions[index].op===5&&[byName('FloatingTextStrRefOnCreature').id,byName('FloatingTextStringOnCreature').id].includes(instructions[index].command)){const row=SCRIPT_FLOATING_CASES[found++];assert.equal(byName(row.type===93?'FloatingTextStrRefOnCreature':'FloatingTextStringOnCreature').args[3].name,'bChatWindow');assert.equal(byName(row.type===93?'FloatingTextStrRefOnCreature':'FloatingTextStringOnCreature').args[2].name,'bBroadcastToFaction');assert.equal(instructions[index-4].value,row.showChat);assert.equal(instructions[index-3].value,row.broadcast);assert.equal(instructions[index-2].command,byName('GetPCChatSpeaker').id);assert.equal(instructions[index-1].value,row.type===93?row.strRef:row.text);}
});
test('fixture path and original server query admission never accept occupied/default/public/illegal or different module contracts',()=>{
 assert.throws(()=>owned('runtime-logs/local-multiplayer-server'));assert.throws(()=>owned('godot-client/.cache/script-floating-authority/native-script-floating-test/client'));
 const valid={type:'info',moduleName:'ScriptFloat1',playerCount:0,enforceLegalCharacters:1,maximumPlayers:1,allowLocalVaultCharacters:1};assert.equal(scriptFloatingServerReady(valid),true);
 for(const patch of [{moduleName:'Prelude'},{playerCount:1},{enforceLegalCharacters:0},{maximumPlayers:2},{allowLocalVaultCharacters:0}])assert.equal(scriptFloatingServerReady({...valid,...patch}),false);
});
