--------------------------------------------------------------------------------------------------------------------------------

/*
Перенос информации об оказании услуг из дневника в назначение:
    1. Сбор информации из дневника ухода, сгруппированные по назначениям, услугам, по дням и по сотрудникам.
    2. Для выбранных записей выбираются агрегации услуг из назначений.
    3. Из выбранных агрегаций выбираются ежедневные отчеты за нужные годы и месяцы по 1. выборке, сгруппированные по назначениям, услугам, по дням и по сотрудникам.
    4. Удаляются те записи из выборки по дневнику и назначению, которые полностью совпадают (по сотруднику и по количеству).
    5. Те записи, которые остались в выборке из назначения удаляются.
    6. Те записи, которые остались в выборке из дневнкиа ухода вставляются в назначение, при этом вставляется еще период в агрегации, если отсутствует.
    7. Производится перерасчет итоговых таблиц в назначениях с вставкой недостающих записей и удалением лишних.
*/

--------------------------------------------------------------------------------------------------------------------------------

--Удаление временных таблиц.
IF OBJECT_ID('tempdb..#FROM_CARE_DIARY_GROUPED')    IS NOT NULL BEGIN DROP TABLE #FROM_CARE_DIARY_GROUPED       END --Сгруппированные данные из ежедневного плана по назначению, услуге, дню и работнику.
IF OBJECT_ID('tempdb..#FROM_SOC_SERV_AGR')          IS NOT NULL BEGIN DROP TABLE #FROM_SOC_SERV_AGR             END --Сопоставленные агрегации для данных из дневника.
IF OBJECT_ID('tempdb..#FROM_SOC_SERV')              IS NOT NULL BEGIN DROP TABLE #FROM_SOC_SERV                 END --Данные из назначения.
IF OBJECT_ID('tempdb..#FROM_SOC_SERV_GROUPED')      IS NOT NULL BEGIN DROP TABLE #FROM_SOC_SERV_GROUPED         END --Сгруппированные данные по назначению, услуге, дню и работнику.
IF OBJECT_ID('tempdb..#FOR_DELETE_FROM_SOC_SERV')   IS NOT NULL BEGIN DROP TABLE #FOR_DELETE_FROM_SOC_SERV      END --Несовпадающие записи для удаления из назначения.
IF OBJECT_ID('tempdb..#CREATEAD_PERIOD_FOR_SERV')   IS NOT NULL BEGIN DROP TABLE #CREATEAD_PERIOD_FOR_SERV      END --Созданные агрегации услуги по периоду.
IF OBJECT_ID('tempdb..#SOC_SERV_FOR_RECALCULATION') IS NOT NULL BEGIN DROP TABLE #SOC_SERV_FOR_RECALCULATION    END --Назначения для перерасчета агрегаций.
IF OBJECT_ID('tempdb..#COUNT_SERV_GROUPED_BY_EACH') IS NOT NULL BEGIN DROP TABLE #COUNT_SERV_GROUPED_BY_EACH    END --Количество оказанных услуг в месяц, которые сгруппированы в рамках каждой услуги в назначении.
IF OBJECT_ID('tempdb..#COUNT_SERV_GROUPED_BY_ALL')  IS NOT NULL BEGIN DROP TABLE #COUNT_SERV_GROUPED_BY_ALL     END --Количество оказанных услуг в месяц, которые сгруппированы в рамках всех услуг в назначении.

--------------------------------------------------------------------------------------------------------------------------------

