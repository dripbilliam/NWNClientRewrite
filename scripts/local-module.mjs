// Read-only adapters for exercising the browser resource resolver against local assets.
import fs from 'node:fs/promises';
import path from 'node:path';
import { ResourceResolver } from '../src/resource_archive.js';

export async function openLocalModule(installPath, modulePath, hakPath = null) {
  const install = path.resolve(installPath);
  const localFile = filename => ({
    name: path.basename(filename),
    webkitRelativePath: path.relative(install, filename),
    async arrayBuffer() {
      const bytes = await fs.readFile(filename);
      return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    }
  });
  const data = path.join(install, 'data');
  const gameFiles = (await fs.readdir(data, { withFileTypes: true }))
    .filter(entry => entry.isFile()).map(entry => localFile(path.join(data, entry.name)));
  const hakDirectories = [...new Set([path.join(data, 'hk'), ...(hakPath ? [path.resolve(hakPath)] : [])])];
  const hakFiles = [];
  for (const directory of hakDirectories) {
    let entries;
    try { entries = await fs.readdir(directory, { withFileTypes: true }); }
    catch (error) { if (error.code === 'ENOENT') continue; throw error; }
    hakFiles.push(...entries.filter(entry => entry.isFile() && /\.hak$/i.test(entry.name))
      .map(entry => localFile(path.join(directory, entry.name))));
  }
  return ResourceResolver.create(localFile(path.resolve(modulePath)), gameFiles, hakFiles);
}
