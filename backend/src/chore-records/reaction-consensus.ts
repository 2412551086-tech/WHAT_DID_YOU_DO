export type ReactionConsensusStatus = 'none' | 'appreciated' | 'questioned';

export type ReactionConsensus = {
  eligibleMemberCount: number;
  requiredCount: number;
  likeCount: number;
  doubtCount: number;
  status: ReactionConsensusStatus;
};

export type ConsensusReaction = {
  userId: string;
  reactionKey: string;
};

export function calculateReactionConsensus(
  reactions: readonly ConsensusReaction[],
  activeMemberUserIds: ReadonlySet<string> | readonly string[],
): ReactionConsensus {
  const activeIds = activeMemberUserIds instanceof Set
    ? activeMemberUserIds
    : new Set(activeMemberUserIds);
  const voters = new Map<string, string>();

  for (const reaction of reactions) {
    if (activeIds.has(reaction.userId)) {
      voters.set(reaction.userId, reaction.reactionKey);
    }
  }

  let likeCount = 0;
  let doubtCount = 0;
  for (const reactionKey of voters.values()) {
    if (reactionKey === 'like') likeCount += 1;
    if (reactionKey === 'doubt') doubtCount += 1;
  }

  const eligibleMemberCount = activeIds.size;
  const requiredCount = Math.floor(eligibleMemberCount / 2) + 1;
  const status: ReactionConsensusStatus = likeCount >= requiredCount
    ? 'appreciated'
    : doubtCount >= requiredCount
      ? 'questioned'
      : 'none';

  return {
    eligibleMemberCount,
    requiredCount,
    likeCount,
    doubtCount,
    status,
  };
}