--Создание временных таблиц.
CREATE TABLE #FROM_CARE_DIARY_GROUPED (
    SOC_SERV_OUID       INT,            --Идентификатор назначения для вставки.
    SERV_TYPE           INT,            --Услуга.
    PERFORM_DATE        DATE,           --Дата оказания услуги.
    PERFORM_COUNT       INT,            --Количество оказанных услуг.
    PERFORM_TIME        INT,            --Время оказания услгуи.
    EMPLOYEE_OUID       INT,            --Идентификатор сотрудника.
    IN_BOTH_PLACES      INT,            --Флаг наличия соответствующей записи в назначении.
    LINK_TO_AGR_OUID    INT,            --Ссылка на агрегацию в назначении по услуге, которой соответствует запись.
    LINK_TO_COUNT_OUID  INT,            --Ссылка на агнегацию в назначении по периоду, которой соответствует запись.
)
CREATE TABLE #FROM_SOC_SERV_AGR (
    SOC_SERV_OUID       INT,            --Идентификатор назначения для вставки.
    SERV_TYPE           INT,            --Услуга.
    PERFORM_YEAR        INT,            --Год оказания услуги.
    PERFORM_MONTH       INT,            --Месяц оказания услуги.
    AGR_OUID            INT,            --Сопоставленная агрегация.
)
CREATE TABLE #FROM_SOC_SERV (
    SOC_SERV_OUID       INT,    --Идентификатор назначения для вставки.
    SERV_TYPE           INT,    --Услуга.
    AGR_OUID            INT,    --Агрегация по услуге.
    PERIOD_OUID         INT,    --Агрегация по периоду.
    DAY_OUID            INT,    --Данные за день.
    DAY_DATE            DATE,   --Дата оказания услуги.
    DAY_COUNT           INT,    --Количество оказанных услуг.
    DAY_TIME            INT,    --Время оказания услгуи.
    DAY_EMPLOYEE_OUID   INT,    --Идентификатор сотрудника.
)
CREATE TABLE #FROM_SOC_SERV_GROUPED (
    SOC_SERV_OUID   INT,    --Идентификатор назначения для вставки.
    SERV_TYPE       INT,    --Услуга.
    PERFORM_DATE    DATE,   --Дата оказания услуги.
    PERFORM_COUNT   INT,    --Количество оказанных услуг.
    PERFORM_TIME    INT,    --Время оказания услгуи.
    EMPLOYEE_OUID   INT,    --Идентификатор сотрудника.
    IN_BOTH_PLACES  BIT     --Флаг наличия соответствующей записи в дневнике ухода.
)
CREATE TABLE #FOR_DELETE_FROM_SOC_SERV (
    OUID    INT, --Идентифкатор.
)
CREATE TABLE #CREATEAD_PERIOD_FOR_SERV (
    OUID        INT,    --Идентификатор записи.
    AGR_OUID    INT,    --Идентификатор агрегации по услуге.
    DATE_START  DATE,   --Дата начала периода.
    DATE_END    DATE,   --Дата окончания периода.
)
CREATE TABLE #SOC_SERV_FOR_RECALCULATION (
    SOC_SERV_OUID   INT,    --Идентификатор назначения.
    YEAR            INT,    --Год пересчета.
    MONTH           INT     --Месяц пересчета.
)
CREATE TABLE #COUNT_SERV_GROUPED_BY_EACH (
    SOC_SERV_OUID   INT,    --Идентификатор назначения.
    AGR_OUID        INT,    --Идентификатор агрегации.
    PERIOD_YEAR     INT,    --Год.
    PERIOD_MONTH    INT,    --Месяц.
    SERV_HOURS      FLOAT,  --Затраченные доли часов.
    SERV_MINUTES    INT,    --Количество затраченные минут.
    SERV_COUNT      INT,    --Количество услуг.
)
CREATE TABLE #COUNT_SERV_GROUPED_BY_ALL (
    SOC_SERV_OUID   INT,    --Идентификатор назначения.
    PERIOD_YEAR     INT,    --Год.
    PERIOD_MONTH    INT,    --Месяц.
    SERV_HOURS      FLOAT,  --Затраченные доли часов.
    SERV_MINUTES    INT,    --Количество затраченные минут.
    SERV_COUNT      INT,    --Количество услуг.
)

------------------------------------------------------------------------------------------------------------------------------

--Константы.
DECLARE @activeStatus       INT = (SELECT A_ID FROM ESRN_SERV_STATUS WHERE A_STATUSCODE = 'act')    --Статус действующей (не удаленной) записи.
DECLARE @deleteStatus       INT = (SELECT A_ID FROM ESRN_SERV_STATUS WHERE A_STATUSCODE = 'delete') --Статус удаленной записи.
DECLARE @docTypeCareDiary   INT = (SELECT A_ID FROM PPR_DOC WHERE A_CODE = 'CareDiary')             --Идентификатор типа документа дневника ухода.
DECLARE @dailyReportClass   INT = (SELECT OUID FROM SXCLASS WHERE NAME = 'SocWorkEmploymentSDU')    --Занятость социальных работников (СДУ).
DECLARE @countSocServClass  INT = (SELECT OUID FROM SXCLASS WHERE NAME = 'wmCountSocServ')          --Количество (часов) социальных услуг СДУ.

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--///////////////////////////////////////////////////////Сбор и сравнение данных////////////////////////////////////////////////////////////////////////////////////////////
--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--Выбор данных из дневнкиа ухода.
INSERT INTO #FROM_CARE_DIARY_GROUPED (SOC_SERV_OUID, SERV_TYPE, PERFORM_DATE, PERFORM_COUNT, PERFORM_TIME, EMPLOYEE_OUID, IN_BOTH_PLACES, LINK_TO_AGR_OUID, LINK_TO_COUNT_OUID)
SELECT
    socServ.OUID                                                            AS SOC_SERV_OUID,
    report.SERV_SDU                                                         AS SERV_TYPE,
    CONVERT(DATE, planOnDay.DATE)                                           AS PERFORM_DATE,
    SUM(CONVERT(INT, ISNULL(planOnDay.PERFORM, 0)))                         AS PERFORM_COUNT,
    SUM(CONVERT(INT, ISNULL(planOnDay.PERFORM, 0))) * report.EXECUTE_TIME   AS PERFORM_TIME,
    ISNULL(planOnDay.EMPLOYEE, 0)                                           AS EMPLOYEE_OUID,
    0                                                                       AS IN_BOTH_PLACES,
    NULL                                                                    AS LINK_TO_AGR_OUID, --Вставляется только в записи перед вставкой.
    NULL                                                                    AS LINK_TO_COUNT_OUID --Вставляется только в записи перед вставкой.
FROM CARE_DIARY_PLAN_ON_DAY planOnDay --План предоставления услуг на дату.
----План-отчет предоставления услуг СДУ из дневника ухода.
    INNER JOIN CARE_DIARY_REPORT report
        ON report.A_OUID = planOnDay.CARE_DIARY_REPORT
            AND report.A_STATUS = @activeStatus
