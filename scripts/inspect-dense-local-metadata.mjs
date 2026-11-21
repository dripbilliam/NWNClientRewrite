// Read-only metadata; never emit or save installed resource bodies.
import {openServerResourceContext} from '../electron/server_resource_context.mjs';
import {decodeResourceText} from '../src/resource_archive.js';
import {parse2da,parseTileset} from '../src/area.js';
import {fileURLToPath} from 'node:url';
const resolver=await openServerResourceContext({install:fileURLToPath(new URL('../../FullDecomp/NwnRootInstall/',import.meta.url))});
for(const name of ['placeables','appearance']){
 const table=parse2da(decodeResourceText(await resolver.getResource(name,2017)));
 console.log(name,JSON.stringify(table.orderedRows.map((row,i)=>({i,label:row.Label,model:row.ModelName,race:row.RACE})).filter(row=>/torch|brazier|human|golem|dragon|orc|chest/i.test(JSON.stringify(row))).slice(0,30)));
}
const set=parseTileset(decodeResourceText(await resolver.getResource('ttr01',2013)));
console.log('tiles',JSON.stringify(Object.entries(set.tiles).slice(0,3)));
const raw=decodeResourceText(await resolver.getResource('ttr01',2013));
console.log('flat grass tiles',[...raw.matchAll(/\[TILE(\d+)\]([\s\S]*?)(?=\[|$)/g)].filter(([,id,body])=>['TopLeft','TopRight','BottomLeft','BottomRight'].every(k=>new RegExp(`^${k}=Grass\\r?$`,'m').test(body)&&new RegExp(`^${k}Height=0\\r?$`,'m').test(body))).slice(0,10).map(([,id,body])=>({id,model:body.match(/^Model=(.*)/m)?.[1].trim()})));
