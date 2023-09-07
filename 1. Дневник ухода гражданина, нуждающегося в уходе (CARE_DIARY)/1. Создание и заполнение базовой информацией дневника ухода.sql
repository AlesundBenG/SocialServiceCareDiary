--------------------------------------------------------------------------------------------------------------------------------

--Удаление временных таблиц.
IF OBJECT_ID('tempdb..#SOC_SERV_FOR_CREATE')    IS NOT NULL BEGIN DROP TABLE #SOC_SERV_FOR_CREATE   END --Назначения социального обслжуивания, для которых создается.
IF OBJECT_ID('tempdb..#DESCRIPTOR_CREATION')    IS NOT NULL BEGIN DROP TABLE #DESCRIPTOR_CREATION   END --Дескриптор создания дневников ухода.
IF OBJECT_ID('tempdb..#CREATED')                IS NOT NULL BEGIN DROP TABLE #CREATED               END --Созданные данные.

--------------------------------------------------------------------------------------------------------------------------------

--Создание временных таблиц.
CREATE TABLE #SOC_SERV_FOR_CREATE (
    SERV_DOCUMENT   INT, --Идентификатор договора на социальное обслжуивание.
    SERV_INFO       INT  --Идентификатор содержимого назначения на обслуживание.
)
CREATE TABLE #DESCRIPTOR_CREATION (
    GUID                VARCHAR(36),    --Глобальный идентификатор записи.
    SERV_DOCUMNET       INT,            --Идентификатор договора на социальное обслуживание.
    SERV_INFO           INT,            --Идентификатор содержимого назначения на обслуживание.
    IPPSU_DOCUMENT      INT,            --Идентификатор документа ИППСУ, для которой создан дневник.
    IPPSU_INFO          INT,            --Идентификатор содержимого ИППСУ.
    ADDITION_DOCUMENT   INT,            --Идентификатор документа дополнения к ИППСУ.
    ADDITION_INFO       INT,            --Идентификатор содержимого дополнения. 
    CARE_DIARY_INFO     INT,            --Идентификатор созданного содержимого дневника.
)
CREATE TABLE #CREATED (
    GUID        VARCHAR(36),    --Глобальный идентификатор созданной записи.
    OUID        INT,            --Локальный идентификатор созданной записи.
    TABLE_NAME  VARCHAR(256)    --Наименование таблицы, в которой создана запись.
)

------------------------------------------------------------------------------------------------------------------------------

--Константы.
DECLARE @activeStatus INT = (SELECT A_ID FROM ESRN_SERV_STATUS WHERE A_STATUSCODE = 'act') --Статус действующей (не удаленной) записи.

------------------------------------------------------------------------------------------------------------------------------

--Выбор назначений на социальное обслжуивание для создания дневников.
INSERT INTO #SOC_SERV_FOR_CREATE (SERV_DOCUMENT, SERV_INFO)
SELECT DISTINCT
    document.OUID   AS SERV_DOCUMENT,
    socServ.OUID    AS SERV_INFO
FROM ESRN_SOC_SERV socServ --Назначение социального обслуживания.
----Агрегация по социальным услугам.
    INNER JOIN WM_SOC_SERV_AGR_SDU AGR
        ON AGR.ESRN_SOC_SERV = socServ.OUID
            AND AGR.A_STATUS = @activeStatus
----Договор на социальное обслуживание.
    INNER JOIN WM_ACTDOCUMENTS document
        ON document.OUID = AGR.A_CONTRACT
            AND document.A_STATUS = @activeStatus
WHERE socServ.A_STATUS = @activeStatus
    AND socServ.OUID IN (
        #socServ#
    )

------------------------------------------------------------------------------------------------------------------------------

