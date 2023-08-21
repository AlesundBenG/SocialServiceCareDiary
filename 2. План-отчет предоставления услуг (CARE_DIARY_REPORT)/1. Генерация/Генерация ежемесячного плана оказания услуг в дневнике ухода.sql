------------------------------------------------------------------------------------------------------------------------------

/*
    1. Формируем календарь на месяц (К какой недели и к какому дню недели относится дата).
    2. Собираем все документы (дневник, ИППСУ и дополнение), периоды которых пересекаются с месяцем.
    3. Извлекаем все сведения об услугах из дополнения ИППСУ.
    4. Составляем календарь с неделями и днями услуг из дополнения, генерируя план на месяц (учитывая дату начала и окончания документов)
    5. Грузим сгенерированный план в таблицу.
*/

------------------------------------------------------------------------------------------------------------------------------

--Параметры.
DECLARE @year           INT = #year#
DECLARE @month          INT = #month#
DECLARE @monthDateStart DATE = dbo.fs_getFirstDayOfMonth(@year, @month)     --Начало месяца.
DECLARE @monthDateEnd   DATE = dbo.fs_getLastDayOfMonth(@year, @month)      --Конец месяца.

------------------------------------------------------------------------------------------------------------------------------

--Удаление временных таблиц.
IF OBJECT_ID('tempdb..#MONTH_INFO') IS NOT NULL BEGIN DROP TABLE #MONTH_INFO    END --Информация о месяце.
IF OBJECT_ID('tempdb..#DOCUMENTS')  IS NOT NULL BEGIN DROP TABLE #DOCUMENTS     END --Необходимые документы.
IF OBJECT_ID('tempdb..#SERV_SDU')   IS NOT NULL BEGIN DROP TABLE #SERV_SDU      END --Список услуг СДУ из дополнений ИППСУ.
IF OBJECT_ID('tempdb..#MONTH_PLAN') IS NOT NULL BEGIN DROP TABLE #MONTH_PLAN    END --План оказания услуг на месяц.

--------------------------------------------------------------------------------------------------------------------------------

--Создание временных таблиц.
CREATE TABLE #MONTH_INFO (
    WEEK_NUMBER     INT,    --Номер недели.
    MONDAY_DATE     DATE,   --Дата понедельника.
    TUESDAY_DATE    DATE,   --Дата вторника.
    WEDNESDAY_DATE  DATE,   --Дата среды.
    THURSDAY_DATE   DATE,   --Дата четверга.
    FRIDAY_DATE     DATE,   --Дата пятницы.
    SATURDAY_DATE   DATE,   --Дата субботы.
    SUNDAY_DATE     DATE,   --Дата воскресенья.
)
CREATE TABLE #DOCUMENTS (
    OUID        INT,    --Идентификатор.
    PERSONOUID  INT,    --Личное дело.
    TYPE        INT,    --Тип документа.
    DATE_START  DATE,   --Дата начала действия документа.
    DATE_END    DATE,   --Дата окончания действия документа.
)
CREATE TABLE #SERV_SDU (
    CARE_DIARY_OUID     INT,    --Идентификатор дневника ухода.
    ADDITION_OUID       INT,    --Дополнение к ИППСУ, на основании которой сформирован план.
    SERV_SDU            INT,    --Услуга.
    EXECUTE_TIME        INT,    --Время для исполнения услуги.
    COUNT_IN_DAY        INT,    --Количество услуг в день.
    FIRST_DAY_OF_MONTH  INT,    --Первый день месяца, с которого будет формироваться план.
    LAST_DAY_OF_MONTH   INT,    --Последний день месяца, до которого будет формироваться план.
)
CREATE TABLE #MONTH_PLAN (
    CARE_DIARY_OUID    INT,    --Идентификатор дневника ухода.
    ADDITION_OUID      INT,    --Дополнение к ИППСУ, на основании которой сформирован план.
    SERV_SDU           INT,    --Услуга.
    EXECUTE_TIME       INT,    --Время для исполнения услуги.
    FIRST_DAY_OF_MONTH INT,    --Первый день месяца, с которого будет формироваться план.
    LAST_DAY_OF_MONTH  INT,    --Последний день месяца, до которого будет формироваться план.
    DAY_1  INT, DAY_2  INT, DAY_3  INT, DAY_4  INT, DAY_5  INT, DAY_6  INT, DAY_7  INT,
    DAY_8  INT, DAY_9  INT, DAY_10 INT, DAY_11 INT, DAY_12 INT, DAY_13 INT, DAY_14 INT,
    DAY_15 INT, DAY_16 INT, DAY_17 INT, DAY_18 INT, DAY_19 INT, DAY_20 INT, DAY_21 INT,
    DAY_22 INT, DAY_23 INT, DAY_24 INT, DAY_25 INT, DAY_26 INT, DAY_27 INT, DAY_28 INT,
    DAY_29 INT, DAY_30 INT, DAY_31 INT,
)