----Дневник ухода гражданина, нуждающегося в уходе.
    INNER JOIN CARE_DIARY careDiary
        ON careDiary.A_OUID = planOnDay.CARE_DIARY_OUID
            AND careDiary.A_STATUS = @activeStatus
----Назначение социального обслуживания.
    INNER JOIN ESRN_SOC_SERV socServ
        ON socServ.OUID = careDiary.SOC_SERV
            AND socServ.A_STATUS = @activeStatus
WHERE planOnDay.A_STATUS = @activeStatus
    AND CONVERT(DATE, planOnDay.DATE) >= CONVERT(DATE, '01-09-2023')
GROUP BY socServ.OUID, report.SERV_SDU, CONVERT(DATE, planOnDay.DATE), report.EXECUTE_TIME, ISNULL(planOnDay.EMPLOYEE, 0)

------------------------------------------------------------------------------------------------------------------------------

--Выбор агрегаций для услуг из дневника ухода.
INSERT INTO #FROM_SOC_SERV_AGR (SOC_SERV_OUID, SERV_TYPE, PERFORM_YEAR, PERFORM_MONTH, AGR_OUID)
SELECT
    periodChoosed.SOC_SERV_OUID     AS SOC_SERV_OUID,
    periodChoosed.SERV_TYPE         AS SERV_TYPE,
    periodChoosed.PERFORM_YEAR      AS PERFORM_YEAR,
    periodChoosed.PERFORM_MONTH     AS PERFORM_MONTH,
    AGR.A_ID                        AS AGR_OUID
FROM (
    SELECT DISTINCT
        SOC_SERV_OUID       AS SOC_SERV_OUID,
        SERV_TYPE           AS SERV_TYPE,
        YEAR(PERFORM_DATE)  AS PERFORM_YEAR,
        MONTH(PERFORM_DATE) AS PERFORM_MONTH
    FROM #FROM_CARE_DIARY_GROUPED
) periodChoosed
----Агрегация по социальной услуге СДУ.
    INNER JOIN WM_SOC_SERV_AGR_SDU AGR
        ON AGR.ESRN_SOC_SERV = periodChoosed.SOC_SERV_OUID
            AND AGR.A_STATUS = @activeStatus
----Тарифы на социальные услуги.
    INNER JOIN SPR_TARIF_SOC_SERV tarif
        ON tarif.A_ID = AGR.A_SOC_SERV
            AND tarif.A_SOC_SERV = periodChoosed.SERV_TYPE
            AND tarif.A_STATUS = @activeStatus

------------------------------------------------------------------------------------------------------------------------------

--Выбор данных из назначений, соответствующим выбранным данным из дневника за выбранные периоды и выбранные услуги.
INSERT INTO #FROM_SOC_SERV (SOC_SERV_OUID, SERV_TYPE, AGR_OUID, PERIOD_OUID, DAY_OUID, DAY_DATE, DAY_COUNT, DAY_TIME, DAY_EMPLOYEE_OUID)
SELECT
    fromSocServ.SOC_SERV_OUID                   AS SOC_SERV_OUID,
    fromSocServ.SERV_TYPE                       AS SERV_TYPE,
    fromSocServ.AGR_OUID                        AS AGR_OUID,
    countSocServ.A_ID                           AS PERIOD_OUID,
    dailyReport.A_OUID                          AS DAY_OUID,
    CONVERT(DATE, dailyReport.A_DATE)           AS DAY_DATE,
    ISNULL(dailyReport.A_SERV_COUNT_NUMBER, 0)  AS DAY_COUNT,
    ISNULL(dailyReport.A_SERV_COUNT_MINUTES, 0) AS DAY_TIME,
    ISNULL(dailyReport.A_SOC_WORKER, 0)         AS DAY_EMPLOYEE_OUID
FROM #FROM_SOC_SERV_AGR fromSocServ
----Количество (часов) социальных услуг СДУ.
    INNER JOIN WM_COUNT_SOC_SERV countSocServ
        ON countSocServ.A_AGR_SOC_SERV = fromSocServ.AGR_OUID
            AND countSocServ.A_STATUS = @activeStatus
----Занятость социальных работников (СДУ).
    INNER JOIN SOC_WORK_EMPLOYMENT_SDU dailyReport
        ON dailyReport.A_SERV_COST = countSocServ.A_ID
            AND dailyReport.A_STATUS = @activeStatus
            AND fromSocServ.PERFORM_YEAR = YEAR(dailyReport.A_DATE)
            AND fromSocServ.PERFORM_MONTH = MONTH(dailyReport.A_DATE)

------------------------------------------------------------------------------------------------------------------------------

--Группировка данных по назначению, услуге, дню и работнику.
INSERT INTO #FROM_SOC_SERV_GROUPED (SOC_SERV_OUID, SERV_TYPE, PERFORM_DATE, PERFORM_COUNT, PERFORM_TIME, EMPLOYEE_OUID, IN_BOTH_PLACES)
SELECT
    fromSocServ.SOC_SERV_OUID       AS SOC_SERV_OUID,
    fromSocServ.SERV_TYPE           AS SERV_TYPE,
    fromSocServ.DAY_DATE            AS PERFORM_DATE,
    SUM(fromSocServ.DAY_COUNT)      AS PERFORM_COUNT,
    SUM(fromSocServ.DAY_TIME)       AS PERFORM_TIME,
    fromSocServ.DAY_EMPLOYEE_OUID   AS EMPLOYEE_OUID,
    0                               AS IN_BOTH_PLACES
