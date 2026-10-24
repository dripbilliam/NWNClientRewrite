const f=Math.fround;
// CGuiInGameFloatyText972750/972840: original lifetime/fade/world rise and
// truncation-to-int screen rounding. p delegates actual model/camera/UI owners.
export function createFloatingTextState(event){return{...event,duration:f(1.5),remaining:f(1.5),rgb:[...event.rgb],shadow:event.flags!==0};}
export function updateFloatingText(state,delta,p){
 delta=f(delta);if(!Number.isFinite(delta)||delta<0)throw new Error('Native floating-text frame delta is invalid');
 if(!(delta<state.remaining)){p.destroy();return false;}
 const object=p.object(state.objectId),model=object&&p.model(object),world=model&&p.world();
 if(world){
  const position=p.position(model),height=f(f(f(state.duration-state.remaining)*f(.5))+f(2)),point=p.project(world,[position[0],position[1],f(height+position[2])]);
  const alpha=state.remaining>=.5?1:f(state.remaining+state.remaining);p.color('foreground',...state.rgb,alpha);if(state.shadow)p.color('background',0,0,0,alpha);
  p.screen([Math.trunc(f(point[0]+f(.5))),Math.trunc(f(point[1]+f(.5))),f(-5.1)]);
 }
 state.remaining=f(state.remaining-delta);return true;
}
