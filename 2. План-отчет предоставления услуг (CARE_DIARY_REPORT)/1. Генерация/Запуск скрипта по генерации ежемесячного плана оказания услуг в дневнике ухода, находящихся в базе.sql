--Назначение для создания дневника.
DECLARE @careDiaryForGenerateMonthReport    INT = 0 --Идентификатор содержимого дневника ухода.
DECLARE @YearForGenerateMonthReport         INT = 0 --Год генерации.
DECLARE @MonthForGenerateMonthReport        INT = 0 --Месяц генерации.
--Запрос на создание дневника по уходу.
DECLARE @queryGenerateMonthReportForCareDiary NVARCHAR(MAX) = (
    SELECT
        REPLACE(REPLACE(REPLACE(SQLSTATEMENT, 
            '#careDiary#',  @careDiaryForGenerateMonthReport),
            '#year#',       @YearForGenerateMonthReport), 
            '#month#',      @MonthForGenerateMonthReport
        )
    FROM SX_OBJ_QUERY query
    WHERE query.A_CODE = 'generateMonthReportForCareDiary'
)
--Создание.
EXEC SP_EXECUTESQL @queryGenerateMonthReportForCareDiary