FROM #FROM_SOC_SERV fromSocServ
GROUP BY fromSocServ.SOC_SERV_OUID, fromSocServ.SERV_TYPE, fromSocServ.DAY_DATE, fromSocServ.DAY_EMPLOYEE_OUID

------------------------------------------------------------------------------------------------------------------------------

--Простановка флагов наличия совпадения в обоих местах.
UPDATE fromCareDiary
SET fromCareDiary.IN_BOTH_PLACES = 1
FROM #FROM_CARE_DIARY_GROUPED fromCareDiary  --Из дневника.
----Из назначения.
    INNER JOIN #FROM_SOC_SERV_GROUPED fromSocServ 
        ON fromSocServ.SOC_SERV_OUID = fromCareDiary.SOC_SERV_OUID
            AND fromSocServ.SERV_TYPE = fromCareDiary.SERV_TYPE
            AND fromSocServ.PERFORM_DATE = fromCareDiary.PERFORM_DATE
            AND fromSocServ.PERFORM_COUNT = fromCareDiary.PERFORM_COUNT
            AND fromSocServ.PERFORM_TIME = fromCareDiary.PERFORM_TIME
            AND fromSocServ.EMPLOYEE_OUID = fromCareDiary.EMPLOYEE_OUID

--Простановка флагов наличия совпадения в обоих местах.
UPDATE fromSocServ
SET fromSocServ.IN_BOTH_PLACES = 1
FROM #FROM_SOC_SERV_GROUPED fromSocServ --Из назначения.
----Из дневника.
    INNER JOIN #FROM_CARE_DIARY_GROUPED fromCareDiary 
        ON fromCareDiary.SOC_SERV_OUID = fromSocServ.SOC_SERV_OUID
            AND fromCareDiary.SERV_TYPE = fromSocServ.SERV_TYPE
            AND fromCareDiary.PERFORM_DATE = fromSocServ.PERFORM_DATE
            AND fromCareDiary.PERFORM_COUNT = fromSocServ.PERFORM_COUNT
            AND fromCareDiary.PERFORM_TIME = fromSocServ.PERFORM_TIME
            AND fromCareDiary.EMPLOYEE_OUID = fromSocServ.EMPLOYEE_OUID

------------------------------------------------------------------------------------------------------------------------------

--Убираем записи, которые есть в обоих местах или которые пустые.
DELETE FROM #FROM_CARE_DIARY_GROUPED
WHERE IN_BOTH_PLACES = 1
    OR PERFORM_COUNT = 0

--Убираем записи, которые есть в обоих местах.
DELETE FROM #FROM_SOC_SERV_GROUPED
WHERE IN_BOTH_PLACES = 1

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--///////////////////////////////////////////////////////Вставка и корректировка данных/////////////////////////////////////////////////////////////////////////////////////
--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--Выбираем записи по услугам за дни, которые не совпадают с дневником.
INSERT INTO #FOR_DELETE_FROM_SOC_SERV (OUID)
SELECT DISTINCT 
    fromSocServ.DAY_OUID
FROM (
    SELECT DISTINCT
        SOC_SERV_OUID, 
        SERV_TYPE, 
        PERFORM_DATE,
        EMPLOYEE_OUID
    FROM #FROM_SOC_SERV_GROUPED fromSocServ
    WHERE fromSocServ.IN_BOTH_PLACES = 0
) forDelete 
    INNER JOIN #FROM_SOC_SERV fromSocServ
        ON fromSocServ.SOC_SERV_OUID = forDelete.SOC_SERV_OUID
            AND fromSocServ.SERV_TYPE = forDelete.SERV_TYPE
            AND fromSocServ.DAY_DATE = forDelete.PERFORM_DATE
            AND fromSocServ.DAY_EMPLOYEE_OUID = forDelete.EMPLOYEE_OUID

------------------------------------------------------------------------------------------------------------------------------

--Удаление лишних строк.
UPDATE dailyReport
SET dailyReport.A_STATUS    = @deleteStatus,
    dailyReport.A_EDITOWNER = NULL,
    dailyReport.A_TS        = GETDATE()
FROM #FOR_DELETE_FROM_SOC_SERV forDelete --Записи для удаления.
----Занятость социальных работников (СДУ).
    INNER JOIN SOC_WORK_EMPLOYMENT_SDU dailyReport
        ON dailyReport.A_OUID = forDelete.OUID

------------------------------------------------------------------------------------------------------------------------------

--Вставка агрегаций услуги, в которые должны происходить записи.
UPDATE fromCareDiary
SET fromCareDiary.LINK_TO_AGR_OUID = fromSocServ.AGR_OUID
FROM #FROM_CARE_DIARY_GROUPED fromCareDiary --Дневник ухода.
    INNER JOIN #FROM_SOC_SERV_AGR fromSocServ
        ON fromSocServ.SOC_SERV_OUID = fromCareDiary.SOC_SERV_OUID
            AND fromSocServ.SERV_TYPE = fromCareDiary.SERV_TYPE
            AND fromSocServ.PERFORM_YEAR = YEAR(fromCareDiary.PERFORM_DATE)
            AND fromSocServ.PERFORM_MONTH = MONTH(fromCareDiary.PERFORM_DATE)

            
