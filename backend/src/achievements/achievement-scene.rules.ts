import { additionalChoreCatalog } from '../chores/premium-chore-catalog';
import { themedChoreCatalog } from '../chores/themed-chore-catalog';

export type SceneRule = {
  key: string;
  theme: string;
  groups: readonly (readonly string[])[];
  team?: boolean;
  hidden?: boolean;
};

const themeKeys = (theme: string) => [...additionalChoreCatalog, ...themedChoreCatalog]
  .filter((chore) => chore.themeKey === theme).map((chore) => chore.id);

export const SCENE_RULES: readonly SceneRule[] = [
  { key: 'SCENE_PET_CARE', theme: 'pet', groups: [['premium-clean-litter'], ['pet-general-care']] },
  { key: 'SCENE_PET_TEAM', theme: 'pet', groups: [themeKeys('pet'), themeKeys('pet')], team: true },
  { key: 'SCENE_CHILDCARE_STORY', theme: 'childcare', groups: [['child-quality-time'], ['child-food-prep']] },
  { key: 'SCENE_CHILDCARE_TEAM', theme: 'childcare', groups: [themeKeys('childcare'), themeKeys('childcare')], team: true },
  { key: 'SCENE_LOVE_MOMENT', theme: 'love', groups: [['love-date-plan'], ['love-cook-meal']] },
  { key: 'SCENE_LOVE_TEAM', theme: 'love', groups: [['love-date-plan'], ['love-cook-meal']], team: true },
  { key: 'HIDDEN_FRESH_START', theme: 'daily', groups: [['premium-change-bedding'], ['core-laundry']], hidden: true },
  { key: 'HIDDEN_WARM_WELCOME', theme: 'daily', groups: [['core-cook-prepare'], ['core-organize-storage']], hidden: true },
];

export type SceneRecord = { userId: string; localDateKey: string; catalogKey: string | null; isCustom: boolean };

export function calculateSceneValue(rule: SceneRule, records: readonly SceneRecord[], userId: string): number {
  const days = new Map<string, SceneRecord[]>();
  for (const record of records) {
    if (record.isCustom || !record.catalogKey || (!rule.team && record.userId !== userId)) continue;
    const day = days.get(record.localDateKey) ?? [];
    day.push(record);
    days.set(record.localDateKey, day);
  }
  for (const day of days.values()) {
    const first = day.filter((record) => rule.groups[0].includes(record.catalogKey!));
    const second = day.filter((record) => rule.groups[1].includes(record.catalogKey!));
    if (first.some((left) => second.some((right) =>
      (!rule.team || left.userId !== right.userId)
      && (left.userId === userId || right.userId === userId),
    ))) return 1;
  }
  return 0;
}
