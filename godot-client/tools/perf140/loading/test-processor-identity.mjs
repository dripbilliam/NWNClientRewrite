import fs from 'node:fs';import path from 'node:path';
import {isolatedHeadless} from './isolated-headless.mjs';
const directory=process.argv[3]??'checks';if(!/^checks(?:-[a-z0-9-]+)?$/.test(directory))throw Error('Fresh checks label required');
await isolatedHeadless({label:process.argv[2],pattern:/^processor-identity-[a-z0-9-]+$/,directory,timeoutMs:20000,script:'native_perf140_loading_processor_identity_test.gd',argumentsForVariant:(variant,root)=>{const cache=path.join(root,'owned-prepared-cache');fs.mkdirSync(cache);return ['--expect-scoped='+(variant==='candidate'),'--cache-root='+cache];}});
