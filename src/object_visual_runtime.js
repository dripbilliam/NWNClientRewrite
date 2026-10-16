import {objectVisualDataGffProviders,loadObjectShaderParams,loadObjectReplacements,loadObjectMiscVisuals} from './object_visual_data.js';
import {visualTransformClockProviders,loadVisualTransform,loadObjectVisualTransforms,assignVisualTransforms} from './object_visual_transform.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
const owners=[0x140497bb0,0x140496ea0,0x140497990,0x1404969c0,0x1404972b0];
const clone=map=>new Map([...map].sort((a,b)=>a[0]-b[0]).map(([key,value])=>[key,value.slice()]));

// Concrete serialized visual-data owners. This bridge does not evaluate/draw
// scoped transforms or shader/texture/bubble overrides; retained diagnostics
// identify those remaining presentation owners when such data is encountered.
export class ObjectVisualRuntime{
 constructor(session){this.session=session;}
 providers(object){
  const s=this.session,scratch=new Uint8Array(64),p={...objectVisualDataGffProviders(),...visualTransformClockProviders(s.worldTimer,()=>s.worldTimer.microseconds()),
   constructMap:()=>new Map(),clearMap:map=>map.clear(),copyMap:(dst,src)=>{for(const[key,value]of clone(src))dst.set(key,value);},releaseMap:map=>map.clear(),
   asItem:o=>o.objectType===6?o:null,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
   equipmentSlot:(creature,item)=>{if(!creature.nativeEquipment)throw new Error('Native visual-transform equipment owner is unavailable');return creature.nativeEquipment.slot(item);},
   copyHand:(creature,offset,map)=>{const dst=creature.nativeHandVisualMaps?.[offset];if(!dst)throw new Error('Native equipped-hand visual-transform storage is unavailable');if(dst===map)return;const owned=clone(map);dst.clear();for(const[key,value]of owned)dst.set(key,value);},
   assertFailure:(method,line,expression)=>runtimeDiagnostics.record('object.visual-data-assertion',expression,{...s.diagnosticContext(object.id),method,line},'error'),
  };
  p.loadTransform=(bytes,data)=>loadVisualTransform(bytes,data,p,scratch);
  p.assignTransforms=(o,map)=>assignVisualTransforms(o,map,p);return p;
 }
 missing(object,owner,feature){runtimeDiagnostics.record('object.visual-presentation-unimplemented',`Native ${feature} presentation is unavailable`,{...this.session.diagnosticContext(object.id),owner});}
 async loadOwner(object,data,owner){
  const s=this.session,context={...s.diagnosticContext(object.id),owner,operation:'native-object-visual-data-load'};
  try{
   if(s.registry.get(object.id)!==object||!object.nativeVisualPools||!object.nativeMiscVisualFields)throw new Error('Native canonical visual-data owner is unavailable');
   const p=this.providers(object);
   if(owner===0x140497bb0){await loadObjectVisualTransforms(object,data,p);if(object.nativeVisualTransforms2b0?.size)this.missing(object,owner,'scoped visual-transform sampling');}
   else if(owner===0x140496ea0){await loadObjectShaderParams(object,data,p);if(object.nativeVisualPools[0x2b8].records.length)this.missing(object,owner,'shader-parameter');}
   else if(owner===0x140497990){await loadObjectReplacements('texture',object,data,p);if(object.nativeVisualPools[0x2c8].records.length)this.missing(object,owner,'texture replacement');}
   else if(owner===0x1404969c0){
    const previous=object.nativeVisualPools[0x2d8];await loadObjectReplacements('animation',object,data,p);
    if(object.nativeVisualPools[0x2d8]!==previous)object.nativeAnimationOverridesLoaded=1;
    if(object.objectType!==5&&object.nativeVisualPools[0x2d8].records.length)this.missing(object,owner,'non-creature animation replacement');
   }else if(owner===0x1404972b0){
    await loadObjectMiscVisuals(object,data,p);const fields=object.nativeMiscVisualFields;
    if([[0x254,-1],[0x258,-1],[0x25c,-1],[0x260,-1],[0x268,45],[0x26c,15],[0x270,0],[0x278,'']].some(([key,value])=>fields[key]!==value))this.missing(object,owner,'custom cursor/highlight/distance/bubble');
   }else throw new Error(`Native visual data owner ${owner} is unavailable`);
  }catch(error){s.report(error,context);throw error;}
 }
 async load(object,data){for(const owner of owners)await this.loadOwner(object,data,owner);}
}
