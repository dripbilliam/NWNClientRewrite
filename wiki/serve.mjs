import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const output = fileURLToPath(new URL('./_site/', import.meta.url));
const port = Number(process.env.WIKI_PORT || 4174);
const base = (process.env.WIKI_BASE || '').replace(/\/$/, '');
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8', '.md': 'text/plain; charset=utf-8' };
await fs.access(path.join(output, 'index.html'));
const server = http.createServer(async (request, response) => {
  try {
    let pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    if (base && !pathname.startsWith(base + '/') && pathname !== base) throw new Error('Outside base');
    pathname = pathname.slice(base.length);
    const file = path.resolve(output, '.' + (pathname.endsWith('/') ? pathname + 'index.html' : pathname || '/index.html'));
    if (!file.startsWith(output) || !(await fs.stat(file)).isFile()) throw new Error('Not found');
    response.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
    response.end(await fs.readFile(file));
  } catch { response.writeHead(404, { 'Content-Type': 'text/plain' }); response.end('Not found'); }
});
server.listen(port, '127.0.0.1', () => console.log(`Wiki preview: http://127.0.0.1:${port}${base}/`));
