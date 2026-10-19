// Re-read captured owned vanilla-server updates after adding the native G/Q
// owner. Keep the earlier historical replays unchanged, including their errors.
import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
const version=Number(process.argv[2]);if(!Number.isInteger(version))throw new Error('Capture version required');
const capture=JSON.parse(await fs.readFile(`backups/animations/local-network-renderer-v${version}.json`)),rules=await loadNetworkObjectRules(await openLocalModule('../FullDecomp/NwnRootInstall','../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm')),world=new NetworkWorld(),uses=[],unhandled=[],unknown=new Map();let updates=0;
for(const [index,hex]of capture.wireMessages.entries()){
 const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(message);
 if(message.kind==='unsupported'){const key=message.major+'/'+message.minor;unknown.set(key,(unknown.get(key)??0)+1);}
 if(message.kind!=='object-updates')continue;updates++;if(!message.complete)unhandled.push({message:index,...message.unhandled});
 for(const record of message.records)if(record.action==='item-use-counts')uses.push({message:index,...record});
}
const result={scope:'Read-only replay of real vanilla replies after implementing G/Q and quickbar messages, with missing owners explicitly retained',updates,uses,unhandled,unsupported:[...unknown],quickbar:world.quickbar,items:[...world.registry.objects.values()].filter(o=>o.objectType===6).map(o=>({id:o.id,item:o.item,areaId:o.areaId,inventoryLocation:o.inventoryLocation})),world:world.snapshot()};await fs.writeFile(`backups/animations/network-item-use-replay-v${version}.json`,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({updates,records:uses.length,entries:uses.reduce((n,v)=>n+v.entries.length,0),unhandled,unsupported:[...unknown],quickbar:world.quickbar.map((b,index)=>({index,...b})).filter(b=>b.type!==0)}));
