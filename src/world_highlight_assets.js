import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {intEntry} from './combat_stats.js';
import {networkPortrait} from './network_portrait.js';
import {highlightDamageLevel} from './world_highlight.js';
const resources=new WeakMap();
function table(assets,name){let cache=resources.get(assets);if(!cache)resources.set(assets,cache=new Map());if(!cache.has(name))cache.set(name,assets.resolver.getResource(name,RESOURCE_TYPE.TWO_DA).then(b=>parse2da(decodeResourceText(b))));return cache.get(name);}
export async function highlightCreatureDetails(object,{assets,tables,resolve,portraitRow=object.replicated??{}}){
 if(!assets)return{};
 const level=highlightDamageLevel(object),condition=level===null?Promise.resolve(''):table(assets,'damagelevels').then(async t=>{const ref=intEntry(t,level,'STRING_REF');return ref.found&&ref.value!==-1?resolve({strRef:ref.value>>>0}):'';});
 const portrait=networkPortrait(assets,tables??{portraits:await table(assets,'portraits')},{id:object.id,...portraitRow},1);
 const [text,image]=await Promise.all([condition,portrait]);return{condition:text,portrait:image,level};
}
