// Apply the three transmitted automap representations, never client-side
// visibility/DFS exploration. Coordinates and dimensions are native tile units.
export function applyNetworkAutomap(previous,change,width,height){
 const size=width*height;if(!Number.isInteger(size)||size<0||size>65536)throw new Error('Invalid native automap dimensions');
 const states=previous?.length===size?Uint8Array.from(previous):new Uint8Array(size);
 if(change.mode[1]){for(let i=0;i<size;i++)states[i]=((change.bytes[i>>>3]??0)>>>(i&7))&1;}
 else{if(change.mode[0])states.fill(change.points.length===0?1:0);for(const p of change.points){if(p.x<0||p.y<0||p.x>=width||p.y>=height)throw new Error('Native automap point exceeds area');states[p.y*width+p.x]=change.mode[0]?1:Number(p.state);}}
 return [...states];
}

