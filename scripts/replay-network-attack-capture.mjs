// Re-decode an owned native-server capture; no connection, rules execution or
// game-state mutation outside the isolated client proxy registry.
import fs from 'node:fs';
import path from 'node:path';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {openLocalModule} from './local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
const version=Number(process.argv[2]);if(!Number.isInteger(version)||version<1)throw new Error('Capture version required');
const report=JSON.parse(fs.readFileSync(`backups/animations/local-network-renderer-v${version}.json`)),install=path.resolve('../FullDecomp/NwnRootInstall'),res=installedNetworkResources({install});
const rules=await loadNetworkObjectRules(await openLocalModule(install,await res.findFile('nwm','Prelude','nwm'))),world=new NetworkWorld(),attacks=[],projectiles=[],unhandled=[],animations=new Map();let updates=0;
for(const [index,hex]of report.wireMessages.entries()){
 const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(message);
 if(message.kind==='safe-projectile')projectiles.push({message:index,...message.header});
 if(message.kind!=='object-updates')continue;
 if(!message.complete)unhandled.push({message:index,...message.unhandled});updates++;
 for(const record of message.records)if(record.objectType===5&&record.state?.animation!==undefined)animations.set(record.state.animation,(animations.get(record.state.animation)??0)+1);
 for(const event of world.presentationChanges)if(event.action==='attack-animation')attacks.push({message:index,...event});
}
const out=`backups/animations/network-attack-replay-v${version}.json`;
fs.writeFileSync(out,JSON.stringify({scope:'Replay of captured unmodified vanilla server replies; partial updates retain explicit unhandled diagnostics just as the live application does',updates,unhandled,projectiles,animations:[...animations],attacks,interactions:report.interactions,closed:report.states.at(-1)?.phase==='closed'},null,2)+'\n');
console.log(JSON.stringify({out,updates,unhandled,projectiles:projectiles.length,animations:[...animations],attackGroups:attacks.length,attackRecords:attacks.reduce((n,e)=>n+e.records.filter(r=>r.type===1).length,0),closed:report.states.at(-1)?.phase==='closed'}));