--Вставка агрегаций периодов, в которые должны происходить записи.
UPDATE fromCareDiary
SET fromCareDiary.LINK_TO_COUNT_OUID = countSocServ.A_ID
FROM #FROM_CARE_DIARY_GROUPED fromCareDiary --Дневник ухода.
----Количество (часов) социальных услуг СДУ.
    INNER JOIN WM_COUNT_SOC_SERV countSocServ
        ON countSocServ.A_AGR_SOC_SERV = fromCareDiary.LINK_TO_AGR_OUID
            AND countSocServ.A_STATUS = @activeStatus
            AND dbo.fs_isDateInPeriod(fromCareDiary.PERFORM_DATE, countSocServ.A_DATE_START, countSocServ.A_DATE_LAST) = 1

------------------------------------------------------------------------------------------------------------------------------

--Вставляем период по услуге, если его нет.
INSERT INTO WM_COUNT_SOC_SERV (A_STATUS, GUID, SYSTEMCLASS, A_CREATEDATE, A_AGR_SOC_SERV, A_DATE_START, A_DATE_LAST, A_ACT_QUANT_SERVS, A_ACT_QUANT, A_ACT_QUANT_MINUTES, A_COMMENT)
OUTPUT inserted.A_ID, inserted.A_AGR_SOC_SERV, inserted.A_DATE_START, inserted.A_DATE_LAST INTO #CREATEAD_PERIOD_FOR_SERV(OUID, AGR_OUID, DATE_START, DATE_END)
SELECT
    @activeStatus                                                       AS A_STATUS,
    NEWID()                                                             AS GUID,
    @countSocServClass                                                  AS SYSTEMCLASS,
    GETDATE()                                                           AS A_CREATEDATE,
    LINK_TO_AGR_OUID                                                    AS A_AGR_SOC_SERV,
    DATE_START                                                          AS A_DATE_START,        --Дата начала периода
    DATE_END                                                            AS A_DATE_LAST,         --Дата окончания периода
    PERFORM_COUNT                                                       AS A_ACT_QUANT_SERVS,   --Количество оказанных услуг
    PERFROM_TIME_HOURS_PART                                             AS A_ACT_QUANT,         --Количество часов оказания услуги в месяц (доли часов)
    PERFORM_TIME_MINUTES                                                AS A_ACT_QUANT_MINUTES, --Количество минут оказания услуги в месяц
    'Загружено из дневника ухода ' + CONVERT(VARCHAR, GETDATE(), 104)   AS A_COMMENT            --Примечание
FROM (  
    SELECT
        LINK_TO_AGR_OUID                                                    AS LINK_TO_AGR_OUID,
        dbo.fs_getFirstDayOfMonth(YEAR(PERFORM_DATE), MONTH(PERFORM_DATE))  AS DATE_START,
        dbo.fs_getLastDayOfMonth(YEAR(PERFORM_DATE), MONTH(PERFORM_DATE))   AS DATE_END,
        SUM(PERFORM_COUNT)                                                  AS PERFORM_COUNT,
        SUM(PERFORM_TIME)                                                   AS PERFORM_TIME_MINUTES,
        SUM(CONVERT(FLOAT, PERFORM_TIME)) / 60.0                            AS PERFROM_TIME_HOURS_PART
    FROM #FROM_CARE_DIARY_GROUPED
    WHERE LINK_TO_COUNT_OUID IS NULL
        AND LINK_TO_AGR_OUID IS NOT NULL
    GROUP BY LINK_TO_AGR_OUID, 
        dbo.fs_getFirstDayOfMonth(YEAR(PERFORM_DATE), MONTH(PERFORM_DATE)), 
        dbo.fs_getLastDayOfMonth(YEAR(PERFORM_DATE), MONTH(PERFORM_DATE))
) periodGrouped

--Подвязка созданных записей.
UPDATE fromCareDiary
SET fromCareDiary.LINK_TO_COUNT_OUID = created.OUID
FROM #FROM_CARE_DIARY_GROUPED fromCareDiary
    INNER JOIN #CREATEAD_PERIOD_FOR_SERV created
        ON created.AGR_OUID = fromCareDiary.LINK_TO_AGR_OUID
            AND dbo.fs_isDateInPeriod(fromCareDiary.PERFORM_DATE, created.DATE_START, created.DATE_END) = 1
WHERE fromCareDiary.LINK_TO_COUNT_OUID IS NULL

------------------------------------------------------------------------------------------------------------------------------

