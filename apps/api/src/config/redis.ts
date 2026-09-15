import { EventEmitter } from "events";

const store = new Map<string, { value: string; expiresAt?: number }>();
export const pubsubEmitter = new EventEmitter();

function isExpired(entry?: { value: string; expiresAt?: number }): boolean {
  if (!entry) return true;
  if (entry.expiresAt && entry.expiresAt < Date.now()) return true;
  return false;
}

export class MockRedis extends EventEmitter {
  async ping(): Promise<string> {
    return "PONG";
  }

  async get(k: string): Promise<string | null> {
    const entry = store.get(k);
    if (!entry) return null;
    if (isExpired(entry)) {
      store.delete(k);
      return null;
    }
    return entry.value;
  }

  async set(k: string, v: string | number, ...args: any[]): Promise<string> {
    const strVal = String(v);
    let expiresAt: number | undefined;
    for (let i = 0; i < args.length; i++) {
      if (typeof args[i] === "string" && args[i].toUpperCase() === "EX" && args[i + 1]) {
        expiresAt = Date.now() + Number(args[i + 1]) * 1000;
        break;
      }
    }
    store.set(k, { value: strVal, expiresAt });
    return "OK";
  }

  async setex(k: string, seconds: number, v: string | number): Promise<string> {
    store.set(k, { value: String(v), expiresAt: Date.now() + seconds * 1000 });
    return "OK";
  }

  async del(...keys: string[]): Promise<number> {
    let count = 0;
    for (const k of keys) {
      if (store.delete(k)) count++;
    }
    return count;
  }

  async incr(k: string): Promise<number> {
    const entry = store.get(k);
    const curr = entry && !isExpired(entry) ? Number(entry.value) || 0 : 0;
    const next = curr + 1;
    store.set(k, { value: String(next), expiresAt: entry?.expiresAt });
    return next;
  }

  async decr(k: string): Promise<number> {
    const entry = store.get(k);
    const curr = entry && !isExpired(entry) ? Number(entry.value) || 0 : 0;
    const next = curr - 1;
    store.set(k, { value: String(next), expiresAt: entry?.expiresAt });
    return next;
  }

  async expire(k: string, seconds: number): Promise<number> {
    const entry = store.get(k);
    if (!entry || isExpired(entry)) return 0;
    entry.expiresAt = Date.now() + seconds * 1000;
    return 1;
  }

  async ttl(k: string): Promise<number> {
    const entry = store.get(k);
    if (!entry || isExpired(entry)) return -2;
    if (!entry.expiresAt) return -1;
    return Math.max(0, Math.floor((entry.expiresAt - Date.now()) / 1000));
  }

  async keys(pattern: string): Promise<string[]> {
    const results: string[] = [];
    for (const [k, entry] of store.entries()) {
      if (!isExpired(entry)) results.push(k);
    }
    return results;
  }

  async subscribe(...channels: string[]): Promise<number> {
    for (const ch of channels) {
      pubsubEmitter.on(ch, (message: string) => {
        this.emit("message", ch, message);
      });
    }
    return channels.length;
  }

  async publish(channel: string, message: string): Promise<number> {
    pubsubEmitter.emit(channel, message);
    return 1;
  }

  async quit(): Promise<string> {
    return "OK";
  }

  disconnect(): void {}
}

export const redis = new MockRedis() as any;