--Выбор документов ИППСУ, в соответствии которых формируются дневники.
INSERT INTO #DESCRIPTOR_CREATION (GUID, SERV_DOCUMNET, SERV_INFO, IPPSU_DOCUMENT, IPPSU_INFO, ADDITION_DOCUMENT, ADDITION_INFO, CARE_DIARY_INFO)
SELECT
    NEWID()                 AS GUID,
    forCreate.SERV_DOCUMENT AS SERV_DOCUMNET,
    socServ.OUID            AS SERV_INFO,
    documentIPPSU.OUID      AS IPPSU_DOCUMENT,
    IPPSU.A_OUID            AS IPPSU_INFO,
    documentAddition.OUID   AS ADDITION_DOCUMENT,
    addition.A_OUID         AS ADDITION_INFO,
    NULL                    AS CARE_DIARY_INFO --Вставляется значение после вставки записи.
FROM #SOC_SERV_FOR_CREATE forCreate
----Содержимое назначения социального обслуживания.
    INNER JOIN ESRN_SOC_SERV socServ 
        ON socServ.OUID = forCreate.SERV_INFO
----Содержимое ИППСУ.
    INNER JOIN INDIVID_PROGRAM IPPSU
        ON IPPSU.A_OUID = socServ.A_IPPSU
            AND IPPSU.A_STATUS = @activeStatus
----Документы ИППСУ.
    INNER JOIN WM_ACTDOCUMENTS documentIPPSU 
        ON documentIPPSU.OUID = IPPSU.A_DOC
            AND documentIPPSU.A_STATUS = @activeStatus
----Документ дополнения к ИППСУ.
    INNER JOIN WM_ACTDOCUMENTS documentAddition
        ON documentAddition.OUID =  IPPSU.A_DOC_ADD_IPPSU
            AND documentAddition.A_STATUS = @activeStatus
----Содержимое к документу ИППСУ.
    INNER JOIN INDIVID_PROGRAM_ADDITION addition
        ON addition.A_DOCUMENT = documentAddition.OUID
            AND addition.A_STATUS = @activeStatus

------------------------------------------------------------------------------------------------------------------------------

--Создание содержимого дневника ухода.
INSERT INTO CARE_DIARY (GUID, A_CREATEDATE, A_STATUS, DOCUMENT_ADDITION, DOCUMENT_SOC_SERV, SOC_SERV, LEVEL_OF_NEED, DOCUMENT_IPPSU)
OUTPUT inserted.GUID, inserted.A_OUID , 'CARE_DIARY' INTO #CREATED (GUID, OUID, TABLE_NAME) --Записываем в лог вставленные записи.
SELECT
    descriptor.GUID                 AS GUID,
    GETDATE()                       AS A_CREATEDATE,
    @activeStatus                   AS A_STATUS,
    descriptor.ADDITION_DOCUMENT    AS DOCUMENT_ADDITION, 
    descriptor.SERV_DOCUMNET        AS DOCUMENT_SOC_SERV, 
    descriptor.SERV_INFO            AS SOC_SERV,
    IPPSU.LEVEL_OF_NEED             AS LEVEL_OF_NEED,
    descriptor.IPPSU_DOCUMENT       AS DOCUMENT_IPPSU
FROM #DESCRIPTOR_CREATION descriptor --Дескриптор создания.
----Содержимое ИППСУ.
    INNER JOIN INDIVID_PROGRAM IPPSU
        ON IPPSU.A_OUID = descriptor.IPPSU_INFO

--Запись вставленных идентификаторов.
UPDATE descriptor
SET descriptor.CARE_DIARY_INFO = created.OUID
FROM #CREATED created --Созданные документы.
----Дескриптор создания.
    INNER JOIN #DESCRIPTOR_CREATION descriptor 
        ON descriptor.GUID = created.GUID
WHERE created.TABLE_NAME = 'CARE_DIARY'

------------------------------------------------------------------------------------------------------------------------------

