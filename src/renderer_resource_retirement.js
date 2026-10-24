// Keep the outgoing area's GPU program owners alive while the incoming area
// compiles matching programs. Logical objects detach immediately; these delayed
// callbacks only dispose renderer materials, geometry, textures and templates.
export class RendererResourceRetirement{
 constructor({report=()=>{}}={}){this.report=report;this.holds=0;this.pending=[];}
 begin(){this.holds++;let ended=false;return()=>{if(ended)return;ended=true;if(--this.holds===0)this.flush();};}
 retire(dispose){if(this.holds)this.pending.push(dispose);else dispose();}
 flush(){const pending=this.pending.splice(0);for(const dispose of pending)try{dispose();}catch(error){this.report('renderer.retirement-failed',error.message);}}
}
