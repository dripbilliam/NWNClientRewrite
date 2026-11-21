import {parentPort} from 'node:worker_threads';
import {serialize} from 'node:v8';
import {parseModel} from '../src/model_parser.js';
import {prepareModelGeometry} from '../src/prepared_model_geometry.js';

parentPort.on('message',({id,buffer,schema,sourceHash})=>{
 const started=performance.now();
 try{
  const model=parseModel(buffer),geometry=prepareModelGeometry(model);
  const encoded=serialize({schema,sourceHash,model}),output=Uint8Array.from(encoded);
  parentPort.postMessage({id,buffer:output.buffer,stats:{...geometry,cpuMs:performance.now()-started}},[output.buffer]);
 }catch(error){parentPort.postMessage({id,error:error.message});}
});
