import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const destination=path.join(project,'migration-inventory.json');
try{const old=JSON.parse(await fs.readFile(destination,'utf8'));if(old.modules.some(m=>m.nativeCounterpart!==null||!['pending feature audit','reused-by-local-bridge; complete feature parity unverified'].includes(m.status)))throw Error('Reviewed migration ledger preserved; update it manually rather than regenerating');}catch(error){if(error.code!=='ENOENT')throw error;}
const groups=[['multiplayer',/network_|server_browser|installed_network|network_ipc/],['nui',/nui_/],['content-and-rendering',/model|mdl|geometry|renderer|texture|particle|resource|material|light|shadow|walkmesh|tileset|palette|gff|archive|s3tc/],['combat-and-rules',/combat|spell|feat|effect|attack|damage|creature|saving_throw/],['gameplay-ui',/game_ui|radial|quickbar|character|inventory|automap|journal|dialog|highlight|target|mouse|camera|input|window/],['audio',/audio|sound|music|voice/],['settings-and-content',/settings|workshop|vault|capture|replay|debug/],['single-player',/module|script|scheduler|save|action|encounter|trigger|door|placeable|item|store|associate|game_object/]];
const reused=new Set(['electron/network_game_session.mjs','electron/installed_network_session.mjs','electron/network_peer.mjs','electron/network_ipc.cjs','electron/network_login_identity.mjs','electron/client_settings.mjs']);
const modules=[];
for(const folder of ['src','electron'])for(const file of (await fs.readdir(path.join(root,folder))).sort()){
 if(!/\.(js|mjs|cjs|css)$/.test(file))continue;
 const name=folder+'/'+file,bytes=await fs.readFile(path.join(root,name));
 modules.push({file:name,sha256:createHash('sha256').update(bytes).digest('hex'),group:groups.find(([,match])=>match.test(file))?.[0]??'needs-classification',status:reused.has(name)?'reused-by-local-bridge; complete feature parity unverified':'pending feature audit',nativeCounterpart:null});
}
const testFiles=(await fs.readdir(path.join(root,'test'))).filter(n=>/\.test\.(js|mjs|cjs)$/.test(n)).map(n=>'test/'+n).sort();
const output={version:1,scope:'Baseline source inventory for the Godot migration. Grouping is a review aid, not proof of coverage or feature completion.',modules,testFiles};
await fs.writeFile(destination,JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify({modules:modules.length,existingTestFiles:testFiles.length,needsClassification:modules.filter(m=>m.group==='needs-classification').length}));
