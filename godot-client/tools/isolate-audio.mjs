// Native-only staging transform. The existing production main/audio classes
// remain untouched; hidden browser players must not duplicate native output.
export function isolateAudio(code){
 for(const[from,to]of[
  ['networkGuiAudio=new GameAudio(','networkGuiAudio=new SilentAudio('],
  ["void networkAmbientAudio?.attach(message.area,resolver);networkPlacedSounds?.attach(message.area);","/* Native ambient/placed audio owners remain tracked migration work. */"],
  ["onAudio:message=>{if(['voice-play','quick-chat'].includes(message.kind)){void networkPresentation?.voices?.receive(message);return;}return message.kind==='ambient-command'?networkAmbientAudio?.receive(message):message.kind==='sound-object'?networkPlacedSounds?.receive(message):networkScriptAudio?.receive(message);},","onAudio:_message=>{},"],
 ]){if(code.split(from).length!==2)throw Error('Native audio staging boundary changed');code=code.replace(from,to);}
 return code;
}
