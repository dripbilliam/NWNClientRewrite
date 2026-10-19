const call=(p,n,...args)=>{if(typeof p[n]!=='function')throw new Error(`Native item copy provider ${n} is unavailable`);return p[n](...args);};
export const copiedItemScalars=Object.freeze([0x394,0x388,0x35c,0x444,0x454,0x45c,0x360,0x144,0x458,0x468,0x40]);
// Complete CNWSItem::CopyItem140466910..140466e60. Selective native copies;
// destination identity, position, prices, droppable/cursed flags and UUID are
// never taken from a blanket authored-record clone.
export async function copyNativeItem(destination,source,copyVariables,p){
 if(!source)return 0;
 const repo=call(p,'repository',source);if(repo&&call(p,'repositoryCount',repo)!==0)return 0;
 for(const offset of[0x3e0,0x3f0,0x420])call(p,'localized',destination,offset,call(p,'localized',source,offset));
 for(const offset of[0x430,0x400,0x410])call(p,'string',destination,offset,call(p,'string',source,offset));
 const oldTag=call(p,'string',destination,0x68);if(oldTag.length!==0)await call(p,'removeTag',destination,oldTag);
 call(p,'string',destination,0x68,call(p,'string',source,0x68));await call(p,'addTag',destination,call(p,'string',destination,0x68));
 call(p,'scalar',destination,0x3c8,call(p,'scalar',source,0x3c8));
 if(repo)call(p,'constructRepository',destination,repo);
 if((copyVariables|0)!==0)await call(p,'copyVariables',destination,source);
 for(const [kind,count]of[['armorParts',19],['modelParts',3]])for(let i=0;i<count;i++)call(p,'appearance',destination,kind,i,call(p,'appearance',source,kind,i));
 for(const active of[true,false])if(call(p,'properties',source,active).length>0)call(p,'assignProperties',destination,call(p,'properties',source,active),active);
 const effects=call(p,'effects',source),targetEffects=call(p,'effects',destination);
 if(effects===targetEffects&&effects.length)throw new Error('Native self-copy of live item effects grows its source traversal indefinitely');
 for(let i=0;i<effects.length;i++)targetEffects.push(call(p,'copyEffectFresh',effects[i]));
 for(const offset of copiedItemScalars.slice(0,7))call(p,'scalar',destination,offset,call(p,'scalar',source,offset));
 for(let i=0;i<9;i++)call(p,'byte',destination,0x350+i,call(p,'byte',source,0x350+i));
 call(p,'scalar',destination,0x144,call(p,'scalar',source,0x144));
 call(p,'string',destination,0x78,call(p,'string',source,0x78));
 for(const offset of[0x458,0x468,0x40])call(p,'scalar',destination,offset,call(p,'scalar',source,offset));
 for(let i=0;i<6;i++)call(p,'appearance',destination,'colors',i,call(p,'appearance',source,'colors',i));
 for(let channel=0;channel<6;channel++)if(call(p,'hasPartColors',source,channel))for(let part=0;part<19;part++)call(p,'setPartColor',destination,channel,part,call(p,'getPartColor',source,channel,part));
 await call(p,'updateVisual',destination);return 1;
}
