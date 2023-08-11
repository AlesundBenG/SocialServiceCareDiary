----------------------------------------------------------------------------------------------------------------------------------
/*Генерация на текущий день

--Назначение для создания дневника.
DECLARE @careDiaryForGenerateDayPlan    INT     = 0 --Идентификатор содержимого дневника ухода.
DECLARE @dateForPlanForGenerateDayPlan  DATE    = CONVERT(DATE, GETDATE()) --Дата, для которой генерируется план.
--Запрос на создание дневника по уходу.
DECLARE @queryGenerateDayPlanForCareDiary NVARCHAR(MAX) = (
    SELECT
        REPLACE(REPLACE(SQLSTATEMENT, 
            '#dateForPlan#',    @dateForPlanForGenerateDayPlan),
            '#careDiary#',      @careDiaryForGenerateDayPlan
        )
    FROM SX_OBJ_QUERY query
    WHERE query.A_CODE = 'generateDayPlanForCareDiary'
)
--Создание.
EXEC SP_EXECUTESQL @queryGenerateDayPlanForCareDiary
*/
----------------------------------------------------------------------------------------------------------------------------------
/*Генерация с начала месяца до текущего дня*/

--Назначение для создания дневника.
DECLARE @generateDateEnd                DATE = CONVERT(DATE, GETDATE())
DECLARE @generateDateStart              DATE = dbo.fs_getFirstDayOfMonth(YEAR(@generateDateEnd), MONTH(@generateDateEnd))
DECLARE @dateForPlanForGenerateDayPlan  DATE = @generateDateStart --Дата, для которой генерируется план.
DECLARE @careDiaryForGenerateDayPlan    INT  = 0 --Идентификатор содержимого дневника ухода.
DECLARE @queryGenerateDayPlanForCareDiary NVARCHAR(MAX)
DECLARE @baseQueryGenerateDayPlanForCareDiary NVARCHAR(MAX) = (
    SELECT
        REPLACE(SQLSTATEMENT, '#careDiary#', @careDiaryForGenerateDayPlan)
    FROM SX_OBJ_QUERY query
    WHERE query.A_CODE = 'generateDayPlanForCareDiary'
)

--Проход по всем дням.
WHILE @dateForPlanForGenerateDayPlan <= @generateDateEnd BEGIN
    --Запрос на создание дневника по уходу.
    SET @queryGenerateDayPlanForCareDiary = REPLACE(@baseQueryGenerateDayPlanForCareDiary, '#dateForPlan#', @dateForPlanForGenerateDayPlan)
    --Создание.
    EXEC SP_EXECUTESQL @queryGenerateDayPlanForCareDiary
    SET @dateForPlanForGenerateDayPlan = DATEADD(DAY, 1, @dateForPlanForGenerateDayPlan)
END

----------------------------------------------------------------------------------------------------------------------------------