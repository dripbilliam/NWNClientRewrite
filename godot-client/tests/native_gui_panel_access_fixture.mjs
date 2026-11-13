// Cross-language fixture made by the production canonical World/host helpers.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {NetworkWorld} from '../../src/network_world.js';
import {guiPanelEventForHost,guiPanelHeaderForHost} from '../../src/network_gui_panel_access.js';
const output=process.argv.find(v=>v.startsWith('--report='))?.slice(9);assert.ok(output);
const INVALID=0x7f000000,actor={id:0xffffffce,objectType:5,areaId:0x80000001},w=new NetworkWorld();
w.localObjectId=actor.id;w.areaId=actor.areaId;w.registry.addObjectAtPos(actor.id,actor);
let generation=1;const events=[];
const change=(panelId,disabled=true,targetId=INVALID)=>({kind:'gui-panel-disabled',panelId,disabled,targetId,targetSource:'received'});
function apply(m){w.apply(m);const e=guiPanelEventForHost(w,m,generation);events.push(e);return e;}
for(const id of [5,6,7,8])apply(change(id));
const seed=guiPanelHeaderForHost(w,generation);
apply({kind:'gui-panel-popup',panelId:6});apply({kind:'gui-panel-popup',panelId:6});apply(change(6));apply(change(6,false));
apply({kind:'gui-panel-popup',panelId:8});apply(change(8,true,0xffffffcd));apply(change(8,true,actor.id));
generation=2;w.areaId=0x80000002;w.registry.delete(actor.id);const replacement={id:0xffffffcc,objectType:5,areaId:w.areaId};w.localObjectId=replacement.id;w.registry.addObjectAtPos(replacement.id,replacement);
apply({kind:'gui-panel-popup',panelId:6});apply(change(6));const next=guiPanelHeaderForHost(w,generation);
apply({kind:'gui-panel-popup',panelId:6});w.registry.delete(replacement.id);w.registry.addObjectAtPos(replacement.id,{...replacement});const reused=guiPanelHeaderForHost(w,generation);
for(const id of [5,7]){apply({kind:'gui-panel-popup',panelId:id});apply({kind:'gui-panel-popup',panelId:id});apply(change(id,true,0xffffffcd));}
for(let count=0;count<80;count++)apply({kind:'gui-panel-popup',panelId:6});const flood=guiPanelHeaderForHost(w,generation);
await fs.writeFile(output,JSON.stringify({seed,events,next,reused,flood,actor,replacement},null,2)+'\n',{flag:'wx'});
