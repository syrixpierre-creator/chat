import { PrismaClient } from "@prisma/client";
import crypto from "crypto";

interface UserRecord {
  id: string;
  username: string;
  email: string;
  passwordHash: string;
  locale: string;
  bio?: string | null;
  avatarUrl?: string | null;
  bannerUrl?: string | null;
  location?: string | null;
  birthDate?: Date | null;
  isEmailVerified: boolean;
  usernameSet: boolean;
  isPremium: boolean;
  premiumExpiresAt?: Date | null;
  isAdmin: boolean;
  isBot: boolean;
  walletBalance: number;
  profileVisibility: string;
  birthDateVisibility: string;
  storyVisibility: string;
  dmPrice: number;
  awayEnabled: boolean;
  awayMessage?: string | null;
  quickReplies?: any;
  createdAt: Date;
}

interface AppConfigRecord {
  id: number;
  siteName: string;
  domain?: string | null;
  updatedAt: Date;
}

interface SessionRecord {
  id: string;
  userId: string;
  deviceInfo?: string | null;
  ipAddress?: string | null;
  createdAt: Date;
  lastSeenAt: Date;
}

interface ContactRecord {
  id: string;
  ownerId: string;
  contactId: string;
  alias?: string | null;
  tag?: string | null;
  createdAt: Date;
}

interface WalletTxRecord {
  id: string;
  userId: string;
  type: string;
  amount: number;
  createdAt: Date;
}

interface DeveloperBotRecord {
  id: string;
  ownerId: string;
  botUserId: string;
  name: string;
  tokenHash: string;
  tokenPrefix: string;
  webhookUrl?: string | null;
  createdAt: Date;
}

class InMemoryPrisma {
  users = new Map<string, UserRecord>();
  appConfigs = new Map<number, AppConfigRecord>();
  sessions = new Map<string, SessionRecord>();
  contacts = new Map<string, ContactRecord>();
  walletTransactions = new Map<string, WalletTxRecord>();
  developerBots = new Map<string, DeveloperBotRecord>();

  constructor() {
    this.appConfigs.set(1, {
      id: 1,
      siteName: "SYRIX CHAT",
      domain: null,
      updatedAt: new Date()
    });
  }

  user = {
    count: async (args?: { where?: any }) => {
      let list = Array.from(this.users.values());
      if (args?.where) {
        if (args.where.isAdmin !== undefined) list = list.filter(u => u.isAdmin === args.where.isAdmin);
        if (args.where.isEmailVerified !== undefined) list = list.filter(u => u.isEmailVerified === args.where.isEmailVerified);
        if (args.where.isBot !== undefined) list = list.filter(u => u.isBot === args.where.isBot);
      }
      return list.length;
    },

    findUnique: async (args: { where: { id?: string; username?: string; email?: string } }) => {
      for (const u of this.users.values()) {
        if (args.where.id && u.id === args.where.id) return { ...u };
        if (args.where.username && u.username.toLowerCase() === args.where.username.toLowerCase()) return { ...u };
        if (args.where.email && u.email.toLowerCase() === args.where.email.toLowerCase()) return { ...u };
      }
      return null;
    },

    findFirst: async (args?: { where?: any }) => {
      for (const u of this.users.values()) {
        if (!args?.where) return { ...u };
        const { OR, email, username } = args.where;
        if (OR) {
          const match = OR.some((cond: any) => {
            if (cond.email && u.email.toLowerCase() === cond.email.toLowerCase()) return true;
            if (cond.username && u.username.toLowerCase() === cond.username.toLowerCase()) return true;
            return false;
          });
          if (match) return { ...u };
        }
        if (email && u.email.toLowerCase() === email.toLowerCase()) return { ...u };
        if (username && u.username.toLowerCase() === username.toLowerCase()) return { ...u };
      }
      return null;
    },

    findMany: async (args?: any) => {
      let list = Array.from(this.users.values());
      if (args?.where) {
        if (args.where.isBot !== undefined) list = list.filter(u => u.isBot === args.where.isBot);
        if (args.where.isAdmin !== undefined) list = list.filter(u => u.isAdmin === args.where.isAdmin);
        if (args.where.isPremium !== undefined) list = list.filter(u => u.isPremium === args.where.isPremium);
      }
      if (args?.orderBy?.createdAt === "desc") {
        list.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
      }
      const skip = args?.skip || 0;
      const take = args?.take ? skip + args.take : list.length;
      return list.slice(skip, take).map(u => ({ ...u }));
    },

    create: async (args: { data: any }) => {
      const id = args.data.id || crypto.randomUUID();
      const record: UserRecord = {
        id,
        username: args.data.username,
        email: args.data.email,
        passwordHash: args.data.passwordHash,
        locale: args.data.locale || "en",
        bio: args.data.bio || null,
        avatarUrl: args.data.avatarUrl || null,
        bannerUrl: args.data.bannerUrl || null,
        location: args.data.location || null,
        birthDate: args.data.birthDate ? new Date(args.data.birthDate) : null,
        isEmailVerified: args.data.isEmailVerified ?? false,
        usernameSet: args.data.usernameSet ?? false,
        isPremium: args.data.isPremium ?? false,
        premiumExpiresAt: args.data.premiumExpiresAt || null,
        isAdmin: args.data.isAdmin ?? false,
        isBot: args.data.isBot ?? false,
        walletBalance: args.data.walletBalance ?? 0,
        profileVisibility: args.data.profileVisibility || "everyone",
        birthDateVisibility: args.data.birthDateVisibility || "hidden",
        storyVisibility: args.data.storyVisibility || "everyone",
        dmPrice: args.data.dmPrice ?? 0,
        awayEnabled: args.data.awayEnabled ?? false,
        awayMessage: args.data.awayMessage || null,
        quickReplies: args.data.quickReplies || null,
        createdAt: new Date()
      };
      this.users.set(id, record);
      return { ...record };
    },

    update: async (args: { where: { id?: string; username?: string }; data: any }) => {
      let target: UserRecord | undefined;
      for (const u of this.users.values()) {
        if (args.where.id && u.id === args.where.id) { target = u; break; }
        if (args.where.username && u.username.toLowerCase() === args.where.username.toLowerCase()) { target = u; break; }
      }
      if (!target) throw new Error("Record not found");
      const updated: UserRecord = {
        ...target,
        ...args.data
      };
      this.users.set(target.id, updated);
      return { ...updated };
    },

    delete: async (args: { where: { id: string } }) => {
      const existing = this.users.get(args.where.id);
      this.users.delete(args.where.id);
      return existing || { id: args.where.id };
    }
  };

