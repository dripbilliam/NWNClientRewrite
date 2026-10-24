import {resourceTaskReply} from './resource_worker_tasks.js';
const context={};
self.addEventListener('message',({data})=>{const reply=resourceTaskReply(data,context);self.postMessage(reply.message,reply.transfer);});
