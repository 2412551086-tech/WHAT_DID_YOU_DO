import { IsIn, IsOptional, IsString } from 'class-validator';

export const CHORE_REACTION_KEYS = [
  'like',
  'high_five',
  'moon_face',
  'laugh_cry',
  'tease',
] as const;

export type ChoreReactionKey = (typeof CHORE_REACTION_KEYS)[number];

export class ReactToChoreRecordDto {
  @IsOptional()
  @IsString()
  @IsIn([...CHORE_REACTION_KEYS])
  reactionKey?: ChoreReactionKey;
}
