--------------------------------------------------------------------------------------------------------------------------------

--Удаление временных таблиц.
IF OBJECT_ID('tempdb..#CHANGED_SERV_SDU')       IS NOT NULL BEGIN DROP TABLE #CHANGED_SERV_SDU      END --Измененные услуги.
IF OBJECT_ID('tempdb..#CHANGED_DAY_OF_MONTH')   IS NOT NULL BEGIN DROP TABLE #CHANGED_DAY_OF_MONTH  END --Измененные дни месяца.
IF OBJECT_ID('tempdb..#FOR_REPORT')             IS NOT NULL BEGIN DROP TABLE #FOR_REPORT            END --Данные для отчета.
IF OBJECT_ID('tempdb..#REPORT_UPDATED')         IS NOT NULL BEGIN DROP TABLE #REPORT_UPDATED        END --Измененные отчеты.

--------------------------------------------------------------------------------------------------------------------------------

--Создание временных таблиц.
CREATE TABLE #CHANGED_SERV_SDU (
    PLAN_ON_DAY         INT,    --Ежедневный отчет.
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
CREATE TABLE #REPORT_UPDATED (
    CARE_DIARY_OUID INT,
    REPORT_OUID     INT,    --Ежемесячный отчет по услуге.
    YEAR            INT,
    MONTH           INT,
)

------------------------------------------------------------------------------------------------------------------------------

