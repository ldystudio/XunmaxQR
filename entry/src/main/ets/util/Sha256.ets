import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

export function sha256Hex(input: string): string {
  try {
    const encoder = util.TextEncoder.create('utf-8');
    const md = cryptoFramework.createMd('SHA256');
    md.updateSync({ data: encoder.encodeInto(input) });
    return bytesToHex(md.digestSync().data);
  } catch (_) {
    return '';
  }
}

function bytesToHex(bytes: Uint8Array): string {
  let result = '';
  for (let index = 0; index < bytes.length; index++) {
    const value = bytes[index].toString(16);
    result += value.length === 1 ? `0${value}` : value;
  }
  return result;
}
