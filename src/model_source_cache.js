import {parseModel} from './model_parser.js';
import {inheritAnimations} from './mdl_animation.js';
import {RESOURCE_TYPE} from './resource_archive.js';
import {decodeResourceText} from './resource_archive.js';
import {parse2da} from './area.js';

// One active resource context owns these immutable model/animation sources.
// Actor palettes, nodes, transforms and animation clocks stay on instances.
export class ModelSourceCache{
 constructor(resolver,{parse=parseModel,parseTable=bytes=>parse2da(decodeResourceText(bytes)),persistent=false,preparedSources=null}={}){Object.assign(this,{resolver,parse,parseTable,persistent,preparedSources});this.models=new Map();this.parents=new Map();this.tables=new Map();this.closed=false;this.stats={parsed:0,hits:0,tablesParsed:0,tableHits:0,persistent:0,persistentFallbacks:0};this.cancelled=new Promise((_,reject)=>{this.cancel=reject;});void this.cancelled.catch(()=>{});}
 table(name){
  const key=name.toLowerCase();if(this.closed)return Promise.reject(Error('Model source cache is closed'));
  if(this.tables.has(key)){this.stats.tableHits++;return this.tables.get(key);}
  const work=Promise.resolve().then(async()=>{const bytes=await this.resolver.getResource(key,RESOURCE_TYPE.TWO_DA);if(this.closed)throw Error('Model source cache is closed');const table=await this.parseTable(bytes);if(this.closed)throw Error('Model source cache is closed');this.stats.tablesParsed++;return table;});
  this.tables.set(key,work);void work.catch(()=>{if(this.tables.get(key)===work)this.tables.delete(key);});return work;
 }
 load(name,ancestors=[]){
  const key=name.toLowerCase();if(this.closed)return Promise.reject(Error('Model source cache is closed'));
  if(ancestors.includes(key)||ancestors.length>=16)return Promise.reject(Error('MDL supermodel inheritance cycle.'));
  if(this.models.has(key)){this.stats.hits++;return this.models.get(key);}
  const work=(async()=>{let model;
   if(this.persistent&&this.resolver.getModelSource){
    try{const work=this.preparedSources?this.preparedSources.load(key,(...args)=>this.resolver.getModelSource(...args),{context:this.resolver.resourceContext??null}):this.resolver.getModelSource(key),result=await Promise.race([work,this.cancelled]);model=result?.model??result;this.stats.persistent++;for(const node of model.nodes??[])if(node.properties)Object.setPrototypeOf(node.properties,null);}
    catch(error){if(this.closed||error.code==='RESOURCE_NOT_FOUND')throw error;this.stats.persistentFallbacks++;}
   }
   if(!model){const bytes=await this.resolver.getResource(key,RESOURCE_TYPE.MDL);if(this.closed)throw Error('Model source cache is closed');model=await this.parse(bytes);this.stats.parsed++;}
   if(this.closed)throw Error('Model source cache is closed');
   this.parents.set(key,String(model.supermodel??'null').toLowerCase());
   const chain=new Set();let parent=key;
   while(parent&&parent!=='null'&&this.parents.has(parent)){if(chain.has(parent)||chain.size>=16)throw Error('MDL supermodel inheritance cycle.');chain.add(parent);parent=this.parents.get(parent);}
   await inheritAnimations(model,parent=>this.load(parent,[...ancestors,key]));if(this.closed)throw Error('Model source cache is closed');return model;})();
  this.models.set(key,work);void work.catch(()=>{if(this.models.get(key)===work){this.models.delete(key);this.parents.delete(key);}});return work;
 }
 paletteImages(load){
  if(this.closed)return Promise.reject(Error('Model source cache is closed'));
  if(!this.paletteWork)this.paletteWork=Promise.resolve().then(load).then(images=>{if(this.closed)throw Error('Model source cache is closed');return images;});
  return this.paletteWork;
 }
 dispose(){if(this.closed)return;this.closed=true;this.cancel(Error('Model source cache is closed'));this.models.clear();this.parents.clear();this.tables.clear();this.paletteWork=null;}
}