--Выбор измененных услуг за другой день.
INSERT INTO #CHANGED_SERV_SDU (PLAN_ON_DAY, CARE_DIARY_REPORT, FOR_DATE)
SELECT DISTINCT
    planOnDay.A_OUID                AS PLAN_ON_DAY,
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
FROM (SELECT DISTINCT CARE_DIARY_REPORT, FOR_DATE FROM #CHANGED_SERV_SDU) changed --Измененные услуги.
----План предоставления услуг на дату.
    INNER JOIN CARE_DIARY_PLAN_ON_DAY planOnDay 
        ON planOnDay.CARE_DIARY_REPORT = changed.CARE_DIARY_REPORT
            AND CONVERT(DATE, planOnDay.DATE) = changed.FOR_DATE
            AND planOnDay.A_STATUS = 10
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
            WHERE DAY(forUpdate.FOR_DATE) = '  + CONVERT(VARCHAR, @numberDay)
        EXEC SP_EXECUTESQL @query
    SET @numberDay = (SELECT MIN(DAY_NUMBER) FROM #CHANGED_DAY_OF_MONTH WHERE DAY_NUMBER > @numberDay)
END

--Меняем флаг того, что данные загружены в отчет.
UPDATE planOnDay
SET planOnDay.CHANGED = 0
FROM CARE_DIARY_PLAN_ON_DAY planOnDay
    INNER JOIN #CHANGED_SERV_SDU forUpdate
        ON forUpdate.PLAN_ON_DAY = planOnDay.A_OUID

--Меняем флаг того, что в отчете нет не занесенных данных.
UPDATE report
SET report.CHANGED = 0
OUTPUT inserted.CARE_DIARY_OUID, inserted.A_OUID, inserted.YEAR, inserted.MONTH INTO #REPORT_UPDATED (CARE_DIARY_OUID, REPORT_OUID, YEAR, MONTH)
FROM (SELECT DISTINCT CARE_DIARY_REPORT FROM #CHANGED_SERV_SDU) forUpdate
    INNER JOIN CARE_DIARY_REPORT report
        ON report.A_OUID = forUpdate.CARE_DIARY_REPORT

--------------------------------------------------------------------------------------------------------------------------------

--Очистка измененынх данных.
DELETE FROM #FOR_REPORT

--Те отчеты, у которых не снялся флаг, так же пересчитываем, но уже полностью.
INSERT INTO #FOR_REPORT (CARE_DIARY_REPORT, FOR_DATE, COUNT_PERFORM)
SELECT
    report.A_OUID                                   AS CARE_DIARY_REPORT,
    planOnDay.DATE                                  AS FOR_DATE,
    SUM(CONVERT(INT, ISNULL(planOnDay.PERFORM, 0))) AS COUNT_PERFORM
FROM CARE_DIARY_REPORT report
----План предоставления услуг на дату.
    INNER JOIN CARE_DIARY_PLAN_ON_DAY planOnDay
        ON planOnDay.CARE_DIARY_REPORT = report.A_OUID
            AND planOnDay.A_STATUS = 10
WHERE report.A_STATUS = 10
    AND ISNULL(report.CHANGED, 0) = 1
GROUP BY report.A_OUID, planOnDay.DATE
ORDER BY report.A_OUID 

--Проход по всем дням.
SET @numberDay = 1
WHILE @numberDay <= 31 BEGIN
        SET @query = '
            UPDATE report
            SET report.DAY_' + CONVERT(VARCHAR, @numberDay) + '_PERFORM = forUpdate.COUNT_PERFORM
            FROM #FOR_REPORT forUpdate
                INNER JOIN CARE_DIARY_REPORT report
                    ON report.A_OUID = forUpdate.CARE_DIARY_REPORT
            WHERE DAY(forUpdate.FOR_DATE) = '  + CONVERT(VARCHAR, @numberDay)
        EXEC SP_EXECUTESQL @query
    SET @numberDay = @numberDay + 1
END

UPDATE report
SET report.CHANGED = 0
OUTPUT inserted.CARE_DIARY_OUID, inserted.A_OUID, inserted.YEAR, inserted.MONTH INTO #REPORT_UPDATED (CARE_DIARY_OUID, REPORT_OUID, YEAR, MONTH)
FROM (SELECT DISTINCT CARE_DIARY_REPORT FROM #FOR_REPORT) forUpdate
    INNER JOIN CARE_DIARY_REPORT report
        ON report.A_OUID = forUpdate.CARE_DIARY_REPORT

--------------------------------------------------------------------------------------------------------------------------------

--Шапка по всем услугам в месяце.
UPDATE title
SET title.DAY_1_PERFORM  = grouped.DAY_1_PERFORM,
    title.DAY_2_PERFORM  = grouped.DAY_2_PERFORM,
    title.DAY_3_PERFORM  = grouped.DAY_3_PERFORM,
    title.DAY_4_PERFORM  = grouped.DAY_4_PERFORM,
    title.DAY_5_PERFORM  = grouped.DAY_5_PERFORM,
    title.DAY_6_PERFORM  = grouped.DAY_6_PERFORM,
    title.DAY_7_PERFORM  = grouped.DAY_7_PERFORM,
    title.DAY_8_PERFORM  = grouped.DAY_8_PERFORM,
    title.DAY_9_PERFORM  = grouped.DAY_9_PERFORM,
    title.DAY_10_PERFORM = grouped.DAY_10_PERFORM,
    title.DAY_11_PERFORM = grouped.DAY_11_PERFORM,
    title.DAY_12_PERFORM = grouped.DAY_12_PERFORM,
    title.DAY_13_PERFORM = grouped.DAY_13_PERFORM,
    title.DAY_14_PERFORM = grouped.DAY_14_PERFORM,
    title.DAY_15_PERFORM = grouped.DAY_15_PERFORM,
    title.DAY_16_PERFORM = grouped.DAY_16_PERFORM,
    title.DAY_17_PERFORM = grouped.DAY_17_PERFORM,
    title.DAY_18_PERFORM = grouped.DAY_18_PERFORM,
    title.DAY_19_PERFORM = grouped.DAY_19_PERFORM,
    title.DAY_20_PERFORM = grouped.DAY_20_PERFORM,
    title.DAY_21_PERFORM = grouped.DAY_21_PERFORM,
    title.DAY_22_PERFORM = grouped.DAY_22_PERFORM,
    title.DAY_23_PERFORM = grouped.DAY_23_PERFORM,
    title.DAY_24_PERFORM = grouped.DAY_24_PERFORM,
    title.DAY_25_PERFORM = grouped.DAY_25_PERFORM,
    title.DAY_26_PERFORM = grouped.DAY_26_PERFORM,
    title.DAY_27_PERFORM = grouped.DAY_27_PERFORM,
    title.DAY_28_PERFORM = grouped.DAY_28_PERFORM,
    title.DAY_29_PERFORM = grouped.DAY_29_PERFORM,
    title.DAY_30_PERFORM = grouped.DAY_30_PERFORM,
    title.DAY_31_PERFORM = grouped.DAY_31_PERFORM,
    title.COUNT_PERFORM_INSERTED = grouped.COUNT_PERFORM_CALCULATED,
    title.TIME_PERFORM_INSERTED  = grouped.TIME_PERFORM_CALCULATED
FROM CARE_DIARY_REPORT title
    INNER JOIN (
        SELECT
            updated.CARE_DIARY_OUID, 
            updated.YEAR, 
            updated.MONTH,
            SUM(COUNT_PERFORM_CALCULATED)   AS COUNT_PERFORM_CALCULATED,
            SUM(TIME_PERFORM_CALCULATED)    AS TIME_PERFORM_CALCULATED,
            --Функция SUM игнорирует NULl, поэтому на NULL не проверяем для производительности.
            SUM(DAY_1_PERFORM)  AS DAY_1_PERFORM,  SUM(DAY_2_PERFORM)  AS DAY_2_PERFORM,  SUM(DAY_3_PERFORM)  AS DAY_3_PERFORM, 
            SUM(DAY_4_PERFORM)  AS DAY_4_PERFORM,  SUM(DAY_5_PERFORM)  AS DAY_5_PERFORM,  SUM(DAY_6_PERFORM)  AS DAY_6_PERFORM, 
            SUM(DAY_7_PERFORM)  AS DAY_7_PERFORM,  SUM(DAY_8_PERFORM)  AS DAY_8_PERFORM,  SUM(DAY_9_PERFORM)  AS DAY_9_PERFORM, 
            SUM(DAY_10_PERFORM) AS DAY_10_PERFORM, SUM(DAY_11_PERFORM) AS DAY_11_PERFORM, SUM(DAY_12_PERFORM) AS DAY_12_PERFORM, 
            SUM(DAY_13_PERFORM) AS DAY_13_PERFORM, SUM(DAY_14_PERFORM) AS DAY_14_PERFORM, SUM(DAY_15_PERFORM) AS DAY_15_PERFORM,
            SUM(DAY_16_PERFORM) AS DAY_16_PERFORM, SUM(DAY_17_PERFORM) AS DAY_17_PERFORM, SUM(DAY_18_PERFORM) AS DAY_18_PERFORM,
            SUM(DAY_19_PERFORM) AS DAY_19_PERFORM, SUM(DAY_20_PERFORM) AS DAY_20_PERFORM, SUM(DAY_21_PERFORM) AS DAY_21_PERFORM,
            SUM(DAY_22_PERFORM) AS DAY_22_PERFORM, SUM(DAY_23_PERFORM) AS DAY_23_PERFORM, SUM(DAY_24_PERFORM) AS DAY_24_PERFORM,
            SUM(DAY_25_PERFORM) AS DAY_25_PERFORM, SUM(DAY_26_PERFORM) AS DAY_26_PERFORM, SUM(DAY_27_PERFORM) AS DAY_27_PERFORM,
            SUM(DAY_28_PERFORM) AS DAY_28_PERFORM, SUM(DAY_29_PERFORM) AS DAY_29_PERFORM, SUM(DAY_30_PERFORM) AS DAY_30_PERFORM,
            SUM(DAY_31_PERFORM) AS DAY_31_PERFORM
        FROM (SELECT DISTINCT CARE_DIARY_OUID, YEAR, MONTH FROM #REPORT_UPDATED) updated
            INNER JOIN CARE_DIARY_REPORT report
                ON report.CARE_DIARY_OUID = updated.CARE_DIARY_OUID
                    AND report.YEAR = updated.YEAR
                    AND report.MONTH = updated.MONTH
                    AND report.A_STATUS = 10
                    AND report.ROW_TYPE = 2
        GROUP BY updated.CARE_DIARY_OUID, updated.YEAR, updated.MONTH
    ) grouped
        ON grouped.CARE_DIARY_OUID = title.CARE_DIARY_OUID
            AND grouped.YEAR = title.YEAR
            AND grouped.MONTH = title.MONTH
WHERE title.ROW_TYPE = 1
    AND title.A_STATUS = 10

--------------------------------------------------------------------------------------------------------------------------------