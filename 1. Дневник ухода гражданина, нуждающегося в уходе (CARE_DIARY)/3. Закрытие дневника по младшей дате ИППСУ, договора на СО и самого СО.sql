------------------------------------------------------------------------------------------------------------------------------

--Константы.
DECLARE @activeStatus       INT = (SELECT A_ID FROM ESRN_SERV_STATUS WHERE A_STATUSCODE = 'act')    --Статус действующей (не удаленной) записи.
DECLARE @docTypeCareDiary   INT = (SELECT A_ID FROM PPR_DOC WHERE A_CODE = 'CareDiary')             --Идентификатор типа документа дневника ухода.

------------------------------------------------------------------------------------------------------------------------------

--Изменение даты окончания дневника ухода по самой младшей дате из ИППСУ, договора и СО.
--В случае, если ни с одним из перечисленных объектов нет связи, то ставится текущая дата. 
UPDATE forUpdate
SET forUpdate.COMPLETIONSACTIONDATE = CASE 
    WHEN dateLast.DELETED_ALL = 1 
        THEN CONVERT(DATE, GETDATE()) --Если все связки удалены, то ставим текущую дату в качестве окончания.
        ELSE dbo.fs_getMinDate(dbo.fs_getMinDate(dateLast.DOCUMENT_SERV_DATE_END, dateLast.DOCUMENT_IPPSU_DATE_END), dateLast.SOC_SERV_DATE_END)
END 
FROM (
    SELECT
        documentDiary.OUID                                          AS DOCUMENT_DIARY_OUID,
        CASE WHEN documentServ.OUID IS NULL 
            AND documentIPPSU.OUID IS NULL 
            AND socServ.OUID IS NULL
            THEN 1 ELSE 0 
        END                                                         AS DELETED_ALL,
        CONVERT(DATE, documentDiary.COMPLETIONSACTIONDATE)          AS DOCUMENT_DIARY_DATE_END,
        CASE WHEN documentServ.OUID IS NOT NULL 
            THEN CONVERT(DATE, documentServ.COMPLETIONSACTIONDATE)   
            ELSE NULL
        END                                                         AS DOCUMENT_SERV_DATE_END,
        CASE WHEN documentIPPSU.OUID IS NOT NULL  
            THEN CONVERT(DATE, documentIPPSU.COMPLETIONSACTIONDATE)
            ELSE NULL
        END                                                         AS DOCUMENT_IPPSU_DATE_END,
        CASE WHEN socServ.OUID IS NOT NULL THEN 
            CONVERT(DATE, period.A_LASTDATE)
            ELSE NULL
        END                                                         AS SOC_SERV_DATE_END,
        ROW_NUMBER() OVER (PARTITION BY documentDiary.OUID ORDER BY period.STARTDATE DESC) AS gnum
    FROM CARE_DIARY careDiary --Дневник ухода гражданина, нуждающегося в уходе.
    ----Документ дневника.
        INNER JOIN WM_ACTDOCUMENTS documentDiary
            ON documentDiary.OUID = careDiary.DOCUMENT_OUID
                AND documentDiary.A_STATUS = @activeStatus
                AND documentDiary.DOCUMENTSTYPE = @docTypeCareDiary
    ----Договор назначения на социальное обслуживание.
        LEFT JOIN WM_ACTDOCUMENTS documentServ
            ON documentServ.OUID = careDiary.DOCUMENT_SOC_SERV
                AND documentServ.A_STATUS = @activeStatus
    ----Документ индивидуальной программы.
        LEFT JOIN WM_ACTDOCUMENTS documentIPPSU
            ON documentIPPSU.OUID = careDiary.DOCUMENT_IPPSU
                AND documentIPPSU.A_STATUS = @activeStatus
    ----Назначение на социальное обслуживание.
        LEFT JOIN ESRN_SOC_SERV socServ
            ON socServ.OUID = careDiary.SOC_SERV
                AND socServ.A_STATUS = @activeStatus
    ----Период предоставления МСП.        
        LEFT JOIN SPR_SOCSERV_PERIOD period
            ON period.A_SERV = socServ.OUID 
                AND period.A_STATUS = @activeStatus                
    WHERE careDiary.A_STATUS = @activeStatus
) dateLast
----Документы для изменения.
    INNER JOIN WM_ACTDOCUMENTS forUpdate
        ON forUpdate.OUID = dateLast.DOCUMENT_DIARY_OUID
WHERE dateLast.gnum = 1
    AND (dateLast.DOCUMENT_DIARY_DATE_END <> dbo.fs_getMinDate(dbo.fs_getMinDate(dateLast.DOCUMENT_SERV_DATE_END, dateLast.DOCUMENT_IPPSU_DATE_END), dateLast.SOC_SERV_DATE_END)
        OR dateLast.DOCUMENT_DIARY_DATE_END IS NULL AND dbo.fs_getMinDate(dbo.fs_getMinDate(dateLast.DOCUMENT_SERV_DATE_END, dateLast.DOCUMENT_IPPSU_DATE_END), dateLast.SOC_SERV_DATE_END) IS NOT NULL
        OR dateLast.DOCUMENT_DIARY_DATE_END IS NOT NULL AND dbo.fs_getMinDate(dbo.fs_getMinDate(dateLast.DOCUMENT_SERV_DATE_END, dateLast.DOCUMENT_IPPSU_DATE_END), dateLast.SOC_SERV_DATE_END) IS NULL
        OR dateLast.DELETED_ALL = 1
    )