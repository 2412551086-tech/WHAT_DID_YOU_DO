export type MasteryRecordTaxonomy = {
  subcategory: string | null;
  standardCategory: string | null;
};

export const MASTERY_KEYS = [
  'MASTERY_DISHES',
  'MASTERY_COOKING',
  'MASTERY_TRASH',
  'MASTERY_PET',
  'MASTERY_CHILDCARE',
  'MASTERY_FLOOR',
  'MASTERY_LAUNDRY',
  'MASTERY_ROMANCE',
  'MASTERY_ORGANIZE',
  'MASTERY_ALL_ROUNDER',
] as const;

export function masteryRuleThemes(value: unknown): string[] {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return [];
  }
  const themes = (value as { themes?: unknown }).themes;
  return Array.isArray(themes) ? themes.filter((theme): theme is string => typeof theme === 'string') : [];
}

export function isMasteryRuleEnabled(value: unknown, enabledThemes: ReadonlySet<string>) {
  const themes = masteryRuleThemes(value);
  return themes.length === 0 || themes.some((theme) => enabledThemes.has(theme));
}

const catalogSubcategories: Record<string, string> = {
  'core-cook-prepare': 'cooking',
  'core-dishes-cleanup': 'dishes',
  'core-laundry': 'laundry',
  'core-fold-clothes': 'laundry',
  'core-sweep-vacuum': 'floor',
  'core-mop-floor': 'floor',
  'core-organize-storage': 'organize',
  'core-trash-recycling': 'trash',
  'premium-change-bedding': 'laundry',
  'daily-make-bed': 'organize',
};

const categoryMap: Record<string, string> = {
  '烹饪': 'cooking',
  '清洁': 'cleaning',
  '洗护': 'laundry',
  '整理': 'organize',
  '照顾': 'care',
  '家庭事务': 'household',
};

export function classifyMasteryRecord(input: {
  catalogKey: string | null;
  themeKey: string;
  category: string;
  isCustom: boolean;
}): MasteryRecordTaxonomy {
  if (input.isCustom) {
    const standardCategory = categoryMap[input.category] ?? null;
    return {
      // Custom names are deliberately ignored. The explicit category is the only mapping source.
      subcategory: standardCategory,
      standardCategory,
    };
  }

  const catalogKey = input.catalogKey ?? '';
  const themeSubcategory = ['pet', 'childcare', 'love'].includes(input.themeKey)
    ? input.themeKey
    : null;
  const subcategory = catalogSubcategories[catalogKey] ?? themeSubcategory ?? null;

  return {
    subcategory,
    standardCategory: subcategory ?? categoryMap[input.category] ?? null,
  };
}
