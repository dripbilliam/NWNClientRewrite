import fs from 'node:fs/promises';
import {openServerResourceContext} from '../electron/server_resource_context.mjs';
import {parseGff} from '../src/gff.js';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
const resolver=await openServerResourceContext({install:process.argv[2]}),result={};
for(const name of ['pre_main','pre_multiplayer','pre_loadmod','pre_loadmodm','pre_chartype','serverlist_panel','serverlist_page1','server_connect','cg_main','cg_char_info']){
 const root=parseGff(await resolver.getResource(name,RESOURCE_TYPE.GUI)).root,records=[];
 const walk=(r,parent)=>{records.push({tag:r.Obj_Tag,parent,type:r.Obj_Type,model:r.Obj_ResRef,x:r.Obj_X,y:r.Obj_Y,label:r.Obj_Label,width:r.Obj_Label_Width,height:r.Obj_Label_Height});for(const child of r.Obj_ChildList??[])walk(child,r.Obj_Tag);};walk(root,null);result[name]=records;
}
for(const key of resolver.key.resources.keys())if(key.endsWith(':'+RESOURCE_TYPE.GUI)){const name=key.split(':')[0];if(result[name])continue;const root=parseGff(await resolver.getResource(name,RESOURCE_TYPE.GUI)).root;const all=[],walk=(r,parent)=>{all.push({tag:r.Obj_Tag,parent,type:r.Obj_Type,model:r.Obj_ResRef,x:r.Obj_X,y:r.Obj_Y});for(const c of r.Obj_ChildList??[])walk(c,r.Obj_Tag);};walk(root,null);if(all.some(r=>/char.*list|charload|chr_load|loadchr/i.test(r.tag??'')||/pnl_chr_load/i.test(r.model??'')))result[name]=all;}
await fs.writeFile('backups/animations/server-vault-ui-layouts-v1.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));
