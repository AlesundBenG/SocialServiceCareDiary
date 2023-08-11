--Назначение для создания дневника.
DECLARE @socServForCreateCareDiary INT = 0 --Идентификатор назначения на социальное обслуживание.
--Запрос на создание дневника по уходу.
DECLARE @queryCreateCareDiaryBySocServ NVARCHAR(MAX) = (
    SELECT
        REPLACE(SQLSTATEMENT, '#socServ#', @socServForCreateCareDiary)
    FROM SX_OBJ_QUERY query
    WHERE query.A_CODE = 'createCareDiaryBySocServ'
)
--Создание.
EXEC SP_EXECUTESQL @queryCreateCareDiaryBySocServ