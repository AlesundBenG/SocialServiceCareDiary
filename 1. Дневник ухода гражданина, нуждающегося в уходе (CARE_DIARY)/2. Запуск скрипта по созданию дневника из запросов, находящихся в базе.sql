--Ссылка на запрос http://esrn/admin/edit.htm?id=12461561%40SXObjQuery

------------------------------------------------------------------------------------------------------------------
/*Одиночное создание*/

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

------------------------------------------------------------------------------------------------------------------
/*Массовое создание*/

--Удаление временных таблиц.
IF OBJECT_ID('tempdb..#FOR_CARE_DIARY') IS NOT NULL BEGIN DROP TABLE #FOR_CARE_DIARY END --Для дневника ухода.

--Создание временных таблиц.
CREATE TABLE #FOR_CARE_DIARY (
    SOC_SERV_OUID INT
)

--Вставка назначений для создания дневника.
INSERT INTO #FOR_CARE_DIARY (SOC_SERV_OUID)
VALUES (0), (-1), (-2)

--Запись всех идентификаторов в одну строку через запятую.
DECLARE @socServForCreateCareDiary VARCHAR(256) = (
SELECT
    STUFF((
        SELECT 
            ',' + CONVERT(VARCHAR, SOC_SERV_OUID)
        FROM #FOR_CARE_DIARY
        FOR XML PATH ('')
        ), 1, 1, ''
    )
)
--Запрос на создание дневника по уходу.
DECLARE @queryCreateCareDiaryBySocServ NVARCHAR(MAX) = (
    SELECT
        REPLACE(SQLSTATEMENT, '#socServ#', @socServForCreateCareDiary)
    FROM SX_OBJ_QUERY query
    WHERE query.A_CODE = 'createCareDiaryBySocServ'
)
--Создание.
EXEC SP_EXECUTESQL @queryCreateCareDiaryBySocServ

------------------------------------------------------------------------------------------------------------------