--Вставка услуг, которые есть в дневнике, но которых нет в назначении.
INSERT INTO SOC_WORK_EMPLOYMENT_SDU (GUID, A_CREATEDATE, A_CROWNER, A_SYSTEMCLASS, A_STATUS, A_DATE ,A_SERV_COUNT_NUMBER, A_SERV_COUNT_MINUTES, A_SOC_WORKER, A_SERV_COUNT, A_SERV_COST)
SELECT
    NEWID()                                             AS GUID,
    GETDATE()                                           AS A_CREATEDATE,
    10314303                                            AS A_CROWNER,
    @dailyReportClass                                   AS A_SYSTEMCLASS,
    @activeStatus                                       AS A_STATUS,
    fromCareDiary.PERFORM_DATE                          AS A_DATE,
    fromCareDiary.PERFORM_COUNT                         AS A_SERV_COUNT_NUMBER,
    fromCareDiary.PERFORM_TIME                          AS A_SERV_COUNT_MINUTES,
    fromCareDiary.EMPLOYEE_OUID                         AS A_SOC_WORKER,
    CONVERT(FLOAT, fromCareDiary.PERFORM_TIME) / 60.0   AS A_SERV_COUNT, --Время в долях часа.
    fromCareDiary.LINK_TO_COUNT_OUID                    AS A_SERV_COST
FROM #FROM_CARE_DIARY_GROUPED fromCareDiary
WHERE fromCareDiary.IN_BOTH_PLACES = 0

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--///////////////////////////////////////////////////////Пересчет итоговых таблиц в назначении//////////////////////////////////////////////////////////////////////////////
--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--Выбор назначений для перерасчета.
INSERT INTO #SOC_SERV_FOR_RECALCULATION (SOC_SERV_OUID, YEAR, MONTH)
SELECT DISTINCT 
    SOC_SERV_OUID       AS SOC_SERV_OUID, 
    YEAR(PERFORM_DATE)  AS YEAR, 
    MONTH(PERFORM_DATE) AS MONTH 
FROM #FROM_CARE_DIARY_GROUPED 
WHERE IN_BOTH_PLACES = 0
UNION
SELECT DISTINCT 
    SOC_SERV_OUID       AS SOC_SERV_OUID, 
    YEAR(PERFORM_DATE)  AS YEAR, 
    MONTH(PERFORM_DATE) AS MONTH
FROM #FROM_SOC_SERV_GROUPED 
WHERE IN_BOTH_PLACES = 0

------------------------------------------------------------------------------------------------------------------------------

--Количество оказанных услуг в месяц, которые сгруппированы в рамках каждой услуги в назначении.
INSERT INTO #COUNT_SERV_GROUPED_BY_EACH (SOC_SERV_OUID, AGR_OUID, PERIOD_YEAR, PERIOD_MONTH, SERV_HOURS, SERV_MINUTES, SERV_COUNT)
SELECT
    forRecalculation.SOC_SERV_OUID              AS SOC_SERV_OUID,
    AGR.A_ID                                    AS AGR_OUID,
    forRecalculation.YEAR                       AS PERIOD_YEAR,
    forRecalculation.MONTH                      AS PERIOD_MONTH,
    SUM(servCountInPeriod.A_ACT_QUANT)          AS SERV_HOURS,
    SUM(servCountInPeriod.A_ACT_QUANT_MINUTES)  AS SERV_MINUTES,
    SUM(servCountInPeriod.A_ACT_QUANT_SERVS)    AS SERV_COUNT   
FROM #SOC_SERV_FOR_RECALCULATION forRecalculation --Назначения для перерасчета.
----Агрегация по социальной услуге СДУ.
    INNER JOIN WM_SOC_SERV_AGR_SDU AGR
        ON AGR.ESRN_SOC_SERV = forRecalculation.SOC_SERV_OUID
            AND AGR.A_STATUS = @activeStatus
----Количество (часов) социальных услуг СДУ.
    INNER JOIN WM_COUNT_SOC_SERV servCountInPeriod
        ON servCountInPeriod.A_AGR_SOC_SERV = AGR.A_ID
            AND servCountInPeriod.A_STATUS = @activeStatus 
            AND YEAR(CONVERT(DATE, servCountInPeriod.A_DATE_START)) = forRecalculation.YEAR 
            AND MONTH(CONVERT(DATE, servCountInPeriod.A_DATE_START)) = forRecalculation.MONTH 
GROUP BY forRecalculation.SOC_SERV_OUID, AGR.A_ID, forRecalculation.YEAR , forRecalculation.MONTH

--Количество оказанных услуг в месяц, которые сгруппированы в рамках всех услуг в назначении.
INSERT INTO #COUNT_SERV_GROUPED_BY_ALL (SOC_SERV_OUID, PERIOD_YEAR, PERIOD_MONTH, SERV_HOURS, SERV_MINUTES, SERV_COUNT)
SELECT
    servCount.SOC_SERV_OUID                 AS SOC_SERV_OUID, 
    servCount.PERIOD_YEAR                   AS PERIOD_YEAR, 
    servCount.PERIOD_MONTH                  AS PERIOD_MONTH,
    SUM(servCount.SERV_MINUTES)* 1.00 / 60  AS SERV_HOURS,
    SUM(servCount.SERV_MINUTES)             AS SERV_MINUTES,
    SUM(servCount.SERV_COUNT)               AS SERV_COUNT
FROM #COUNT_SERV_GROUPED_BY_EACH servCount
GROUP BY servCount.SOC_SERV_OUID, servCount.PERIOD_YEAR, servCount.PERIOD_MONTH

---------------------------------------------------------------------------------------------------------------------------------------------
	
