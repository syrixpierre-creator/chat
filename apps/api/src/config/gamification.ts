export const XP_PER_MESSAGE = 10;
export const XP_PER_LEVEL = 100;
export const XP_COOLDOWN_MS = 30 * 1000;

export interface Badge {
  key: string;
  minLevel: number;
}

export const BADGES: Badge[] = [
  { key: "newcomer", minLevel: 1 },
  { key: "contributor", minLevel: 5 },
  { key: "active_contributor", minLevel: 10 },
  { key: "pillar", minLevel: 20 }
];

export function levelFromXp(xp: number): number {
  return Math.floor(xp / XP_PER_LEVEL) + 1;
}

export function xpIntoCurrentLevel(xp: number): { current: number; needed: number } {
  const current = xp % XP_PER_LEVEL;
  return { current, needed: XP_PER_LEVEL };
}

export function badgeForLevel(level: number): string {
  let badge = BADGES[0].key;
  for (const entry of BADGES) {
    if (level >= entry.minLevel) {
      badge = entry.key;
    }
  }
  return badge;
}
