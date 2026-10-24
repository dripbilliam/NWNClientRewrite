import {parseModel} from './model_parser.js';
import {parseNativeTga} from './native_tga.js';
import {decodeBioWarePlt} from './bioware_plt.js';
import {parse2da} from './area.js';
import {decodeResourceText} from './resource_archive.js';
import {buildParticleVertexBatch} from './particle_vertex_batch.js';

// Pure CPU work only. Workers never own a connection, resolver, actor, WebGL
// object or mutable palette texture. Archive reads remain asynchronous IPC.
export function executeResourceTask(kind,payload){
 switch(kind){
  case 'model':return parseModel(payload.buffer);
  case 'tga':return parseNativeTga(payload.buffer);
  case 'plt':return decodeBioWarePlt(payload.buffer,payload.palettes,payload.rows);
  case '2da':return parse2da(decodeResourceText(payload.buffer));
  case 'particle-vertices':return buildParticleVertexBatch(payload);
  default:throw Error(`Unknown resource worker task: ${kind}`);
 }
}

export function resourceTaskReply({id,kind,payload},context=null){
 const started=performance.now();
 try{
  if(kind==='plt'&&payload.paletteId!==undefined){
   if(!context)throw Error('Resident PLT palette context is unavailable');
   if(payload.paletteImages){context.paletteId=payload.paletteId;context.palettes=payload.paletteImages;}
   if(context.paletteId!==payload.paletteId||!context.palettes)throw Error('Resident PLT palette context is stale');
   payload={...payload,palettes:context.palettes};
  }
  const result=executeResourceTask(kind,payload),transfer=kind==='particle-vertices'?result.flatMap(frame=>frame.out?[frame.out.buffer]:[]):result.data?.buffer?[result.data.buffer]:[];return{message:{id,result,cpuMs:performance.now()-started},transfer};}
 catch(error){return{message:{id,error:{message:error.message,name:error.name},cpuMs:performance.now()-started},transfer:[]};}
}
