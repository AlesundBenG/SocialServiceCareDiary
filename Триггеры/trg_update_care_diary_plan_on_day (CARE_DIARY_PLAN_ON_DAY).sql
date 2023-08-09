USE [esrn]
GO
/****** Object:  Trigger [dbo].[trg_update_care_diary_plan_on_day]    Script Date: 09.08.2023 14:36:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[trg_update_care_diary_plan_on_day] ON [dbo].[CARE_DIARY_PLAN_ON_DAY]
AFTER UPDATE
AS
BEGIN
    --Ставим флаг изменения записи.
    UPDATE planOnDay
    SET planOnDay.CHANGED = 1
    FROM inserted --Новые значения.
    ----Значения до изменения.
        INNER JOIN deleted
            ON inserted.A_OUID = deleted.A_OUID
    ----План предоставления услуг на дату.
        INNER JOIN CARE_DIARY_PLAN_ON_DAY planOnDay
            ON planOnDay.A_OUID = inserted.A_OUID
    WHERE ISNULL(inserted.PERFORM, 0) <> ISNULL(deleted.PERFORM, 0) --Установлен или снят флаг.
        OR ISNULL(inserted.A_STATUS, 0) <> ISNULL(deleted.A_STATUS, 0) --Или запись удалена.
END
