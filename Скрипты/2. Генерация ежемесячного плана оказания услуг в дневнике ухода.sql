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
DECLARE @year           INT = 2023
DECLARE @month          INT = 8
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
    IPPSU_OUID          INT,    --ИППСУ, на основании которой сформирован план.
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

--------------------------------------------------------------------------------------------------------------------------------

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

--Выбор всех действующих документов на указанный месяц.
INSERT INTO #DOCUMENTS (OUID, PERSONOUID, TYPE, DATE_START, DATE_END)
SELECT
    document.OUID                                   AS OUID,
    personalCard.OUID                               AS PERSONOUID,
    document.DOCUMENTSTYPE                          AS TYPE,
    CONVERT(DATE, document.ISSUEEXTENSIONSDATE)     AS DATE_START,
    CONVERT(DATE,  document.COMPLETIONSACTIONDATE)  AS DATE_END
FROM WM_ACTDOCUMENTS document --Действующие документы.  
----Личное дело держателя документа.
    INNER JOIN WM_PERSONAL_CARD personalCard
        ON personalCard.OUID = document.PERSONOUID 
            AND personalCard.A_STATUS = 10
            AND personalCard.A_PCSTATUS = 1
            AND personalCard.A_DEATHDATE IS NULL
WHERE document.A_STATUS = 10
    AND document.A_DOCSTATUS = 1
    AND dbo.fs_thisPeriodsCross(document.ISSUEEXTENSIONSDATE, document.COMPLETIONSACTIONDATE, @monthDateStart, @monthDateEnd, DEFAULT) = 1
    AND document.DOCUMENTSTYPE IN (
        4404,   --Дневник ухода.
        3883,   --Индивидуальная программа предоставления социальных услуг.
        4388    --Дополнение к индивидуальной программе предоставления социальных услуг.
    )
    AND personalCard.OUID = 870030

--------------------------------------------------------------------------------------------------------------------------------

--Формирование планов на день. 
INSERT INTO #SERV_SDU(CARE_DIARY_OUID, IPPSU_OUID, ADDITION_OUID, SERV_SDU, EXECUTE_TIME, COUNT_IN_DAY, FIRST_DAY_OF_MONTH, LAST_DAY_OF_MONTH)
SELECT DISTINCT
    careDiaryInfo.A_OUID        AS CARE_DIARY_OUID,
    infoIPPSU.A_OUID            AS IPPSU_OUID,
    additionInfo.A_OUID         AS ADDITION_OUID,
    servSDU.A_SOC_SERV          AS SERV_SDU,
    servSDU.A_VOLUME_DAY        AS EXECUTE_TIME,
    servSDU.A_PERIOD_DAY        AS COUNT_IN_DAY,
    CASE WHEN @monthDateStart < CONVERT(DATE, careDiaryDoc.DATE_START)
        THEN DAY(careDiaryDoc.DATE_START) ELSE 1
    END AS FIRST_DAY_OF_MONTH,
    CASE WHEN @monthDateEnd > CONVERT(DATE, careDiaryDoc.DATE_END)
        THEN DAY(careDiaryDoc.DATE_END) ELSE DAY(@monthDateEnd)
    END AS LAST_DAY_OF_MONTH
FROM #DOCUMENTS careDiaryDoc --Документ дневника ухода.
----Информация дневника ухода.
    INNER JOIN CARE_DIARY careDiaryInfo
        ON careDiaryInfo.DOCUMENT_OUID = careDiaryDoc.OUID
            AND careDiaryInfo.A_STATUS = 10
----Документ ИППСУ.
    INNER JOIN #DOCUMENTS docIPPSU
        ON docIPPSU.OUID = careDiaryInfo.DOCUMENT_IPPSU
----Информация из ИППСУ.
    INNER JOIN INDIVID_PROGRAM infoIPPSU
        ON infoIPPSU.A_DOC = docIPPSU.OUID
            AND infoIPPSU.A_STATUS = 10
----Документ дополнения к ИППСУ.
    INNER JOIN #DOCUMENTS additionDoc
        ON additionDoc.OUID = infoIPPSU.A_DOC_ADD_IPPSU
----Информация из дополнения к ИППСУ.
    INNER JOIN INDIVID_PROGRAM_ADDITION additionInfo
        ON additionInfo.A_DOCUMENT = additionDoc.OUID
            AND additionInfo.A_STATUS = 10
----Услуги, попадающие под указанный день.
    INNER JOIN SOCSERV_INDIVIDPROGRAM_ADDITION servSDU
        ON servSDU.A_IPPSU_ADDITION = additionInfo.A_OUID
            AND servSDU.A_STATUS = 10
            AND ISNULL(servSDU.A_SOCSERV_NOT_NEED, 0) = 0
WHERE careDiaryDoc.TYPE = 4404   --Дневник ухода.

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
        WHERE monthInfo.WEEK_NUMBER = ' + CONVERT(VARCHAR, @numberWeek) 
    EXEC SP_EXECUTESQL @query
    SET @numberWeek = @numberWeek + 1
END

SELECT * FROM #MONTH_PLAN