--Вставка агрегации услуги за месяц при ее отсутствии.
INSERT INTO WM_COUNT_SOC_SERV_MONTH(A_YEAR, A_MONTH, A_GUID, A_STATUS, A_CREATEDATE, A_CROWNER, A_AGR_SOC_SERV, A_COND_SOC_SERV, A_SOC_SERV_MONTH_NUMBER, A_SOC_SERV_MONTH, A_SOC_SERV_MONTH_MINUTES)
SELECT 
    countCalculated.PERIOD_YEAR     AS A_YEAR,
    countCalculated.PERIOD_MONTH    AS A_MONTH,
    NEWID()                         AS A_GUID,
    @activeStatus                   AS A_STATUS,
    GETDATE()                       AS A_CREATEDATE,
    10314303                        AS A_CROWNER,
    countCalculated.AGR_OUID        AS A_AGR_SOC_SERV,
    'free'                          AS A_COND_SOC_SERV,
    countCalculated.SERV_COUNT      AS A_SOC_SERV_MONTH_NUMBER,
    countCalculated.SERV_HOURS      AS A_SOC_SERV_MONTH,
    countCalculated.SERV_MINUTES    AS A_SOC_SERV_MONTH_MINUTES
FROM #COUNT_SERV_GROUPED_BY_EACH countCalculated --Количество услуг.
----Количество социальных услуг за месяц (СДУ)
    LEFT JOIN WM_COUNT_SOC_SERV_MONTH countMonth 
        ON countMonth.A_AGR_SOC_SERV = countCalculated.AGR_OUID 
            AND countMonth.A_YEAR = countCalculated.PERIOD_YEAR
            AND countMonth.A_MONTH = countCalculated.PERIOD_MONTH
            AND countMonth.A_STATUS = @activeStatus
WHERE countMonth.A_ID IS NULL

--Заполнение таблицы "Количество (часов) всех оказанных услуг за календарный месяц (СДУ)" 
INSERT INTO WM_FACT_COUNT_SOC_SERV(GUID,A_CREATEDATE, A_CROWNER, A_SUM_PERIOD, A_STATUS, A_YEAR, A_MONTH, ESRN_SOC_SERV, A_COND_SOC_SERV, A_SOC_COUNT, A_SOC_COUNT_NUMBER, A_SOC_COST_MONTH)
SELECT
    NEWID()                         AS GUID,
    GETDATE()                       AS A_CREATEDATE,
    10314303                        AS A_CROWNER,
    0                               AS A_SUM_PERIOD,
    @activeStatus                   AS A_STATUS,
    countCalculated.PERIOD_YEAR     AS A_YEAR,
    countCalculated.PERIOD_MONTH    AS A_MONTH,
    countCalculated.SOC_SERV_OUID   AS ESRN_SOC_SERV,
    'free'                          AS A_COND_SOC_SERV,
    countCalculated.SERV_HOURS      AS A_SOC_COUNT,
    countCalculated.SERV_COUNT      AS A_SOC_COUNT_NUMBER,
    0                               AS A_SOC_COST_MONTH
FROM #COUNT_SERV_GROUPED_BY_ALL countCalculated --Количество услуг.
----Количество (часов) всех оказанных услуг за месяц (СДУ)
    LEFT JOIN WM_FACT_COUNT_SOC_SERV countAll
        ON countAll.ESRN_SOC_SERV = countCalculated.SOC_SERV_OUID
            AND countAll.A_YEAR = countCalculated.PERIOD_YEAR
            AND countAll.A_MONTH = countCalculated.PERIOD_MONTH
            AND countAll.A_STATUS = @activeStatus
WHERE countAll.A_ID IS NULL

---------------------------------------------------------------------------------------------------------------------------------------------

--Обновление услуг за месяц в агрегации
UPDATE countMonth
SET countMonth.A_SOC_SERV_MONTH         = countCalculated.SERV_HOURS,
    countMonth.A_SOC_SERV_MONTH_MINUTES = countCalculated.SERV_MINUTES,
    countMonth.A_SOC_SERV_MONTH_NUMBER  = countCalculated.SERV_COUNT,
    countMonth.A_EDITOWNER              = 10314303,
    countMonth.A_TS                     = GETDATE()
FROM #COUNT_SERV_GROUPED_BY_EACH countCalculated --Количество услуг.
----Количество социальных услуг за месяц (СДУ).
    INNER JOIN WM_COUNT_SOC_SERV_MONTH countMonth
        ON countMonth.A_AGR_SOC_SERV = countCalculated.AGR_OUID
            AND countMonth.A_YEAR = countCalculated.PERIOD_YEAR
            AND countMonth.A_MONTH = countCalculated.PERIOD_MONTH
            AND countMonth.A_STATUS = @activeStatus
--Обновляем только различающиеся записи.
WHERE ISNULL(countMonth.A_SOC_SERV_MONTH, 0)  <> ISNULL(countCalculated.SERV_HOURS, 0)
    OR ISNULL(countMonth.A_SOC_SERV_MONTH_MINUTES, 0) <> ISNULL(countCalculated.SERV_MINUTES, 0)
    OR ISNULL(countMonth.A_SOC_SERV_MONTH_NUMBER, 0)  <> ISNULL(countCalculated.SERV_COUNT, 0)

--Обновление услуг за месяц в назначении.
UPDATE countAll
SET countAll.A_SOC_COUNT        = countCalculated.SERV_HOURS,
    countAll.A_SOC_COUNT_NUMBER = countCalculated.SERV_COUNT,
    countAll.A_EDITOWNER        = 10314303,
    countAll.TS                 = GETDATE()
