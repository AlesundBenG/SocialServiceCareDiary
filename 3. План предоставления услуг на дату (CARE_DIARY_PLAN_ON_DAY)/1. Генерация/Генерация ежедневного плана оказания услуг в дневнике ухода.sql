--------------------------------------------------------------------------------------------------------------------------------

--Параметры.
DECLARE @dateForPlan    DATE    = CONVERT(DATE, '#dateForPlan#')              --День, для которого составляется график.
DECLARE @weekForPlan    INT     = dbo.fs_getNumberWeekOfMonth(@dateForPlan) --Номер недели, для которой составляется график.
DECLARE @dayForPlan     INT     = DATEPART(DW, @dateForPlan)                --День недели, для которой составляется план.
DECLARE @year           INT     = YEAR(@dateForPlan)    --Год.
DECLARE @month          INT     = MONTH(@dateForPlan)   --Месяц.
DECLARE @day            INT     = DAY(@dateForPlan)     --День.

--------------------------------------------------------------------------------------------------------------------------------

--Удаление временных таблиц.
IF OBJECT_ID('tempdb..#SERV_SDU_FOR_DAY')   IS NOT NULL BEGIN DROP TABLE #SERV_SDU_FOR_DAY  END --Список услуг СДУ для указанного дня.
IF OBJECT_ID('tempdb..#WORK_PLAN')          IS NOT NULL BEGIN DROP TABLE #WORK_PLAN         END --План оказания услуг для указанного дня.

------------------------------------------------------------------------------------------------------------------------------

--Константы.
DECLARE @activeStatus       INT = (SELECT A_ID FROM ESRN_SERV_STATUS WHERE A_STATUSCODE = 'act')    --Статус действующей (не удаленной) записи.
DECLARE @docTypeCareDiary   INT = (SELECT A_ID FROM PPR_DOC WHERE A_CODE = 'CareDiary')             --Идентификатор типа документа дневника ухода.

------------------------------------------------------------------------------------------------------------------------------

--Создание временных таблиц.
CREATE TABLE #SERV_SDU_FOR_DAY (
    CARE_DIARY_OUID     INT,            --Идентификатор дневника ухода.
    CARE_DIARY_REPORT   INT,            --Идентификатор ежемесячного отчета, по которому создается план.
    COUNT_IN_DAY        INT,            --Количество услуг в день.

)
CREATE TABLE #WORK_PLAN (
    CARE_DIARY_OUID     INT,    --Идентификатор дневника ухода.
    CARE_DIARY_REPORT   INT,    --Идентификатор ежемесячного отчета, по которому создается план.
    COUNT_IN_DAY        INT,    --Количество услуг в день.
    INDEX_IN_DAY        INT,    --Индекс услуги.
    DATE                DATE,   --Дата, для которой сформирована услуга.
    WEEK_NUMBER         INT,    --Номер недели, для которой сформирована услуга.
    DAY_NUMBER          INT,    --Номер дня, для которой сформирована услуга.
)

--------------------------------------------------------------------------------------------------------------------------------

--Формирование планов на день. 
DECLARE @query NVARCHAR(MAX) = ''
SET @query = '
    INSERT INTO #SERV_SDU_FOR_DAY(CARE_DIARY_OUID, CARE_DIARY_REPORT, COUNT_IN_DAY)
    SELECT
        report.CARE_DIARY_OUID                          AS CARE_DIARY_OUID,
        report.A_OUID                                   AS CARE_DIARY_REPORT,
        report.DAY_' +  CONVERT(VARCHAR, @day) + '_ALL  AS COUNT_IN_DAY
    FROM CARE_DIARY_REPORT report --План-отчет предоставления услуг СДУ из дневника ухода.
    ----План предоставления услуг на дату.
        LEFT JOIN CARE_DIARY_PLAN_ON_DAY planOnDay
            ON planOnDay.CARE_DIARY_REPORT = report.A_OUID
                AND planOnDay.A_STATUS = ' + CONVERT(VARCHAR, @activeStatus) + '
                AND CONVERT(DATE, planOnDay.DATE) = CONVERT(DATE, ''' + CONVERT(VARCHAR, @dateForPlan) + ''')
    WHERE report.A_STATUS = ' + CONVERT(VARCHAR, @activeStatus) + '
        AND planOnDay.A_OUID IS NULL
        AND report.ROW_TYPE = 2
        AND report.YEAR = ' + CONVERT(VARCHAR, @year) + '
        AND report.MONTH = ' + CONVERT(VARCHAR, @month) + '
        AND ISNULL(DAY_' + CONVERT(VARCHAR, @day) + '_ALL, 0) > 0
        AND report.CARE_DIARY_OUID  IN (
            #careDiary#
        )'

