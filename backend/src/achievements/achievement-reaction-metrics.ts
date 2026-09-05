export type ReactionMetricRecord = {
  recordId: string;
  senderUserId: string;
  receiverUserId: string;
  localDateKey: string;
};
export type ReactionMetrics = {
  firstGiven: number;
  given: number;
  received: number;
};

export function calculateReactionMetrics(
  records: readonly ReactionMetricRecord[],
  userId: string,
  dailyRelationshipLimit = 3,
): ReactionMetrics {
  const unique = new Map<string, ReactionMetricRecord>();

  for (const record of records) {
    if (record.senderUserId === record.receiverUserId) {
      continue;
    }
    unique.set(
      `${record.senderUserId}:${record.receiverUserId}:${record.recordId}`,
      record,
    );
  }

  const valid = [...unique.values()];
  const sent = valid.filter((record) => record.senderUserId === userId);
  const contributionByRelationshipAndDay = new Map<string, number>();

  for (const record of sent) {
    const key = `${record.senderUserId}:${record.receiverUserId}:${record.localDateKey}`;
    contributionByRelationshipAndDay.set(
      key,
      Math.min(
        dailyRelationshipLimit,
        (contributionByRelationshipAndDay.get(key) ?? 0) + 1,
      ),
    );
  }

  return {
    firstGiven: sent.length > 0 ? 1 : 0,
    given: [...contributionByRelationshipAndDay.values()].reduce(
      (total, count) => total + count,
      0,
    ),
    received: valid.filter((record) => record.receiverUserId === userId).length,
  };
}
