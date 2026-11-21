import fs from 'node:fs';
import readline from 'node:readline';
const file=process.argv[2];
const counts={},samples={};
for await(const line of readline.createInterface({input:fs.createReadStream(file),crlfDelay:Infinity})){
  let r;try{r=JSON.parse(line);}catch{continue;}
  const code=r.code??r.type;counts[code]=(counts[code]??0)+1;
  if(!samples[code])samples[code]=[];
  if(samples[code].length<4)samples[code].push(r);
}
console.log(JSON.stringify({counts,samples},null,2));
