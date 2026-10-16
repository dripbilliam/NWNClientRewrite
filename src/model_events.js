const f=Math.fround;
// Complete AnimateEvents14004fce0..14004fe88. Physical event order is kept;
// forward intervals are (from,to], reverse intervals [to,from). Wrapping
// splits at the native +/-1e9 sentinels, not at an invented clip length.
export function animateModelEvents(clip,from,to,flags,emit){
  from=f(from);to=f(to);flags|=0;
  if(flags&2){from=-1e9;to=1e9;flags&=~2;}
  if(flags&1){if(to>from){animateModelEvents(clip,from,-1e9,flags,emit);from=1e9;}}
  else if(from>to){animateModelEvents(clip,from,1e9,flags,emit);from=-1e9;}
  const events=clip.events??[];
  if(flags&1){for(let i=events.length-1;i>=0;i--){const event=events[i],time=f(event.time);if(time>=to&&from>time)emit(event.name,null,i);}}
  else for(let i=0;i<events.length;i++){const event=events[i],time=f(event.time);if(to>=time&&time>from)emit(event.name,null,i);}
}
const asciiLower=value=>{
  value=String(value);if(/[^\x00-\x7f]/.test(value))throw new Error('Native model event locale comparison is unavailable');
  return value.replace(/[A-Z]/g,c=>c.toLowerCase());
};
// Gob::DoEvent140050d50..140050eaf: reverse registration order, leading
// '*' or empty wildcard, case-insensitive names, explicit data overriding
// listener userdata, and destruction invalidating active dispatch handles.
// JS owns backing storage; preserve native capacities and swap-remove order.
export class ModelEventDispatcher{
  constructor(owner){this.owner=owner;this.listeners=[];this.handles=[];this.capacity=0;}
  add(pattern,callback,data=null){const record={pattern:String(pattern),callback,data};this.listeners.push(record);return record;}
  accepts(name){return this.listeners.some(listener=>listener.pattern===''||listener.pattern[0]==='*'||asciiLower(listener.pattern)===asciiLower(name));}
  dispatch(name,data=null){
    let index=this.listeners.length-1;
    if(this.handles.length===this.capacity)this.capacity=this.capacity===0?16:Math.imul(this.capacity,2);
    const frame={owner:this.owner,index:this.handles.length};this.handles.push(frame);let delivered=0;
    while(frame.owner&&index>=0){
      const listener=this.listeners[index--];if(!listener)throw new Error('Native model listener removal during dispatch is unavailable');
      if(listener.pattern===''||listener.pattern[0]==='*'||asciiLower(listener.pattern)===asciiLower(name)){
        listener.callback(frame.owner,name,data??listener.data);delivered++;
      }
    }
    if(frame.owner&&frame.index>=0&&frame.index<this.handles.length){
      this.handles[frame.index]=this.handles.at(-1);this.handles.pop();
      if(frame.index<this.handles.length)this.handles[frame.index].index=frame.index;
    }
    return delivered;
  }
  destroy(){for(const frame of this.handles)frame.owner=null;this.handles=[];this.owner=null;}
}