EXEC SP_EXECUTESQL @query

------------------------------------------------------------------------------------------------------------------------------

--Дублирование услуг в соответствии с количеством оказанием на дню.
DECLARE @careDiary          INT         --Идентификатор дневника ухода.
DECLARE @careDiaryReport    INT         --Идентификатор ежемесячного отчета.
DECLARE @countInDay         INT         --Количество услуг в день.
DECLARE @cursorMultiplyRows CURSOR      --Курсор для приумножения строк в соответствии со значением.

--Формирования xml-текста документов.                         
SET @cursorMultiplyRows = CURSOR SCROLL FOR --Заполнение курсора.
    SELECT CARE_DIARY_OUID, CARE_DIARY_REPORT, COUNT_IN_DAY FROM #SERV_SDU_FOR_DAY  
OPEN @cursorMultiplyRows --Открытие курсора.
FETCH NEXT FROM @cursorMultiplyRows INTO @careDiary, @careDiaryReport, @countInDay --Выбор первой записи.
--Основной цикл курсора.
WHILE @@FETCH_STATUS = 0 BEGIN
    DECLARE @count INT = 0
    WHILE @count < @countInDay BEGIN
        INSERT INTO #WORK_PLAN (CARE_DIARY_OUID, CARE_DIARY_REPORT, COUNT_IN_DAY, INDEX_IN_DAY, DATE, WEEK_NUMBER, DAY_NUMBER)
        VALUES(@careDiary, @careDiaryReport, @countInDay, @count + 1, @dateForPlan, @weekForPlan, @dayForPlan)
        SET @count = @count + 1 
    END
     --Выбираем данные изе первой строки курсора
    FETCH NEXT FROM @cursorMultiplyRows INTO @careDiary, @careDiaryReport, @countInDay
END
CLOSE @cursorMultiplyRows --Закрытие курсора.
DEALLOCATE @cursorMultiplyRows --Освобождения ресурсов, выделенные курсору.     

------------------------------------------------------------------------------------------------------------------------------

--Вставка плана.
INSERT INTO CARE_DIARY_PLAN_ON_DAY(CARE_DIARY_OUID, CARE_DIARY_REPORT, INDEX_IN_DAY, COUNT_IN_DAY, DATE, WEEK_NUMBER, DAY_NUMBER, PERFORM, A_STATUS, A_CREATEDATE, CHANGED)
SELECT 
    CARE_DIARY_OUID     AS CARE_DIARY_OUID, 
    CARE_DIARY_REPORT   AS CARE_DIARY_REPORT,
    INDEX_IN_DAY        AS INDEX_IN_DAY, 
    COUNT_IN_DAY        AS COUNT_IN_DAY, 
    DATE                AS DATE, 
    WEEK_NUMBER         AS WEEK_NUMBER, 
    DAY_NUMBER          AS DAY_NUMBER, 
    0                   AS PERFORM,
    @activeStatus       AS A_STATUS,
    GETDATE()           AS A_CREATEDATE,
    0                   AS CHANGED
FROM #WORK_PLAN

------------------------------------------------------------------------------------------------------------------------------