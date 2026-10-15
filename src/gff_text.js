// Explicit CP1252 avoids host ICU differences between Node and Chromium.
// Undefined CP1252 slots retain their control code, as the native byte strings do.
const high=[0x20ac,0x81,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x8d,0x17d,0x8f,0x90,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x9d,0x17e,0x178];
const characters=Array.from({length:256},(_,n)=>String.fromCodePoint(n>=128&&n<160?high[n-128]:n));
const bytesByCharacter=new Map(characters.map((c,n)=>[c,n]));
export function decodeGffText(bytes){let result='';for(let start=0;start<bytes.length;start+=8192)result+=Array.from(bytes.subarray(start,start+8192),n=>characters[n]).join('');return result;}
export function encodeGffText(value){return Uint8Array.from([...String(value)].map(c=>{const n=bytesByCharacter.get(c);if(n===undefined)throw new Error(`Character ${c} cannot be saved in a Western NWN character file`);return n;}));}
