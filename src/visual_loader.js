const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native visual loader provider ${name} is unavailable`);return p[name](...args);};
// LoadVisualEffect14096cf10..14096ed64. Resource loading, active tables and
// controller-map ownership are explicit boundaries. Table strings carry both
// found and value: failed queries can still write the table's default string.
// The caller owns construction of e; a failed target lookup leaves its other
// constructor fields intact. Native input-map consumption occurs on both exits.
function* loadVisualEffectSteps(e,args,p){
  e.visualF8=args.visual&65535;e.target54=args.target>>>0;e.source58=args.source>>>0;
  const finish=()=>call(p,'consumeControllers',args.controllers);
  const object=call(p,'clientObject',e.target54);
  const render=object?call(p,'renderObject',object):null;
  if(!render){finish();return 0;}
  const source=call(p,'clientObject',e.source58),sourceRender=source?call(p,'renderObject',source):null;
  const integer=column=>call(p,'visualInt',e.visualF8,column);
  const string=(row,column)=>call(p,'visualString',row,column);
  const value=(row,column)=>String(string(row,column).value);
  const orient=integer('OrientWithObject');e.orient120=orient.found&&(orient.value|0)!==0?1:0;
  function variants(name,column,isHead){
    if(!name.length)return name;
    if((call(p,'settings').quality64|0)===0){const low=string(e.visualF8,'LowQuality');if(low.found)name=String(low.value);}
    if((call(p,'settings').violence40&255)<2){
      const low=integer('LowViolence');
      if(low.found){const alternate=string(low.value|0,column);if(!isHead||alternate.found)name=String(alternate.value);}
    }
    return name;
  }
  const head=variants(value(e.visualF8,'Imp_HeadCon_Node'),'Imp_HeadCon_Node',true);
  const impact=variants(value(e.visualF8,'Imp_Impact_Node'),'Imp_Impact_Node',false);
  const creature=call(p,'creatureView58',render);let size=3,root='';
  if(creature){const entry=call(p,'appearanceInt',creature.appearanceCc&65535,'SIZECATEGORY');if(entry.found)size=entry.value|0;}
  function rootFor(row){
    if(size>=5)root=value(row,'Imp_Root_H_Node');
    if(size>=4&&!root.length)root=value(row,'Imp_Root_L_Node');
    if(size>=1&&!root.length)root=value(row,'Imp_Root_M_Node');
  }
  rootFor(e.visualF8);
  if(root.length){
    if((call(p,'settings').quality64|0)===0){const low=string(e.visualF8,'LowQuality');if(low.found)root=String(low.value);}
    if((call(p,'settings').violence40&255)<2){const low=integer('LowViolence');if(low.found)rootFor(low.value|0);}
  }
  let programs=[{found:false},{found:false},{found:false}];
  if(!root.length)programs=['ProgFX_Impact','ProgFX_Duration','ProgFX_Cessation'].map(integer);
  // This override exists in the original owner at14096de1a, including when a
  // root suppressed table-program queries. It is not a spell-script substitute.
  if(e.visualF8===999)programs[0]={found:true,value:1100};
  const sourceFirst=sourceRender?call(p,'prefixViewA0',sourceRender):null;
  const sourceSecond=sourceRender?call(p,'prefixView28',sourceRender):null;
  const sourcePart=args.sourcePart&255,targetPart=args.targetPart&255;
  const sourceSuffix=sourcePart===0?'_hand':sourcePart===1?'_impact':'_ground';
  e.sourceAnchor28=sourceFirst?String(sourceFirst.prefix1e0)+sourceSuffix:sourceSecond?String(sourceSecond.prefix1c8)+(sourcePart<2?'impc':'grnd'):sourcePart===0?'handconjure':sourcePart===1?'impact':sourcePart<=11?`monster${sourcePart-2}`:'root';
  const targetFirst=call(p,'prefixViewA0',render),targetSecond=call(p,'prefixView28',render);
  e.targetAnchor38=targetFirst?String(targetFirst.prefix1e0)+(targetPart<2?'_impact':'_ground'):targetSecond?String(targetSecond.prefix1c8)+(targetPart<2?'impc':'grnd'):targetPart<2?'impact':targetPart<=11?`monster${targetPart-2}`:'root';
  if(sourceRender){const model=call(p,'modelHandle',sourceRender,255,1);if(model&&!call(p,'findNode',model,e.sourceAnchor28))e.sourceAnchor28='root';}
  const targetModel=call(p,'modelHandle',render,255,1);if(targetModel&&!call(p,'findNode',targetModel,e.targetAnchor38))e.targetAnchor38='root';
  e.point48=args.point.map(Math.fround);
  e.programsD0=[65535,65535,65535];e.retiredDc=[1,1,1];e.durationFc=(args.instant|0)===0?1:0;
  for(let i=0;i<3;i++)if(programs[i].found&&(i===0||e.durationFc))e.programsD0[i]=programs[i].value&65535;
  const names=[root,impact,head],aliases=['fxground','fximpact','fxhead'],labels=['ground','impact','head'];
  for(let i=0;i<3;i++)if(names[i].length){
    // Yield only the resource boundary. Both runners retain all native
    // selection/state/callback order without replaying the loader after I/O.
    e.models88[i]=yield()=>call(p,'loadModel',names[i],aliases[i],0);
    if(e.models88[i]){e.retiredDc[i]=0;call(p,'modelSetting1a0',e.models88[i],3);}
    else call(p,'warning',574+15*i,`CNWCVisualEffectOnObject::LoadVisualEffect: Failed to load ${labels[i]} node visual.`);
  }
  e.programRemainingCc=e.programsD0[0]!==65535?1000:e.programsD0[1]!==65535?0:e.programsD0[2]!==65535?1000:0;
  e.closedEc=1;call(p,'copyControllers',e,args.controllers);finish();return 1;
}

export function loadVisualEffect(e,args,p){
 const steps=loadVisualEffectSteps(e,args,p);let step=steps.next();
 while(!step.done){const result=step.value();if(result&&typeof result.then==='function')throw new Error('Async visual model provider requires loadVisualEffectAsync');step=steps.next(result);}
 return step.value;
}
export async function loadVisualEffectAsync(e,args,p){
 const steps=loadVisualEffectSteps(e,args,p);let step=steps.next();
 while(!step.done)step=steps.next(await step.value());return step.value;
}
