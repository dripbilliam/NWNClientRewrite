// Buffers and typed arrays can cross main-process/tool VM realms. instanceof
// rejects those legitimate byte views; retain a strict Uint8Array/Buffer shape.
export const isNetworkBytes=value=>ArrayBuffer.isView(value)&&value.BYTES_PER_ELEMENT===1&&Object.prototype.toString.call(value)==='[object Uint8Array]';