  appConfig = {
    findUnique: async (_args: { where: { id: number } }) => {
      const cfg = this.appConfigs.get(1);
      return cfg ? { ...cfg } : null;
    },
    upsert: async (args: { where: { id: number }; update: any; create: any }) => {
      const existing = this.appConfigs.get(1);
      if (existing) {
        const updated = { ...existing, ...args.update, updatedAt: new Date() };
        this.appConfigs.set(1, updated);
        return { ...updated };
      }
      const created = { id: 1, siteName: "SYRIX CHAT", domain: null, ...args.create, updatedAt: new Date() };
      this.appConfigs.set(1, created);
      return { ...created };
    }
  };

  session = {
    create: async (args: { data: any }) => {
      const id = args.data.id || crypto.randomUUID();
      const rec: SessionRecord = {
        id,
        userId: args.data.userId,
        deviceInfo: args.data.deviceInfo || null,
        ipAddress: args.data.ipAddress || null,
        createdAt: new Date(),
        lastSeenAt: new Date()
      };
      this.sessions.set(id, rec);
      return { ...rec };
    },
    findUnique: async (args: { where: { id: string } }) => {
      const s = this.sessions.get(args.where.id);
      return s ? { ...s } : null;
    },
    findMany: async (args?: { where?: { userId?: string } }) => {
      let list = Array.from(this.sessions.values());
      if (args?.where?.userId) list = list.filter(s => s.userId === args.where!.userId);
      return list.map(s => ({ ...s }));
    },
    delete: async (args: { where: { id: string } }) => {
      const s = this.sessions.get(args.where.id);
      this.sessions.delete(args.where.id);
      return s || { id: args.where.id };
    },
    deleteMany: async (args?: { where?: any }) => {
      let count = 0;
      for (const [id, s] of this.sessions.entries()) {
        if (args?.where?.userId && s.userId === args.where.userId) {
          if (args.where.id?.not && s.id === args.where.id.not) continue;
          this.sessions.delete(id);
          count++;
        }
      }
      return { count };
    }
  };

