import {parentPort} from 'node:worker_threads';
import {resourceTaskReply} from '../src/resource_worker_tasks.js';
const context={};
parentPort.on('message',message=>{const reply=resourceTaskReply(message,context);parentPort.postMessage(reply.message,reply.transfer);});
