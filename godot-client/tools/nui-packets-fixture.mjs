// Authored Unicode/control text only; never copies installed assets or server data.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {nuiFixture} from './nui-fixture.mjs';import {NUI_FRAME_BYTES} from './nui-packets.mjs';
const args=Object.fromEntries(process.argv.slice(2).map(a=>a.replace(/^--/,'').split('='))),hash=s=>createHash('sha256').update(s).digest('hex');
const text='é💎\\ "'.repeat(140000),input='é💎\\\n"'.repeat(120000),layout={title:'Authored large NUI',geometry:{x:20,y:20,w:800,h:130},root:{type:'col',children:[{type:'label',id:'long',value:text,height:30},{type:'textedit',id:'edit',value:{bind:'large'},max:1000000,height:40}]}};
if(args.presentation==='tooltip'){layout.root.children[0].tooltip=text;layout.root.children[0].value='Authored large tooltip';}
const f=nuiFixture({count:0,layout});await f.service.sync();
if(args.mode==='build'){
 assert.ok(f.sent.some(m=>m.kind==='nui-json-begin'));assert.ok(f.sent.every(m=>Buffer.byteLength(JSON.stringify(m))<NUI_FRAME_BYTES));
 await fs.writeFile(args.fixture,JSON.stringify({messages:f.sent,tooltip:args.presentation==='tooltip',textSha256:hash(text),input,inputSha256:hash(input)}),{flag:'wx'});
 console.log(JSON.stringify({fixture:args.fixture,textBytes:Buffer.byteLength(text),inputBytes:Buffer.byteLength(JSON.stringify(input)),messages:f.sent.length}));
}else if(args.mode==='verify'){
 const packets=JSON.parse(await fs.readFile(args.input,'utf8'));assert.ok(packets.length>3);assert.ok(packets.every(m=>Buffer.byteLength(JSON.stringify(m))<NUI_FRAME_BYTES));
 for(const packet of packets)await f.service.command(packet);
 assert.equal(f.calls.length,1);assert.equal(f.calls[0].binds[0].value,input);assert.equal(f.world.nui.windows.get(11).bindings.get('large'),input);
 const result={passed:true,scope:'Godot native encoded input accepted by actual service private-handle validation and canonical binding, authored transport only',packets:packets.length,inputSha256:hash(f.world.nui.windows.get(11).bindings.get('large')),inputCharacters:input.length};
 await fs.writeFile(args.report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
}else throw Error('Use --mode=build or verify');
await f.service.retire();
