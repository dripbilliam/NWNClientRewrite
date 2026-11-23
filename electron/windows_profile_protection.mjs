import { execFile } from 'node:child_process';
import { existsSync } from 'node:fs';

// The native profile helper uses current-user DPAPI. The private child pipe
// carries a single framed request. Its stdout is never inherited or logged.
export function windowsProfileProtection(executable) {
 const maximum = 65_536;
 const available = () => process.platform === 'win32' && existsSync(executable);
 function request(operation, payload) {
  if (!available() || payload.length < 1 || payload.length > maximum) {
   return Promise.reject(new Error('Windows profile protection is unavailable'));
  }
  return new Promise((resolve, reject) => {
   const frame = Buffer.alloc(5 + payload.length);
   frame.writeUInt32LE(payload.length);
   frame[4] = operation;
   frame.set(payload, 5);
   const child = execFile(executable, ['serve'], {
    encoding: 'buffer', maxBuffer: maximum + 5, timeout: 15_000, windowsHide: true,
   }, (failure, output) => {
    const length = output.length >= 5 ? output.readUInt32LE() : 0;
    if (failure || length < 1 || length > maximum || output[4] !== 0 || output.length !== length + 5) {
     output.fill(0);
     reject(new Error('Windows could not process this user’s protected profile'));
     return;
    }
    const result = Buffer.from(output.subarray(5));
    output.fill(0);
    resolve(result);
   });
   child.stdin.on('error', () => frame.fill(0));
   child.stdin.end(frame, () => frame.fill(0));
  });
 }
 return { available, protect: bytes => request(1, bytes), unprotect: bytes => request(2, bytes) };
}
