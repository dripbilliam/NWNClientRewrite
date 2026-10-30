// Offline developer oracle only. No original model/texture/table payloads are
// retained: output is authored appearances, selected resource names and hashes.
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {parse2da} from '../../src/area.js';import {decodeGffText} from '../../src/gff_text.js';
import {itemIconPlan,selectItemIcon} from '../../src/item_icon.js';
import {decodeBioWarePlt,PLT_PALETTE_NAMES} from '../../src/bioware_plt.js';import {parseNativeTga} from '../../src/native_tga.js';
const install=path.resolve('../FullDecomp/NwnRootInstall'),resolver=await openServerResourceContext({install,module:path.join(install,'data/nwm/Prelude.nwm')}),hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const tables={};for(const name of ['baseitems','capart','parts_robe','cloakmodel','iprp_spells'])tables[name]=parse2da(decodeGffText(new Uint8Array(await resolver.getResource(name,2017))));
const palettes=new Map();for(const name of new Set(PLT_PALETTE_NAMES))palettes.set(name,parseNativeTga(await resolver.getResource(name,3)));palettes.set('pal_armor01',palettes.get('pal_armor02'));
const existsCache=new Map(),exists=async(name,type)=>{const key=name+':'+type;if(!existsCache.has(key))existsCache.set(key,resolver.getResource(name,type).then(()=>true,e=>{if(e.code&&e.code!=='RESOURCE_NOT_FOUND')throw e;return false;}));return existsCache.get(key);};
const cases=[];
for(const [base,row]of tables.baseitems.rows){
 if(![0,1,2,3].includes(Number(row.ModelType))||!(Number(row.InvSlotWidth)>0&&Number(row.InvSlotHeight)>0))continue;
 for(const gender of [0,1]){
  const parts=Array(19).fill(1);parts[18]=cases.length%4===0?5:0;
  const item={baseItem:base,parts,colors:[1,3,5,8,12,18],partColors:Array.from({length:19},(_,i)=>i===7?[2,255,9,255,4,255]:Array(6).fill(255)),properties:base===75?[{type:15,subtype:1}]:[]};
  let plan,selected,error=false;try{plan=itemIconPlan(item,tables,{gender});selected=await selectItemIcon(plan,exists);}catch{error=true;}
  const pixels=[];
  if(selected&&cases.length<100)for(const layer of selected.layers)if(layer.type===6){const image=decodeBioWarePlt(await resolver.getResource(layer.name,6),palettes,layer.palette);pixels.push({name:layer.name,sha256:hash(image.data),palette:layer.palette});}
  cases.push({item,gender,plan,selected,error,pixels});
 }
}
const sources={};for(const file of ['src/item_icon.js','src/item_model.js','src/inventory_layout.js','src/bioware_plt.js'])sources[file]=hash(await fs.readFile(file));
const output='godot-client/reports/native-item-icon-oracle-v1.json';await fs.writeFile(output,JSON.stringify({install,cases,sources,scope:'Offline original-table/resource selection oracle and palette pixel hashes; no JS runtime presentation input or original assets retained'},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({cases:cases.length,palettes:cases.flatMap(row=>row.pixels).length,output}));
