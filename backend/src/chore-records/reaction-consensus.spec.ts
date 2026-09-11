import { calculateReactionConsensus } from './reaction-consensus';

describe('calculateReactionConsensus', () => {
  it('requires two votes for a two-member family, including the author', () => {
    const reactions = [{ userId: 'member', reactionKey: 'like' }];

    expect(calculateReactionConsensus(reactions, ['author', 'member'])).toEqual({
      eligibleMemberCount: 2,
      requiredCount: 2,
      likeCount: 1,
      doubtCount: 0,
      status: 'none',
    });

    expect(calculateReactionConsensus(
      [...reactions, { userId: 'author', reactionKey: 'like' }],
      ['author', 'member'],
    ).status).toBe('appreciated');
  });

  it('requires three votes for four members and counts only active unique voters', () => {
    const reactions = [
      { userId: 'one', reactionKey: 'like' },
      { userId: 'two', reactionKey: 'like' },
      { userId: 'two', reactionKey: 'like' },
    ];

    expect(calculateReactionConsensus(reactions, ['author', 'one', 'two', 'three']).status).toBe('none');
    expect(calculateReactionConsensus(
      [...reactions, { userId: 'three', reactionKey: 'like' }],
      ['author', 'one', 'two', 'three'],
    )).toMatchObject({ likeCount: 3, requiredCount: 3, status: 'appreciated' });
  });

  it('marks doubt only when doubt has a strict majority among active members', () => {
    expect(calculateReactionConsensus(
      [
        { userId: 'one', reactionKey: 'doubt' },
        { userId: 'two', reactionKey: 'doubt' },
        { userId: 'former', reactionKey: 'doubt' },
      ],
      ['author', 'one', 'two'],
    )).toEqual({
      eligibleMemberCount: 3,
      requiredCount: 2,
      likeCount: 0,
      doubtCount: 2,
      status: 'questioned',
    });
  });
});
