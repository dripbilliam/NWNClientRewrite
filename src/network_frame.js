// Native client6db800 calls input6f14e0/6f1e40 before AI767d50. Sample
// held-input pose before advancing this frame's local presentation movement.
// Async preview completion retains its existing owner/fresh-pose guards.
export function updateNetworkFrame(keyboard,presentation,delta){
 keyboard.update();
 presentation?.update(delta);
}
