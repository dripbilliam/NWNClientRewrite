import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';import {parseBinaryMdl} from '../../src/binary_mdl.js';
const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),models=[];
for(const name of ['plc_a08','pmh0_chest001','c_ydrowiz','pfa0_robe003']){
 const bytes=Buffer.from(await resolver.getResource(name,2002)),model=parseBinaryMdl(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));models.push({name,sha256:createHash('sha256').update(bytes).digest('hex'),nodes:model.nodes.map(node=>({name:node.name,area:node.nativeTriMeshArea??null,skin:node.skinned}))});
}
await fs.writeFile('godot-client/reports/native-ranged-area-oracle-v2.json',JSON.stringify({scope:'Installed original binary model metadata via independent retained reader; no original asset payload',models})+'\n',{flag:'wx'});console.log(JSON.stringify({models:models.map(model=>({name:model.name,parts:model.nodes.length,skins:model.nodes.filter(node=>node.skin).length}))}));
