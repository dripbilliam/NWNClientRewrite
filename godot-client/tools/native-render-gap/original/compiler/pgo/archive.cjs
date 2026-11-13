'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function readNormalArchive(file){
 const bytes=fs.readFileSync(file);assert.equal(bytes.toString('ascii',0,8),'!<arch>\n','Expected private normal archive');let names=null;const members=[];
 for(let at=8;at<bytes.length;){assert(at+60<=bytes.length,'Truncated archive header');const h=bytes.toString('ascii',at,at+60);assert.equal(h.slice(58,60),'`\n');const size=Number(h.slice(48,58).trim());assert(Number.isSafeInteger(size)&&size>=0&&at+60+size<=bytes.length);const raw=h.slice(0,16).trim(),body=bytes.subarray(at+60,at+60+size);
  if(raw==='//')names=body;else if(raw!=='/'&&raw!=='/SYM64/'){let name=raw;if(/^\/\d+$/.test(raw)){assert(names,'Missing GNU long-name table');const offset=Number(raw.slice(1));assert(offset<names.length);let end=names.indexOf(Buffer.from('/\n'),offset);assert(end>=0);name=names.toString('utf8',offset,end);}else name=name.replace(/\/$/,'');assert(!name.startsWith('#1/'),'Unexpected BSD archive');members.push({name,bytes:size,sha256:hash(body)});}
  at+=60+size+(size&1);
 }
 return members;
}
function assertArchive(file,expectedPaths){const actual=readNormalArchive(file),expected=expectedPaths.map(p=>({name:path.basename(p),bytes:fs.statSync(p).size,sha256:hash(fs.readFileSync(p))}));assert.deepEqual(actual,expected,'Every ordered archive member/name/body must match, including duplicate dictionary basenames');return actual;}
module.exports={readNormalArchive,assertArchive};