------------------------------------------------------------------------------------------------------------------------------

--Константы.
DECLARE @activeStatus       INT = (SELECT A_ID FROM ESRN_SERV_STATUS WHERE A_STATUSCODE = 'act')    --Статус действующей (не удаленной) записи.
DECLARE @docTypeCareDiary   INT = (SELECT A_ID FROM PPR_DOC WHERE A_CODE = 'CareDiary')             --Идентификатор типа документа дневника ухода.

------------------------------------------------------------------------------------------------------------------------------

--Параметры цикла формирования информации об месяце.
DECLARE @tempDate       DATE    = @monthDateStart           --Итератор.
DECLARE @tempDayOfWeek  INT     = DATEPART(DW, @tempDate)   --День недели итератора.
DECLARE @tempNumberWeek INT     = 1                         --Номер недели итератора.
DECLARE @numberWeek     INT     = 1
DECLARE @dateWeekEnd    DATE    
DECLARE @query          NVARCHAR(MAX)   = '' --Для запроса.


--Цикл формирования информации об месяце.
WHILE @tempDate <= @monthDateEnd BEGIN
    --Вставка информации.
    INSERT INTO #MONTH_INFO (WEEK_NUMBER)
    VALUES (@numberWeek)
    --Заполнение недели.
    SET @dateWeekEnd = dbo.fs_getLastDayOfWeek(@tempDate)
    WHILE @tempDate <= @dateWeekEnd AND @tempDate <= @monthDateEnd BEGIN
        SET @query = '
            UPDATE #MONTH_INFO
            SET ' +
                CASE DATEPART(DW, @tempDate)
                    WHEN 1 THEN 'MONDAY_DATE'
                    WHEN 2 THEN 'TUESDAY_DATE'
                    WHEN 3 THEN 'WEDNESDAY_DATE'
                    WHEN 4 THEN 'THURSDAY_DATE'
                    WHEN 5 THEN 'FRIDAY_DATE'
                    WHEN 6 THEN 'SATURDAY_DATE'
                    WHEN 7 THEN 'SUNDAY_DATE'
                END + ' = ''' + CONVERT(VARCHAR, @tempDate, 104) + '''
            WHERE WEEK_NUMBER = '  + CONVERT(VARCHAR, @numberWeek)
        EXEC SP_EXECUTESQL @query
        SET @tempDate = DATEADD(DAY, 1, @tempDate)
    END
    --Переход к следующей неделе.
    SET @numberWeek = @numberWeek + 1
END

--------------------------------------------------------------------------------------------------------------------------------

--Формирование планов на день. 
INSERT INTO #SERV_SDU(CARE_DIARY_OUID, ADDITION_OUID, SERV_SDU, EXECUTE_TIME, COUNT_IN_DAY, FIRST_DAY_OF_MONTH, LAST_DAY_OF_MONTH)
SELECT DISTINCT
    careDiaryInfo.A_OUID        AS CARE_DIARY_OUID,
    additionInfo.A_OUID         AS ADDITION_OUID,
    servSDU.A_SOC_SERV          AS SERV_SDU,
    CASE 
        WHEN ISNULL(servSDU.A_PERIOD_DAY, 0) <> 0 
        THEN servSDU.A_VOLUME_DAY / servSDU.A_PERIOD_DAY 
        ELSE 0
    END                     AS EXECUTE_TIME,
    servSDU.A_PERIOD_DAY    AS COUNT_IN_DAY,
    CASE WHEN @monthDateStart < CONVERT(DATE, careDiaryDoc.ISSUEEXTENSIONSDATE)
        THEN DAY(careDiaryDoc.ISSUEEXTENSIONSDATE) ELSE 1
    END AS FIRST_DAY_OF_MONTH,
    CASE WHEN @monthDateEnd > CONVERT(DATE, careDiaryDoc.COMPLETIONSACTIONDATE)
        THEN DAY(careDiaryDoc.COMPLETIONSACTIONDATE) ELSE DAY(@monthDateEnd)
    END AS LAST_DAY_OF_MONTH
FROM CARE_DIARY careDiaryInfo --Информация дневника ухода.
----Документ дневника ухода.
    INNER JOIN WM_ACTDOCUMENTS careDiaryDoc
        ON careDiaryDoc.OUID = careDiaryInfo.DOCUMENT_OUID
            AND careDiaryDoc.A_STATUS = @activeStatus
            AND dbo.fs_thisPeriodsCross(careDiaryDoc.ISSUEEXTENSIONSDATE, careDiaryDoc.COMPLETIONSACTIONDATE, @monthDateStart, @monthDateEnd, DEFAULT) = 1
            AND careDiaryDoc.DOCUMENTSTYPE = @docTypeCareDiary
----Документ дополнения к ИППСУ.
    INNER JOIN WM_ACTDOCUMENTS additionDoc
        ON additionDoc.OUID = careDiaryInfo.DOCUMENT_ADDITION
            AND additionDoc.A_STATUS = @activeStatus 
----Информация из дополнения к ИППСУ.
    INNER JOIN INDIVID_PROGRAM_ADDITION additionInfo
        ON additionInfo.A_DOCUMENT = additionDoc.OUID
            AND additionInfo.A_STATUS = 10
----Услуги, попадающие под указанный день.
    INNER JOIN SOCSERV_INDIVIDPROGRAM_ADDITION servSDU
        ON servSDU.A_IPPSU_ADDITION = additionInfo.A_OUID
            AND servSDU.A_STATUS = 10
            AND ISNULL(servSDU.A_SOCSERV_NOT_NEED, 0) = 0
----План-отчет предоставления услуг СДУ из дневника ухода
    LEFT JOIN CARE_DIARY_REPORT report
        ON report.CARE_DIARY_OUID = careDiaryInfo.A_OUID
            AND report.A_STATUS = @activeStatus
            AND report.YEAR = @year
            AND report.MONTH = @month
WHERE careDiaryInfo.A_STATUS = @activeStatus
    AND report.A_OUID IS NULL
    AND careDiaryInfo.A_OUID IN (
        #careDiary#
    )

------------------------------------------------------------------------------------------------------------------------------

--Инициализация плана.
INSERT INTO #MONTH_PLAN (CARE_DIARY_OUID, ADDITION_OUID, SERV_SDU, EXECUTE_TIME, FIRST_DAY_OF_MONTH, LAST_DAY_OF_MONTH)
SELECT DISTINCT
    CARE_DIARY_OUID     AS CARE_DIARY_OUID,
    ADDITION_OUID       AS ADDITION_OUID,
    SERV_SDU            AS SERV_SDU,
    EXECUTE_TIME        AS EXECUTE_TIME,
    FIRST_DAY_OF_MONTH  AS FIRST_DAY_OF_MONTH, 
    LAST_DAY_OF_MONTH   AS LAST_DAY_OF_MONTH
FROM #SERV_SDU

--------------------------------------------------------------------------------------------------------------------------------

--Формирование плана.
SET @numberWeek = 1
DECLARE @numberWeekMax  INT = (SELECT MAX(WEEK_NUMBER) FROM #MONTH_INFO)
DECLARE @expression VARCHAR(MAX)

WHILE @numberWeek <= @numberWeekMax BEGIN
    --Выражение для обновления полей.
    SET @expression = (
        SELECT
            dbo.fs_concatenateString(dbo.fs_concatenateString(dbo.fs_concatenateString(dbo.fs_concatenateString(dbo.fs_concatenateString(dbo.fs_concatenateString(
                'mP.DAY_' + CONVERT(VARCHAR, DAY(MONDAY_DATE))    + ' = CASE WHEN ISNULL(serv.A_MONDAY, 0) = 1 AND '    + CONVERT(VARCHAR, DAY(MONDAY_DATE))  + ' BETWEEN mP.FIRST_DAY_OF_MONTH AND mP.LAST_DAY_OF_MONTH THEN serv.A_PERIOD_DAY END', 
                'mP.DAY_' + CONVERT(VARCHAR, DAY(TUESDAY_DATE))   + ' = CASE WHEN ISNULL(serv.A_TUESDAY, 0) = 1 AND '   + CONVERT(VARCHAR, DAY(TUESDAY_DATE)) + ' BETWEEN mP.FIRST_DAY_OF_MONTH AND mP.LAST_DAY_OF_MONTH THEN serv.A_PERIOD_DAY END', ','), 
                'mP.DAY_' + CONVERT(VARCHAR, DAY(WEDNESDAY_DATE)) + ' = CASE WHEN ISNULL(serv.A_WEDNESDAY, 0) = 1 AND ' + CONVERT(VARCHAR, DAY(WEDNESDAY_DATE)) + ' BETWEEN mP.FIRST_DAY_OF_MONTH AND mP.LAST_DAY_OF_MONTH THEN serv.A_PERIOD_DAY END', ','),
                'mP.DAY_' + CONVERT(VARCHAR, DAY(THURSDAY_DATE))  + ' = CASE WHEN ISNULL(serv.A_THURSDAY, 0) = 1 AND '  + CONVERT(VARCHAR, DAY(THURSDAY_DATE))  + ' BETWEEN mP.FIRST_DAY_OF_MONTH AND mP.LAST_DAY_OF_MONTH THEN serv.A_PERIOD_DAY END', ','),
                'mP.DAY_' + CONVERT(VARCHAR, DAY(FRIDAY_DATE))    + ' = CASE WHEN ISNULL(serv.A_FRIDAY, 0) = 1 AND '    + CONVERT(VARCHAR, DAY(FRIDAY_DATE))    + ' BETWEEN mP.FIRST_DAY_OF_MONTH AND mP.LAST_DAY_OF_MONTH THEN serv.A_PERIOD_DAY END', ','),
                'mP.DAY_' + CONVERT(VARCHAR, DAY(SATURDAY_DATE))  + ' = CASE WHEN ISNULL(serv.A_SATURDAY, 0) = 1 AND '  + CONVERT(VARCHAR, DAY(SATURDAY_DATE))  + ' BETWEEN mP.FIRST_DAY_OF_MONTH AND mP.LAST_DAY_OF_MONTH THEN serv.A_PERIOD_DAY END', ','),
                'mP.DAY_' + CONVERT(VARCHAR, DAY(SUNDAY_DATE))    + ' = CASE WHEN ISNULL(serv.A_SUNDAY, 0) = 1 AND '    + CONVERT(VARCHAR, DAY(SUNDAY_DATE))    +' BETWEEN mP.FIRST_DAY_OF_MONTH AND mP.LAST_DAY_OF_MONTH THEN serv.A_PERIOD_DAY END', ','
            )
        FROM #MONTH_INFO
        WHERE WEEK_NUMBER = @numberWeek
    )
    SET @query = '
        UPDATE mP
        SET ' + @expression + '        
        FROM #MONTH_INFO monthInfo
        ----Планы на месяц.
            CROSS JOIN #MONTH_PLAN mP            
        ----Услуги, попадающие под указанный день.
            INNER JOIN SOCSERV_INDIVIDPROGRAM_ADDITION serv 
                ON serv.A_IPPSU_ADDITION = mP.ADDITION_OUID
                    AND serv.A_SOC_SERV = mP.SERV_SDU
                    AND serv.A_STATUS = 10
                    AND serv.A_WEEK_NUM = monthInfo.WEEK_NUMBER
        WHERE monthInfo.WEEK_NUMBER = ' + CONVERT(VARCHAR, CASE WHEN @numberWeek <= 5 THEN @numberWeek ELSE @numberWeek - 5 END) --Если 6 недель, то 6 неделя считается первой.
    EXEC SP_EXECUTESQL @query
    SET @numberWeek = @numberWeek + 1
END

--------------------------------------------------------------------------------------------------------------------------------

--Вставка заголовков.
INSERT INTO CARE_DIARY_REPORT (YEAR, MONTH, CARE_DIARY_OUID,
    DAY_1_ALL,  DAY_2_ALL,  DAY_3_ALL,  DAY_4_ALL,  DAY_5_ALL,  DAY_6_ALL,  DAY_7_ALL, 
    DAY_8_ALL,  DAY_9_ALL,  DAY_10_ALL, DAY_11_ALL, DAY_12_ALL, DAY_13_ALL, DAY_14_ALL, 
    DAY_15_ALL, DAY_16_ALL, DAY_17_ALL, DAY_18_ALL, DAY_19_ALL, DAY_20_ALL, DAY_21_ALL, 
    DAY_22_ALL, DAY_23_ALL, DAY_24_ALL, DAY_25_ALL, DAY_26_ALL, DAY_27_ALL, DAY_28_ALL, 
    DAY_29_ALL, DAY_30_ALL, DAY_31_ALL, 
    DAY_1_PERFORM,  DAY_2_PERFORM,  DAY_3_PERFORM,  DAY_4_PERFORM,  DAY_5_PERFORM,  DAY_6_PERFORM,  DAY_7_PERFORM, 
    DAY_8_PERFORM,  DAY_9_PERFORM,  DAY_10_PERFORM, DAY_11_PERFORM, DAY_12_PERFORM, DAY_13_PERFORM, DAY_14_PERFORM, 
    DAY_15_PERFORM, DAY_16_PERFORM, DAY_17_PERFORM, DAY_18_PERFORM, DAY_19_PERFORM, DAY_20_PERFORM, DAY_21_PERFORM, 
    DAY_22_PERFORM, DAY_23_PERFORM, DAY_24_PERFORM, DAY_25_PERFORM, DAY_26_PERFORM, DAY_27_PERFORM, DAY_28_PERFORM, 
    DAY_29_PERFORM, DAY_30_PERFORM, DAY_31_PERFORM, 
    A_STATUS, ROW_TYPE
)
SELECT DISTINCT
    @year                       AS YEAR,
    @month                      AS MONTH,
    monthPlan.CARE_DIARY_OUID   AS CARE_DIARY_OUID,
    --Функция SUM игнорирует NULL, поэтому на NULL не проверяем для производительности.
    SUM(ISNULL(monthPlan.DAY_1, 0))  AS DAY_1_ALL,  SUM(ISNULL(monthPlan.DAY_2, 0))  AS DAY_2_ALL,  SUM(ISNULL(monthPlan.DAY_3, 0))  AS DAY_3_ALL,  
    SUM(ISNULL(monthPlan.DAY_4, 0))  AS DAY_4_ALL,  SUM(ISNULL(monthPlan.DAY_5, 0))  AS DAY_5_ALL,  SUM(ISNULL(monthPlan.DAY_6, 0))  AS DAY_6_ALL,  
    SUM(ISNULL(monthPlan.DAY_7, 0))  AS DAY_7_ALL,  SUM(ISNULL(monthPlan.DAY_8, 0))  AS DAY_8_ALL,  SUM(ISNULL(monthPlan.DAY_9, 0))  AS DAY_9_ALL,  
    SUM(ISNULL(monthPlan.DAY_10, 0)) AS DAY_10_ALL, SUM(ISNULL(monthPlan.DAY_11, 0)) AS DAY_11_ALL, SUM(ISNULL(monthPlan.DAY_12, 0)) AS DAY_12_ALL, 
    SUM(ISNULL(monthPlan.DAY_13, 0)) AS DAY_13_ALL, SUM(ISNULL(monthPlan.DAY_14, 0)) AS DAY_14_ALL, SUM(ISNULL(monthPlan.DAY_15, 0)) AS DAY_15_ALL, 
    SUM(ISNULL(monthPlan.DAY_16, 0)) AS DAY_16_ALL, SUM(ISNULL(monthPlan.DAY_17, 0)) AS DAY_17_ALL, SUM(ISNULL(monthPlan.DAY_18, 0)) AS DAY_18_ALL, 
    SUM(ISNULL(monthPlan.DAY_19, 0)) AS DAY_19_ALL, SUM(ISNULL(monthPlan.DAY_20, 0)) AS DAY_20_ALL, SUM(ISNULL(monthPlan.DAY_21, 0)) AS DAY_21_ALL, 
    SUM(ISNULL(monthPlan.DAY_22, 0)) AS DAY_22_ALL, SUM(ISNULL(monthPlan.DAY_23, 0)) AS DAY_23_ALL, SUM(ISNULL(monthPlan.DAY_24, 0)) AS DAY_24_ALL, 
    SUM(ISNULL(monthPlan.DAY_25, 0)) AS DAY_25_ALL, SUM(ISNULL(monthPlan.DAY_26, 0)) AS DAY_26_ALL, SUM(ISNULL(monthPlan.DAY_27, 0)) AS DAY_27_ALL, 
    SUM(ISNULL(monthPlan.DAY_28, 0)) AS DAY_28_ALL, SUM(ISNULL(monthPlan.DAY_29, 0)) AS DAY_29_ALL, SUM(ISNULL(monthPlan.DAY_30, 0)) AS DAY_30_ALL, 
    SUM(ISNULL(monthPlan.DAY_31, 0)) AS DAY_31_ALL,
    0 AS DAY_1_PERFORM,  0 AS DAY_2_PERFORM,  0 AS DAY_3_PERFORM,  0 AS DAY_4_PERFORM,  0 AS DAY_5_PERFORM,  0 AS DAY_6_PERFORM,  0 AS DAY_7_PERFORM, 
    0 AS DAY_8_PERFORM,  0 AS DAY_9_PERFORM,  0 AS DAY_10_PERFORM, 0 AS DAY_11_PERFORM, 0 AS DAY_12_PERFORM, 0 AS DAY_13_PERFORM, 0 AS DAY_14_PERFORM, 
    0 AS DAY_15_PERFORM, 0 AS DAY_16_PERFORM, 0 AS DAY_17_PERFORM, 0 AS DAY_18_PERFORM, 0 AS DAY_19_PERFORM, 0 AS DAY_20_PERFORM, 0 AS DAY_21_PERFORM, 
    0 AS DAY_22_PERFORM, 0 AS DAY_23_PERFORM, 0 AS DAY_24_PERFORM, 0 AS DAY_25_PERFORM, 0 AS DAY_26_PERFORM, 0 AS DAY_27_PERFORM, 0 AS DAY_28_PERFORM, 
    0 AS DAY_29_PERFORM, 0 AS DAY_30_PERFORM, 0 AS DAY_31_PERFORM, 
    10                          AS A_STATUS,
    1                           AS ROW_TYPE
FROM #MONTH_PLAN monthPlan
----Для данного месяца еще нет заголовка.
    LEFT JOIN CARE_DIARY_REPORT reportMonth
        ON reportMonth.CARE_DIARY_OUID =  monthPlan.CARE_DIARY_OUID
            AND reportMonth.A_STATUS = 10
            AND reportMonth.YEAR = @year
            AND reportMonth.MONTH = @month
            AND reportMonth.ROW_TYPE = 1
WHERE reportMonth.A_OUID IS NULL
GROUP BY monthPlan.CARE_DIARY_OUID

--Вставка планов.
INSERT INTO CARE_DIARY_REPORT (YEAR, MONTH, CARE_DIARY_OUID, SERV_SDU, EXECUTE_TIME,
    DAY_1_ALL,  DAY_2_ALL,  DAY_3_ALL,  DAY_4_ALL,  DAY_5_ALL,  DAY_6_ALL,  DAY_7_ALL, 
    DAY_8_ALL,  DAY_9_ALL,  DAY_10_ALL, DAY_11_ALL, DAY_12_ALL, DAY_13_ALL, DAY_14_ALL, 
    DAY_15_ALL, DAY_16_ALL, DAY_17_ALL, DAY_18_ALL, DAY_19_ALL, DAY_20_ALL, DAY_21_ALL, 
    DAY_22_ALL, DAY_23_ALL, DAY_24_ALL, DAY_25_ALL, DAY_26_ALL, DAY_27_ALL, DAY_28_ALL, 
    DAY_29_ALL, DAY_30_ALL, DAY_31_ALL,
    DAY_1_PERFORM,  DAY_2_PERFORM,  DAY_3_PERFORM,  DAY_4_PERFORM,  DAY_5_PERFORM,  DAY_6_PERFORM,  DAY_7_PERFORM, 
    DAY_8_PERFORM,  DAY_9_PERFORM,  DAY_10_PERFORM, DAY_11_PERFORM, DAY_12_PERFORM, DAY_13_PERFORM, DAY_14_PERFORM, 
    DAY_15_PERFORM, DAY_16_PERFORM, DAY_17_PERFORM, DAY_18_PERFORM, DAY_19_PERFORM, DAY_20_PERFORM, DAY_21_PERFORM, 
    DAY_22_PERFORM, DAY_23_PERFORM, DAY_24_PERFORM, DAY_25_PERFORM, DAY_26_PERFORM, DAY_27_PERFORM, DAY_28_PERFORM, 
    DAY_29_PERFORM, DAY_30_PERFORM, DAY_31_PERFORM, 
    A_STATUS, ROW_TYPE
)
SELECT
    @year   AS YEAR,
    @month  AS MONTH,
    CARE_DIARY_OUID AS CARE_DIARY_OUID,
    SERV_SDU        AS SERV_SDU,
    EXECUTE_TIME    AS EXECUTE_TIME,
    ISNULL(DAY_1, 0)  AS DAY_1,  ISNULL(DAY_2, 0)  AS DAY_2,  ISNULL(DAY_3, 0)  AS DAY_3,  ISNULL(DAY_4, 0)  AS DAY_4,  ISNULL(DAY_5, 0)  AS DAY_5,  ISNULL(DAY_6, 0)  AS DAY_6,  ISNULL(DAY_7, 0)  AS DAY_7,
    ISNULL(DAY_8, 0)  AS DAY_8,  ISNULL(DAY_9, 0)  AS DAY_9,  ISNULL(DAY_10, 0) AS DAY_10, ISNULL(DAY_11, 0) AS DAY_11, ISNULL(DAY_12, 0) AS DAY_12, ISNULL(DAY_13, 0) AS DAY_13, ISNULL(DAY_14, 0) AS DAY_14, 
    ISNULL(DAY_15, 0) AS DAY_15, ISNULL(DAY_16, 0) AS DAY_16, ISNULL(DAY_17, 0) AS DAY_17, ISNULL(DAY_18, 0) AS DAY_18, ISNULL(DAY_19, 0) AS DAY_19, ISNULL(DAY_20, 0) AS DAY_20, ISNULL(DAY_21, 0) AS DAY_21,
    ISNULL(DAY_22, 0) AS DAY_22, ISNULL(DAY_23, 0) AS DAY_23, ISNULL(DAY_24, 0) AS DAY_24, ISNULL(DAY_25, 0) AS DAY_25, ISNULL(DAY_26, 0) AS DAY_26, ISNULL(DAY_27, 0) AS DAY_27, ISNULL(DAY_28, 0) AS DAY_28,
    ISNULL(DAY_29, 0) AS DAY_29, ISNULL(DAY_30, 0) AS DAY_30, ISNULL(DAY_31, 0) AS DAY_31,
    0 AS DAY_1_PERFORM,  0 AS DAY_2_PERFORM,  0 AS DAY_3_PERFORM,  0 AS DAY_4_PERFORM,  0 AS DAY_5_PERFORM,  0 AS DAY_6_PERFORM,  0 AS DAY_7_PERFORM, 
    0 AS DAY_8_PERFORM,  0 AS DAY_9_PERFORM,  0 AS DAY_10_PERFORM, 0 AS DAY_11_PERFORM, 0 AS DAY_12_PERFORM, 0 AS DAY_13_PERFORM, 0 AS DAY_14_PERFORM, 
    0 AS DAY_15_PERFORM, 0 AS DAY_16_PERFORM, 0 AS DAY_17_PERFORM, 0 AS DAY_18_PERFORM, 0 AS DAY_19_PERFORM, 0 AS DAY_20_PERFORM, 0 AS DAY_21_PERFORM, 
    0 AS DAY_22_PERFORM, 0 AS DAY_23_PERFORM, 0 AS DAY_24_PERFORM, 0 AS DAY_25_PERFORM, 0 AS DAY_26_PERFORM, 0 AS DAY_27_PERFORM, 0 AS DAY_28_PERFORM, 
    0 AS DAY_29_PERFORM, 0 AS DAY_30_PERFORM, 0 AS DAY_31_PERFORM, 
    10  AS A_STATUS,
    2   AS ROW_TYPE
FROM #MONTH_PLAN

--------------------------------------------------------------------------------------------------------------------------------