--Заполнение "Основные цели ухода".
INSERT INTO CARE_DIARY_PURPOSE (A_CREATEDATE, A_STATUS, PURPOSE_TYPE, CARE_DIARY_OUID)
OUTPUT NULL, inserted.A_OUID , 'CARE_DIARY_PURPOSE' INTO #CREATED (GUID, OUID, TABLE_NAME) --Записываем в лог вставленные записи.
SELECT
    GETDATE()                   AS A_CREATEDATE,
    @activeStatus               AS A_STATUS,
    purpose.A_OUID              AS PURPOSE_TYPE,
    descriptor.CARE_DIARY_INFO  AS CARE_DIARY_OUID
FROM #DESCRIPTOR_CREATION descriptor  --Дескриптор создания.
----Справочник основных целей ухода.
    INNER JOIN SPR_CARE_PURPOSE purpose
        ON purpose.A_STATUS = @activeStatus

------------------------------------------------------------------------------------------------------------------------------

--Заполнение "Перечень медицинских рекомендаций".
INSERT INTO CARE_DIARY_RECOMMENDATION (A_CREATEDATE, A_STATUS, RECOMMENDATION_TYPE, CARE_DIARY_OUID)
OUTPUT NULL, inserted.A_OUID , 'CARE_DIARY_RECOMMENDATION' INTO #CREATED (GUID, OUID, TABLE_NAME) --Записываем в лог вставленные записи.
SELECT
    GETDATE()                   AS A_CREATEDATE,
    @activeStatus               AS A_STATUS,
    recommendation.A_OUID       AS RECOMMENDATION_TYPE,
    descriptor.CARE_DIARY_INFO  AS CARE_DIARY_OUID
FROM #DESCRIPTOR_CREATION descriptor  --Дескриптор создания.
----Справочник медицинских рекомендаций.
    INNER JOIN SPR_MEDICAL_RECOMMENDATION recommendation
        ON recommendation.A_STATUS = @activeStatus

------------------------------------------------------------------------------------------------------------------------------

--Заполнение "Индивидуальные особенности гражданина".
INSERT INTO CARE_DIARY_FEATURES (A_CREATEDATE, A_STATUS, FEATURES_TYPE, CARE_DIARY_OUID)
OUTPUT NULL, inserted.A_OUID , 'CARE_DIARY_FEATURES' INTO #CREATED (GUID, OUID, TABLE_NAME) --Записываем в лог вставленные записи.
SELECT
    GETDATE()                   AS A_CREATEDATE,
    @activeStatus               AS A_STATUS,
    features.A_OUID             AS FEATURES_TYPE,
    descriptor.CARE_DIARY_INFO  AS CARE_DIARY_OUID
FROM #DESCRIPTOR_CREATION descriptor  --Дескриптор создания.
----Справочник индивидуальных особенностей гражданина.
    INNER JOIN SPR_INDIVIDUAL_FEATURES features
        ON features.A_STATUS = @activeStatus

------------------------------------------------------------------------------------------------------------------------------

--Заполнение графика работы.
INSERT INTO CARE_DIARY_WORK_PLAN (A_CREATEDATE, A_STATUS, VISIT_NUMBER, MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY, CARE_DIARY_OUID)
OUTPUT NULL, inserted.A_OUID , 'CARE_DIARY_WORK_PLAN' INTO #CREATED (GUID, OUID, TABLE_NAME) --Записываем в лог вставленные записи.
SELECT
    GETDATE()                                       AS A_CREATEDATE,
    @activeStatus                                   AS A_STATUS,
    visit.NUMBER                                    AS VISIT_NUMBER,
    0                                               AS MONDAY,
    0                                               AS TUESDAY,
    0                                               AS WEDNESDAY,
    0                                               AS THURSDAY,
    0                                               AS FRIDAY,
    0                                               AS SATURDAY,
    0                                               AS SUNDAY,
    descriptor.CARE_DIARY_INFO                      AS CARE_DIARY_OUID
FROM #DESCRIPTOR_CREATION descriptor  --Дескриптор создания.
----Возможные номера посещения.
    CROSS JOIN (    
        SELECT 1 AS NUMBER 
        UNION SELECT 2 AS NUMBER 
        UNION SELECT 3 AS NUMBER 
    ) visit
