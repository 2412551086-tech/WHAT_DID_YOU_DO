import { achievementDefinitions } from '../../prisma/achievement-definitions';
import { additionalChoreCatalog } from '../chores/premium-chore-catalog';
import { themedChoreCatalog } from '../chores/themed-chore-catalog';
import { getLocalDateKeyForTimeZone } from '../common/timezone-ranges';
import { calculateSceneValue, SCENE_RULES, SceneRecord } from './achievement-scene.rules';

describe('achievement V2 scenes', () => {
  const record = (catalogKey: string, userId = 'a', localDateKey = '2026-09-08'): SceneRecord => ({ catalogKey, userId, localDateKey, isCustom: false });

  it('preserves the 59 definitions and adds exactly six visible and two hidden single-stage personal awards', () => {
    expect(achievementDefinitions).toHaveLength(67);
    expect(SCENE_RULES.filter((rule) => !rule.hidden)).toHaveLength(6);
    const catalog = new Set<string>([...additionalChoreCatalog, ...themedChoreCatalog].map((chore) => chore.id));
    ['core-laundry', 'core-cook-prepare', 'core-organize-storage'].forEach((key) => catalog.add(key));
    for (const rule of SCENE_RULES) {
      expect(rule.groups.flat().every((key) => catalog.has(key))).toBe(true);
      const definitions = achievementDefinitions.filter((definition) => definition.key === rule.key);
      expect(definitions).toHaveLength(1);
      expect(definitions[0]).toMatchObject({ ownerType: 'MEMBER', tier: 'NONE', targetValue: 1 });
      expect(definitions[0].rewardConfigJson).toBeUndefined();
    }
    expect(achievementDefinitions.filter((definition) => definition.rewardConfigJson).map((definition) => definition.key)).toEqual(['ACTIVE_DAYS_3', 'ACTIVE_DAYS_5', 'ACTIVE_DAYS_7']);
  });

  it.each(SCENE_RULES)('$key needs a real same-day combination and owner participation', (rule) => {
    const records = [record(rule.groups[0][0]), record(rule.groups[1][0], rule.team ? 'b' : 'a')];
    expect(calculateSceneValue(rule, records, 'a')).toBe(1);
    expect(calculateSceneValue(rule, records, 'outsider')).toBe(0);
    expect(calculateSceneValue(rule, [{ ...records[0], isCustom: true }, records[1]], 'a')).toBe(0);
    expect(calculateSceneValue(rule, [records[0], { ...records[1], localDateKey: '2026-09-09' }], 'a')).toBe(0);
    expect(calculateSceneValue(rule, records.slice(0, 1), 'a')).toBe(0);
    if (rule.team) {
      expect(calculateSceneValue(rule, records, 'b')).toBe(1);
      expect(calculateSceneValue(rule, records.map((record) => ({ ...record, userId: 'a' })), 'a')).toBe(0);
    }
  });

  it('uses snapshot local dates across UTC midnight and DST', () => {
    const rule = SCENE_RULES.find((rule) => rule.key === 'HIDDEN_FRESH_START')!;
    const inZone = (key: string, time: string, zone: string) => record(key, 'a', getLocalDateKeyForTimeZone(new Date(time), zone));
    expect(calculateSceneValue(rule, [
      inZone('premium-change-bedding', '2026-09-07T23:30:00Z', 'Asia/Shanghai'),
      inZone('core-laundry', '2026-09-08T02:00:00Z', 'Asia/Shanghai'),
    ], 'a')).toBe(1);
    expect(calculateSceneValue(rule, [
      inZone('premium-change-bedding', '2026-11-01T05:30:00Z', 'America/New_York'),
      inZone('core-laundry', '2026-11-01T06:30:00Z', 'America/New_York'),
    ], 'a')).toBe(1);
  });
});