  contact = {
    findMany: async (args?: { where?: any; include?: any }) => {
      let list = Array.from(this.contacts.values());
      if (args?.where?.ownerId) list = list.filter(c => c.ownerId === args.where.ownerId);
      return list.map(c => {
        const res: any = { ...c };
        if (args?.include?.contact) {
          res.contact = this.users.get(c.contactId) || null;
        }
        return res;
      });
    },
    findUnique: async (args: { where: any }) => {
      for (const c of this.contacts.values()) {
        if (args.where.id && c.id === args.where.id) return { ...c };
        if (args.where.ownerId_contactId) {
          if (c.ownerId === args.where.ownerId_contactId.ownerId && c.contactId === args.where.ownerId_contactId.contactId) {
            return { ...c };
          }
        }
      }
      return null;
    },
    create: async (args: { data: any }) => {
      const id = args.data.id || crypto.randomUUID();
      const rec: ContactRecord = {
        id,
        ownerId: args.data.ownerId,
        contactId: args.data.contactId,
        alias: args.data.alias || null,
        tag: args.data.tag || null,
        createdAt: new Date()
      };
      this.contacts.set(id, rec);
      return { ...rec };
    },
    update: async (args: { where: { id: string }; data: any }) => {
      const existing = this.contacts.get(args.where.id);
      if (!existing) throw new Error("Contact not found");
      const updated = { ...existing, ...args.data };
      this.contacts.set(args.where.id, updated);
      return { ...updated };
    },
    delete: async (args: { where: { id: string } }) => {
      const existing = this.contacts.get(args.where.id);
      this.contacts.delete(args.where.id);
      return existing || { id: args.where.id };
    }
  };

  walletTransaction = {
    findMany: async (args?: { where?: any; orderBy?: any }) => {
      let list = Array.from(this.walletTransactions.values());
      if (args?.where?.userId) list = list.filter(t => t.userId === args.where.userId);
      if (args?.orderBy?.createdAt === "desc") {
        list.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
      }
      return list.map(t => ({ ...t }));
    },
    create: async (args: { data: any }) => {
      const id = args.data.id || crypto.randomUUID();
      const rec: WalletTxRecord = {
        id,
        userId: args.data.userId,
        type: args.data.type,
        amount: args.data.amount,
        createdAt: new Date()
      };
      this.walletTransactions.set(id, rec);
      return { ...rec };
    }
  };

  developerBot = {
    findMany: async (args?: { where?: any }) => {
      let list = Array.from(this.developerBots.values());
      if (args?.where?.ownerId) list = list.filter(b => b.ownerId === args.where.ownerId);
      return list.map(b => ({ ...b }));
    },
    findUnique: async (args: { where: any }) => {
      for (const b of this.developerBots.values()) {
        if (args.where.id && b.id === args.where.id) return { ...b };
        if (args.where.botUserId && b.botUserId === args.where.botUserId) return { ...b };
      }
      return null;
    },
    create: async (args: { data: any }) => {
      const id = args.data.id || crypto.randomUUID();
      const rec: DeveloperBotRecord = {
        id,
        ownerId: args.data.ownerId,
        botUserId: args.data.botUserId,
        name: args.data.name,
        tokenHash: args.data.tokenHash,
        tokenPrefix: args.data.tokenPrefix,
        webhookUrl: args.data.webhookUrl || null,
        createdAt: new Date()
      };
      this.developerBots.set(id, rec);
      return { ...rec };
    },
    update: async (args: { where: { id: string }; data: any }) => {
      const existing = this.developerBots.get(args.where.id);
      if (!existing) throw new Error("Bot not found");
      const updated = { ...existing, ...args.data };
      this.developerBots.set(args.where.id, updated);
      return { ...updated };
    },
    delete: async (args: { where: { id: string } }) => {
      const existing = this.developerBots.get(args.where.id);
      this.developerBots.delete(args.where.id);
      return existing || { id: args.where.id };
    }
  };

  async $connect() {}
  async $disconnect() {}
}

const inMemory = new InMemoryPrisma();

let realPrisma: any = null;
if (process.env.DATABASE_URL) {
  try {
    realPrisma = new PrismaClient();
  } catch {
    console.warn("[AI Studio] Could not initialize real PrismaClient, using in-memory mock");
  }
}

export const prisma: PrismaClient = new Proxy(inMemory as any, {
  get(target, prop) {
    if (realPrisma && prop in realPrisma) {
      const realVal = realPrisma[prop];
      if (typeof realVal === "object" && realVal !== null) {
        return new Proxy(realVal, {
          get(subTarget, subProp) {
            const originalMethod = subTarget[subProp];
            if (typeof originalMethod === "function") {
              return async (...args: any[]) => {
                try {
                  return await originalMethod.apply(subTarget, args);
                } catch (err) {
                  const fallbackObj = (target as any)[prop];
                  if (fallbackObj && typeof fallbackObj[subProp] === "function") {
                    return await fallbackObj[subProp](...args);
                  }
                  throw err;
                }
              };
            }
            return originalMethod;
          }
        });
      }
      return realVal;
    }
    return (target as any)[prop];
  }
});

