--------------------------------------------------------------------------------------------------------------------------------

--Удаление временных таблиц.
IF OBJECT_ID('tempdb..#CHANGED_SERV_SDU')       IS NOT NULL BEGIN DROP TABLE #CHANGED_SERV_SDU      END --Измененные услуги.
IF OBJECT_ID('tempdb..#CHANGED_DAY_OF_MONTH')   IS NOT NULL BEGIN DROP TABLE #CHANGED_DAY_OF_MONTH  END --Измененные дни месяца.
IF OBJECT_ID('tempdb..#FOR_REPORT')             IS NOT NULL BEGIN DROP TABLE #FOR_REPORT            END --Данные для отчета.

--------------------------------------------------------------------------------------------------------------------------------

--Создание временных таблиц.
CREATE TABLE #CHANGED_SERV_SDU (
    CARE_DIARY_REPORT   INT,    --Ежемесячный отчет по услуге.
    FOR_DATE            DATE    --Дата плана услуги.
)
CREATE TABLE #CHANGED_DAY_OF_MONTH (
    DAY_NUMBER INT,  --Номер дня месяца.
)
CREATE TABLE #FOR_REPORT (
    CARE_DIARY_REPORT   INT,    --Ежемесячный отчет по услуге.
    FOR_DATE            DATE,   --Дата плана услуги.
    COUNT_PERFORM       INT,    --Количество оказанных услуг.
)

------------------------------------------------------------------------------------------------------------------------------

--Выбор измененных услуг за другой день.
INSERT INTO #CHANGED_SERV_SDU (CARE_DIARY_REPORT, FOR_DATE)
SELECT DISTINCT
    planOnDay.CARE_DIARY_REPORT     AS CARE_DIARY_REPORT,
    CONVERT(DATE, planOnDay.DATE)   AS FOR_DATE
FROM CARE_DIARY_PLAN_ON_DAY planOnDay --План предоставления услуг на дату
WHERE ISNULL(planOnDay.CHANGED, 0) = 1 --Данные изменены.

------------------------------------------------------------------------------------------------------------------------------

--Выбор измененных дней в месяце.
INSERT INTO #CHANGED_DAY_OF_MONTH (DAY_NUMBER)
SELECT DISTINCT
   DAY(FOR_DATE) 
FROM #CHANGED_SERV_SDU

------------------------------------------------------------------------------------------------------------------------------

--Перерасчет по измененным услугам.
INSERT INTO #FOR_REPORT (CARE_DIARY_REPORT, FOR_DATE, COUNT_PERFORM)
SELECT
    planOnDay.CARE_DIARY_REPORT                     AS CARE_DIARY_REPORT,
    changed.FOR_DATE                                AS FOR_DATE,
    SUM(CONVERT(INT, ISNULL(planOnDay.PERFORM, 0))) AS COUNT_PERFORM
FROM #CHANGED_SERV_SDU changed --Измененные услуги.
----План предоставления услуг на дату.
    INNER JOIN CARE_DIARY_PLAN_ON_DAY planOnDay 
        ON planOnDay.CARE_DIARY_REPORT = changed.CARE_DIARY_REPORT
            AND CONVERT(DATE, planOnDay.DATE) = changed.FOR_DATE
WHERE planOnDay.A_STATUS = 10
GROUP BY planOnDay.CARE_DIARY_REPORT, changed.FOR_DATE

--------------------------------------------------------------------------------------------------------------------------------

--Цикл прохода по всем отредактированным дням месяцев.
DECLARE @numberDay INT = (SELECT MIN(DAY_NUMBER) FROM #CHANGED_DAY_OF_MONTH)
DECLARE @query NVARCHAR(MAX) = ''
WHILE @numberDay IS NOT NULL BEGIN
        SET @query = '
            UPDATE report
            SET report.DAY_' + CONVERT(VARCHAR, @numberDay) + '_PERFORM = forUpdate.COUNT_PERFORM
            FROM #FOR_REPORT forUpdate
                INNER JOIN CARE_DIARY_REPORT report
                    ON report.A_OUID = forUpdate.CARE_DIARY_REPORT
                        AND report.YEAR = YEAR(forUpdate.FOR_DATE)
                        AND report.MONTH = MONTH(forUpdate.FOR_DATE)
            WHERE DAY(forUpdate.FOR_DATE) = '  + CONVERT(VARCHAR, @numberDay)
        EXEC SP_EXECUTESQL @query
    SET @numberDay = (SELECT MIN(DAY_NUMBER) FROM #CHANGED_DAY_OF_MONTH WHERE DAY_NUMBER > @numberDay)
END

--Меняем флаг того, что данные не редактируются сейчас
UPDATE CARE_DIARY_PLAN_ON_DAY
SET CHANGED = 0
WHERE ISNULL(CHANGED, 0) = 1 --Данные изменены.

--------------------------------------------------------------------------------------------------------------------------------
