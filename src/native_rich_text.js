import {scriptStringBytes} from './script_string.js';

// Byte controls have a fixed width: an RGB component can itself be '<' or
// '>'. They must be recognized before searching for a talk-token delimiter.
export function nativeColorControlLength(bytes,at){
 if(bytes[at]!==60)return 0;
 if(bytes[at+1]===47&&bytes[at+2]===99&&bytes[at+3]===62)return 4;
 return bytes[at+1]===99&&bytes[at+5]===62?6:0;
}

// The native log carries byte RGB controls, not HTML. Color closes restore
// the enclosing message color, including colored names inside spell text.
export function nativeRichText(raw){
 const spans=[],colors=[];let text='';
 const flush=()=>{if(text){spans.push({text,color:colors.at(-1)??null});text='';}};
 for(let at=0;at<raw.length;){
  if(raw.startsWith('</c>',at)){flush();colors.pop();at+=4;continue;}
  if(raw.startsWith('<c',at)&&raw[at+5]==='>'){
   let rgb;try{rgb=scriptStringBytes(raw.slice(at+2,at+5));}catch{}
   if(rgb?.length===3){flush();colors.push('#'+[...rgb].map(n=>n.toString(16).padStart(2,'0')).join(''));at+=6;continue;}
  }
  text+=raw[at++];
 }
 flush();return{spans,text:spans.map(s=>s.text).join('')};
}

// Only literal text nodes and numeric RGB styles enter the DOM, never server
// HTML. Reusable by descriptions, dialogue replies and speaker names.
export function setNativeRichText(node,raw){
 const rich=nativeRichText(raw);node.replaceChildren(...rich.spans.map(part=>{const span=node.ownerDocument.createElement('span');span.textContent=part.text;if(part.color)span.style.color=part.color;return span;}));return rich;
}
