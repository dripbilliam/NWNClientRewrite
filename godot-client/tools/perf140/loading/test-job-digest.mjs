import fs from 'node:fs';import path from 'node:path';
import {isolatedHeadless} from './isolated-headless.mjs';
await isolatedHeadless({
 label:process.argv[2],pattern:/^job-digest-[a-z0-9-]+$/,
 script:'native_perf140_loading_job_digest_test.gd',
 argumentsForVariant:(variant,root)=>{const cache=path.join(root,'owned-prepared-cache');fs.mkdirSync(cache);return ['--expect-reuse='+(variant==='candidate'),'--prepared-cache-write=sync','--cache-root='+cache];}
});
