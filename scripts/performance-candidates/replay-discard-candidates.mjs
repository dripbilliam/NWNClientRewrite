// Offline captured-room experiment only. No normal client imports or defaults.
import {RendererOpaqueAlpha} from '../../src/renderer_opaque_alpha.js';
export const replayDiscardModes=['opaque-alpha','keyhole-inactive','native-discard'];
export class ReplayDiscardCandidates{
 constructor(renderer,keyhole){this.renderer=renderer;this.keyhole=keyhole;this.alpha=new RendererOpaqueAlpha();this.inactive=false;}
 select(mode){this.alpha.enabled=mode==='opaque-alpha'||mode==='native-discard';this.inactive=mode==='keyhole-inactive'||mode==='native-discard';this.keyhole()?.setInactivePrograms(this.inactive);}
 prepare(scene){this.keyhole()?.setInactivePrograms(this.inactive);this.alpha.prepare(scene);}
 snapshot(){
  const owner=this.keyhole(),programs={inactive:0,active:0,ordinary:0,unprepared:0};
  for(const binding of owner?.bindings.values()??[])for(const state of binding.states){
   const program=this.renderer.properties.get(state.material).currentProgram;
   if(!program){programs.unprepared++;continue;}
   const key=program.cacheKey??'';
   if(key.includes('|can=0'))programs.inactive++;else if(key.includes('|can=1'))programs.active++;else programs.ordinary++;
  }
  return{opaqueAlpha:this.alpha.snapshot(),keyhole:owner?.snapshot()??null,programs};
 }
 dispose(){this.alpha.dispose();this.keyhole()?.setInactivePrograms(false);}
}
