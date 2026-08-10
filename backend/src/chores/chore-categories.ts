export const choreCategories = [
  '烹饪',
  '清洁',
  '洗护',
  '整理',
  '照顾',
  '家庭事务',
] as const;

export type ChoreCategory = (typeof choreCategories)[number];
