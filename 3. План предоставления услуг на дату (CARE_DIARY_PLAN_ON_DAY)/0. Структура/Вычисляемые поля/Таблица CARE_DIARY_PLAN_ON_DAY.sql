----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--Вычисляемое поле "День недели"
--Конвертирует номер дня недели в слово.
ALTER TABLE dbo.CARE_DIARY_PLAN_ON_DAY DROP COLUMN DAY_NUMBER_TITLE
ALTER TABLE dbo.CARE_DIARY_PLAN_ON_DAY ADD DAY_NUMBER_TITLE AS (dbo.fs_getTitleDayOfWeek(DAY_NUMBER, 'Пн.', 'Вт.', 'Ср.', 'Чт.', 'Пт.', 'Сб.', 'Вс.'))

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------