import { Injectable } from '@nestjs/common';
import { AchievementEvent, AchievementOwnerType, AchievementProgressStatus, AchievementVisibility, MemberStatus, Prisma } from '@prisma/client';
import { getLocalDateKeyForTimeZone } from '../common/timezone-ranges';
import { calculateSceneValue, SCENE_RULES } from './achievement-scene.rules';

@Injectable()
export class AchievementSceneService {
  async process(tx: Prisma.TransactionClient, event: AchievementEvent) {
    const result = { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    if (!['CHORE_CREATED', 'CHORE_UPDATED', 'CHORE_DELETED', 'CHORE_RESTORED'].includes(event.eventType)) return result;
    const family = await tx.family.findUniqueOrThrow({
      where: { id: event.familyId },
      include: { members: { where: { status: MemberStatus.ACTIVE } } },
    });
    const records = await tx.choreRecord.findMany({
      where: { familyId: event.familyId, deletedAt: null, userId: { in: family.members.map((member) => member.userId) } },
      include: { chore: { select: { catalogKey: true, isCustom: true } } },
    });
    const snapshots = await tx.achievementEvent.findMany({
      where: { familyId: event.familyId, eventType: 'CHORE_CREATED', sourceId: { in: records.map((record) => record.id) } },
      select: { sourceId: true, familyTimezoneSnapshot: true },
    });
    const timezoneByRecord = new Map(snapshots.map((snapshot) => [snapshot.sourceId, snapshot.familyTimezoneSnapshot]));
    const metrics = records.map((record) => ({
      userId: record.userId,
      localDateKey: getLocalDateKeyForTimeZone(record.occurredAt, timezoneByRecord.get(record.id) ?? family.timezone),
      ...record.chore,
    }));
    const chores = await tx.chore.findMany({ where: { id: { in: family.choreOrder }, archivedAt: null }, select: { themeKey: true } });
    const themes = new Set(['daily', ...chores.map((chore) => chore.themeKey)]);
    const definitions = await tx.achievementDefinition.findMany({ where: { key: { in: SCENE_RULES.map((rule) => rule.key) }, ownerType: AchievementOwnerType.MEMBER, isActive: true } });
    let batch = await tx.achievementUnlockBatch.findUnique({ where: { triggerEventId: event.id } });
    for (const member of family.members) {
      const owned = await tx.memberAchievement.findMany({ where: { familyId: family.id, userId: member.userId, definitionId: { in: definitions.map((definition) => definition.id) } } });
      for (const definition of definitions) {
        const rule = SCENE_RULES.find((rule) => rule.key === definition.key)!;
        const wasUnlocked = owned.some((unlock) => unlock.definitionId === definition.id);
        if (!wasUnlocked && (!themes.has(rule.theme) || family.members.length < (definition.minimumMemberCount ?? 1))) continue;
        const rawCurrentValue = calculateSceneValue(rule, metrics, member.userId);
        const achieved = wasUnlocked || rawCurrentValue >= definition.targetValue;
        const ownerKey = `${family.id}:${member.userId}`;
        const values = {
          rawCurrentValue,
          displayCurrentValue: achieved ? definition.targetValue : rawCurrentValue,
          progressStatus: achieved ? AchievementProgressStatus.COMPLETED : AchievementProgressStatus.ACTIVE,
          lastEventId: event.id,
        };
        await tx.achievementProgress.upsert({
          where: { ownerType_ownerKey_achievementKey_tier_definitionVersion: { ownerType: AchievementOwnerType.MEMBER, ownerKey, achievementKey: definition.key, tier: definition.tier, definitionVersion: definition.definitionVersion } },
          create: { ownerType: AchievementOwnerType.MEMBER, ownerKey, familyId: family.id, definitionId: definition.id, achievementKey: definition.key, tier: definition.tier, definitionVersion: definition.definitionVersion, targetValue: definition.targetValue, ...values },
          update: values,
        });
        result.progressUpdateCount++;
        if (!achieved || wasUnlocked) continue;
        batch ??= await tx.achievementUnlockBatch.create({ data: { familyId: family.id, triggerEventId: event.id } });
        const unlock = await tx.memberAchievement.create({ data: {
          userId: member.userId, familyId: family.id, definitionId: definition.id,
          achievementKey: definition.key, tier: definition.tier, definitionVersion: definition.definitionVersion,
          visibility: rule.hidden || !member.showAchievementsToFamily ? AchievementVisibility.PRIVATE : AchievementVisibility.FAMILY,
          unlockBatchId: batch.id, triggerEventId: event.id, unlockedAt: event.occurredAt,
        } });
        await tx.achievementAuditLog.create({ data: {
          familyId: family.id, actorUserId: member.userId,
          actionType: rule.hidden ? 'HIDDEN_ACHIEVEMENT_DISCOVERED' : 'ACHIEVEMENT_UNLOCKED',
          entityType: 'MemberAchievement', entityId: unlock.id,
          afterJson: { achievementKey: definition.key, triggerEventId: event.id },
        } });
        result.unlockedKeys.push(definition.key);
      }
    }
    return result;
  }
}
