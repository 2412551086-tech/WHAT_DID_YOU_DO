UPDATE "Chore"
SET "category" = CASE
  WHEN "catalogKey" = 'core-cook-prepare' THEN '烹饪'
  WHEN "catalogKey" IN (
    'core-dishes-cleanup',
    'core-sweep-vacuum',
    'core-mop-floor',
    'core-bathroom-clean',
    'core-trash-recycling',
    'premium-clean-stove',
    'premium-clean-litter'
  ) THEN '清洁'
  WHEN "catalogKey" IN (
    'core-laundry',
    'core-fold-clothes',
    'premium-change-bedding'
  ) THEN '洗护'
  WHEN "catalogKey" = 'core-organize-storage' THEN '整理'
  WHEN "catalogKey" IN (
    'premium-walk-dog',
    'premium-homework-help',
    'premium-feed-baby',
    'premium-walk-child',
    'premium-school-run'
  ) THEN '照顾'
  WHEN "catalogKey" IN (
    'core-shopping-supplies',
    'premium-heavy-lifting',
    'premium-repair-booking'
  ) THEN '家庭事务'
  WHEN "isCustom" = true AND "icon" IN (
    'chore_custom_dust',
    'chore_custom_window',
    'chore_custom_car',
    'chore_custom_fridge'
  ) THEN '清洁'
  WHEN "isCustom" = true AND "icon" = 'chore_custom_bed' THEN '整理'
  WHEN "isCustom" = true AND "icon" IN (
    'chore_custom_plant',
    'chore_custom_pet',
    'chore_custom_childcare'
  ) THEN '照顾'
  WHEN "isCustom" = true AND "icon" IN (
    'chore_custom_repair',
    'chore_custom_admin'
  ) THEN '家庭事务'
  WHEN "category" IN ('清洁类', '餐厨清洁', '地面清洁', '卫生间', '日常杂务') THEN '清洁'
  WHEN "category" IN ('洗护类', '洗护', '衣物整理') THEN '洗护'
  WHEN "category" IN ('收纳类', '整理收纳') THEN '整理'
  WHEN "category" IN ('照顾类', '宠物类') THEN '照顾'
  WHEN "category" IN ('采购类', '管理类', '采购管理') THEN '家庭事务'
  WHEN "category" = '厨房类' AND ("name" LIKE '%做饭%' OR "name" LIKE '%备餐%') THEN '烹饪'
  WHEN "category" = '厨房类' THEN '清洁'
  ELSE "category"
END;