FROM #COUNT_SERV_GROUPED_BY_ALL countCalculated --Количество услуг.
----Количество социальных услуг за месяц (СДУ).
    INNER JOIN WM_FACT_COUNT_SOC_SERV countAll
        ON countAll.ESRN_SOC_SERV = countCalculated.SOC_SERV_OUID
            AND countAll.A_YEAR = countCalculated.PERIOD_YEAR
            AND countAll.A_MONTH = countCalculated.PERIOD_MONTH
            AND countAll.A_STATUS = @activeStatus
WHERE ISNULL(countAll.A_SOC_COUNT, 0) <> ISNULL(countCalculated.SERV_HOURS, 0)
    OR ISNULL(countAll.A_SOC_COUNT_NUMBER, 0)  <> ISNULL(countCalculated.SERV_COUNT, 0)

---------------------------------------------------------------------------------------------------------------------------------------------

--Удаление строк количества услуг за месяц в агрегации, если в эти строки нечего вставить.
UPDATE countMonth
SET countMonth.A_STATUS     = @deleteStatus,
    countMonth.A_EDITOWNER  = 10314303,
    countMonth.A_TS         = GETDATE()
FROM (SELECT DISTINCT SOC_SERV_OUID, YEAR, MONTH FROM #SOC_SERV_FOR_RECALCULATION) forRecalculation --Назначения для перерасчета.
----Агрегация по социальной услуге СДУ
    INNER JOIN WM_SOC_SERV_AGR_SDU AGR
        ON AGR.ESRN_SOC_SERV = forRecalculation.SOC_SERV_OUID
            AND AGR.A_STATUS = @activeStatus
----Количество социальных услуг за месяц (СДУ).
    INNER JOIN WM_COUNT_SOC_SERV_MONTH countMonth
        ON countMonth.A_AGR_SOC_SERV = AGR.A_ID
            AND countMonth.A_YEAR = forRecalculation.YEAR
            AND countMonth.A_MONTH = forRecalculation.MONTH
            AND countMonth.A_STATUS = @activeStatus
----Посчитанное количество отсутствует.
    LEFT JOIN #COUNT_SERV_GROUPED_BY_EACH countCalculated
        ON countCalculated.AGR_OUID = AGR.A_ID
            AND countCalculated.PERIOD_YEAR = countMonth.A_YEAR
            AND countCalculated.PERIOD_MONTH = countMonth.A_MONTH
WHERE countCalculated.AGR_OUID IS NULL

--Удаление строк количества всех услуг за месяц, если в эти это строки нечего вставить.
UPDATE countAll
SET countAll.A_STATUS       = @deleteStatus,
    countAll.A_EDITOWNER    = 10314303,
    countAll.TS             = GETDATE()
FROM (SELECT DISTINCT SOC_SERV_OUID, YEAR, MONTH FROM #SOC_SERV_FOR_RECALCULATION) forRecalculation --Назначения для перерасчета.
----Количество (часов) всех оказанных услуг за месяц (СДУ).
    INNER JOIN WM_FACT_COUNT_SOC_SERV countAll
        ON countAll.ESRN_SOC_SERV = forRecalculation.SOC_SERV_OUID
            AND countAll.A_YEAR = forRecalculation.YEAR
            AND countAll.A_MONTH = forRecalculation.MONTH
            AND countAll.A_STATUS = @activeStatus
----Посчитанное количество отсутствует.
    LEFT JOIN #COUNT_SERV_GROUPED_BY_ALL countCalculated
        ON countCalculated.SOC_SERV_OUID = countAll.ESRN_SOC_SERV
            AND countCalculated.PERIOD_YEAR = countAll.A_YEAR
            AND countCalculated.PERIOD_MONTH = countAll.A_MONTH
WHERE countCalculated.SOC_SERV_OUID IS NULL

---------------------------------------------------------------------------------------------------------------------------------------------

--SELECT * FROM #FROM_CARE_DIARY_GROUPED      --Сгруппированные данные из ежедневного плана по назначению, услуге, дню и работнику.
--SELECT * FROM #FROM_SOC_SERV_AGR            --Сопоставленные агрегации для данных из дневника.
--SELECT * FROM #FROM_SOC_SERV                --Данные из назначения.
--SELECT * FROM #FROM_SOC_SERV_GROUPED        --Сгруппированные данные по назначению, услуге, дню и работнику.
--SELECT * FROM #FOR_DELETE_FROM_SOC_SERV     --Несовпадающие записи для удаления из назначения.
--SELECT * FROM #CREATEAD_PERIOD_FOR_SERV     --Созданные агрегации услуги по периоду.
--SELECT * FROM #SOC_SERV_FOR_RECALCULATION   --Назначения для перерасчета агрегаций.
--SELECT * FROM #COUNT_SERV_GROUPED_BY_EACH   --Количество оказанных услуг в месяц, которые сгруппированы в рамках каждой услуги в назначении.
--SELECT * FROM #COUNT_SERV_GROUPED_BY_ALL    --Количество оказанных услуг в месяц, которые сгруппированы в рамках всех услуг в назначении.

---------------------------------------------------------------------------------------------------------------------------------------------