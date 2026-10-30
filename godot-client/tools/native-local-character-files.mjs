import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
// Raw filesystem identity/integrity only. Godot decodes BIC and active 2DAs.
export async function localCharacterFile(file){
 let bytes;
 try{bytes=await fs.readFile(file);return{format:'native-local-bic-v1',path:file,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};}
 catch{return{format:'native-local-bic-v1',path:file,error:'Local character byte source is unavailable'};}
 finally{bytes?.fill(0);}
}
