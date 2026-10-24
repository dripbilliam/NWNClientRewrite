// Only the isolated Godot staging build uses this transform. Asset providers
// remain available, but decoded object effects have exactly one presentation
// owner: the native effect list, rather than hidden Three instances too.
export function isolateVisualDelivery(code){
 for(const [from,to]of [
  ['receiveVisualChanges(events){return this.visuals?.receive(events);}','receiveVisualChanges(_events){return Promise.resolve();}'],
  ['receiveObjectVisual(message){return this.visuals?.receiveInstant(message);}','receiveObjectVisual(_message){return Promise.resolve();}'],
  ['receiveAreaVisual(message){return this.areaVisuals?.receive(message);}','receiveAreaVisual(_message){return Promise.resolve();}'],
 ]){if(code.split(from).length!==2)throw Error('Visual presentation boundary changed');code=code.replace(from,to);}
 return code;
}