WHERE descriptor.CARE_DIARY_INFO IS NOT NULL

--Простановка флагов посещения.
UPDATE workPlan
SET workPlan.MONDAY     = CASE WHEN workPlan.VISIT_NUMBER <= maxCountVisitOnDay.MONDAY      THEN 1 ELSE 0 END,  --Если посещений 0, то ни у какого посещения будет поставлен флаг.
    workPlan.TUESDAY    = CASE WHEN workPlan.VISIT_NUMBER <= maxCountVisitOnDay.TUESDAY     THEN 1 ELSE 0 END,  --Если посещений 1, то у посещения №1 поставится флаг.
    workPlan.WEDNESDAY  = CASE WHEN workPlan.VISIT_NUMBER <= maxCountVisitOnDay.WEDNESDAY   THEN 1 ELSE 0 END,  --Если посещений 2, то у посещения №1, №2 будут поставлены флаги.
    workPlan.THURSDAY   = CASE WHEN workPlan.VISIT_NUMBER <= maxCountVisitOnDay.THURSDAY    THEN 1 ELSE 0 END,  --Если посещений 3, то у посещения №1, №2, №3 будут поставены флаги.
    workPlan.FRIDAY     = CASE WHEN workPlan.VISIT_NUMBER <= maxCountVisitOnDay.FRIDAY      THEN 1 ELSE 0 END,  --И т.д.
    workPlan.SATURDAY   = CASE WHEN workPlan.VISIT_NUMBER <= maxCountVisitOnDay.SATURDAY    THEN 1 ELSE 0 END,
    workPlan.SUNDAY     = CASE WHEN workPlan.VISIT_NUMBER <= maxCountVisitOnDay.SUNDAY      THEN 1 ELSE 0 END 
FROM (
    SELECT
        descriptor.CARE_DIARY_INFO                                          AS CARE_DIARY_INFO,
        MAX(CASE WHEN visit.A_MONDAY_FLAG   = 1 THEN A_WEEK_DAY ELSE 0 END) AS MONDAY,
        MAX(CASE WHEN visit.A_TUESDAY_FLAG  = 1 THEN A_WEEK_DAY ELSE 0 END) AS TUESDAY,
        MAX(CASE WHEN visit.A_WEDNESDAY_FLAG= 1 THEN A_WEEK_DAY ELSE 0 END) AS WEDNESDAY,
        MAX(CASE WHEN visit.A_THURSDAY_FLAG = 1 THEN A_WEEK_DAY ELSE 0 END) AS THURSDAY,
        MAX(CASE WHEN visit.A_FRIDAY_FLAG   = 1 THEN A_WEEK_DAY ELSE 0 END) AS FRIDAY,
        MAX(CASE WHEN visit.A_SATURDAY_FLAG = 1 THEN A_WEEK_DAY ELSE 0 END) AS SATURDAY,
        MAX(CASE WHEN visit.A_SUNDAY_FLAG   = 1 THEN A_WEEK_DAY ELSE 0 END) AS SUNDAY
    FROM #DESCRIPTOR_CREATION descriptor  --Дескриптор создания.
    ----Количество посещений по дням недели (Дополнение к ИППСУ).
        INNER JOIN INDIVID_PROGRAM_ADDITION_DAYS_OF_VISIT visit
            ON visit.A_IPPSU_ADDITION = descriptor.ADDITION_INFO
                AND visit.A_STATUS = @activeStatus
    GROUP BY descriptor.CARE_DIARY_INFO
) maxCountVisitOnDay
----Созданные планы.
    INNER JOIN CARE_DIARY_WORK_PLAN workPlan
        ON workPlan.CARE_DIARY_OUID = maxCountVisitOnDay.CARE_DIARY_INFO

------------------------------------------------------------------------------------------------------------------------------