--------------------------------------------------------------------------------------------------------------------------------
/*
--Вставка заголовков.
INSERT INTO CARE_DIARY_REPORT (YEAR, MONTH, CARE_DIARY_OUID,
    DAY_1_ALL,  DAY_2_ALL,  DAY_3_ALL,  DAY_4_ALL,  DAY_5_ALL,  DAY_6_ALL,  DAY_7_ALL, 
    DAY_8_ALL,  DAY_9_ALL,  DAY_10_ALL, DAY_11_ALL, DAY_12_ALL, DAY_13_ALL, DAY_14_ALL, 
    DAY_15_ALL, DAY_16_ALL, DAY_17_ALL, DAY_18_ALL, DAY_19_ALL, DAY_20_ALL, DAY_21_ALL, 
    DAY_22_ALL, DAY_23_ALL, DAY_24_ALL, DAY_25_ALL, DAY_26_ALL, DAY_27_ALL, DAY_28_ALL, 
    DAY_29_ALL, DAY_30_ALL, DAY_31_ALL, 
    A_STATUS, ROW_TYPE
)
SELECT DISTINCT
    @year                       AS YEAR,
    @month                      AS MONTH,
    monthPlan.CARE_DIARY_OUID   AS CARE_DIARY_OUID,
    --Функция SUM игнорирует NULl, поэтому на NULL не проверяем для производительности
    SUM(monthPlan.DAY_1)  AS DAY_1_ALL,  SUM(monthPlan.DAY_2)  AS DAY_2_ALL,  SUM(monthPlan.DAY_3)  AS DAY_3_ALL,  
    SUM(monthPlan.DAY_4)  AS DAY_4_ALL,  SUM(monthPlan.DAY_5)  AS DAY_5_ALL,  SUM(monthPlan.DAY_6)  AS DAY_6_ALL,  
    SUM(monthPlan.DAY_7)  AS DAY_7_ALL,  SUM(monthPlan.DAY_8)  AS DAY_8_ALL,  SUM(monthPlan.DAY_9)  AS DAY_9_ALL,  
    SUM(monthPlan.DAY_10) AS DAY_10_ALL, SUM(monthPlan.DAY_11) AS DAY_11_ALL, SUM(monthPlan.DAY_12) AS DAY_12_ALL, 
    SUM(monthPlan.DAY_13) AS DAY_13_ALL, SUM(monthPlan.DAY_14) AS DAY_14_ALL, SUM(monthPlan.DAY_15) AS DAY_15_ALL, 
    SUM(monthPlan.DAY_16) AS DAY_16_ALL, SUM(monthPlan.DAY_17) AS DAY_17_ALL, SUM(monthPlan.DAY_18) AS DAY_18_ALL, 
    SUM(monthPlan.DAY_19) AS DAY_19_ALL, SUM(monthPlan.DAY_20) AS DAY_20_ALL, SUM(monthPlan.DAY_21) AS DAY_21_ALL, 
    SUM(monthPlan.DAY_22) AS DAY_22_ALL, SUM(monthPlan.DAY_23) AS DAY_23_ALL, SUM(monthPlan.DAY_24) AS DAY_24_ALL, 
    SUM(monthPlan.DAY_25) AS DAY_25_ALL, SUM(monthPlan.DAY_26) AS DAY_26_ALL, SUM(monthPlan.DAY_27) AS DAY_27_ALL, 
    SUM(monthPlan.DAY_28) AS DAY_28_ALL, SUM(monthPlan.DAY_29) AS DAY_29_ALL, SUM(monthPlan.DAY_30) AS DAY_30_ALL, 
    SUM(monthPlan.DAY_31) AS DAY_31_ALL, 
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
    A_STATUS, ROW_TYPE
)
SELECT
    @year   AS YEAR,
    @month  AS MONTH,
    CARE_DIARY_OUID AS CARE_DIARY_OUID,
    SERV_SDU        AS SERV_SDU,
    EXECUTE_TIME    AS EXECUTE_TIME,
    DAY_1  AS DAY_1,  DAY_2  AS DAY_2,  DAY_3  AS DAY_3,  DAY_4  AS DAY_4,  DAY_5  AS DAY_5,  DAY_6  AS DAY_6,  DAY_7  AS DAY_7,
    DAY_8  AS DAY_8,  DAY_9  AS DAY_9,  DAY_10 AS DAY_10, DAY_11 AS DAY_11, DAY_12 AS DAY_12, DAY_13 AS DAY_13, DAY_14 AS DAY_14, 
    DAY_15 AS DAY_15, DAY_16 AS DAY_16, DAY_17 AS DAY_17, DAY_18 AS DAY_18, DAY_19 AS DAY_19, DAY_20 AS DAY_20, DAY_21 AS DAY_21,
    DAY_22 AS DAY_22, DAY_23 AS DAY_23, DAY_24 AS DAY_24, DAY_25 AS DAY_25, DAY_26 AS DAY_26, DAY_27 AS DAY_27, DAY_28 AS DAY_28,
    DAY_29 AS DAY_29, DAY_30 AS DAY_30, DAY_31 AS DAY_31,
    10  AS A_STATUS,
    2   AS ROW_TYPE
FROM #MONTH_PLAN

--------------------------------------------------------------------------------------------------------------------------------
*/