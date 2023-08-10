-- =============================================    
-- Author:  Баташев П.А.    
-- Create date: 23.06.2022    
-- Description:     
/*    
Входные параметры:    
    @firstPeriodStart   --Дата начала 1 периода (Может быть типа DATETIME, DATETIME2, VARCHAR).    
    @firstPeriodEnd     --Дата окончания 1 периода (Может быть типа DATETIME, DATETIME2, VARCHAR).     
    @secondPeriodStart  --Дата начала 2 периода (Может быть типа DATETIME, DATETIME2, VARCHAR).    
    @secondPeriodEnd    --Дата окончания 2 периода (Может быть типа DATETIME, DATETIME2, VARCHAR).     
    @borderConsidered   --Учитывать ли в качестве пересечения соприкосновения границ периодов. (borderConsidered, borderNotConsidered)    
Выходные параметры:    
    Пересекаются ли периоды.    
*/    
-- =============================================    
CREATE FUNCTION [dbo].[fs_thisPeriodsCross] (@firstPeriodStart DATE, @firstPeriodEnd DATE, @secondPeriodStart DATE, @secondPeriodEnd DATE, @borderConsidered INT = 1)    
RETURNS BIT AS     
BEGIN    
    DECLARE @thisPeriodsCross BIT    
    IF (@borderConsidered = 1) BEGIN     
        SET @thisPeriodsCross = CASE    
            WHEN (@firstPeriodStart < @secondPeriodEnd OR @firstPeriodStart IS NULL OR @secondPeriodEnd IS NULL)    
                AND (@firstPeriodEnd > @secondPeriodStart OR @firstPeriodEnd IS NULL OR @secondPeriodStart IS NULL)  
            THEN 1    
            ELSE 0    
        END    
    END    
    ELSE BEGIN    
        SET @thisPeriodsCross = CASE    
            WHEN (@firstPeriodStart <= @secondPeriodEnd OR @firstPeriodStart IS NULL OR @secondPeriodEnd IS NULL)    
                AND (@firstPeriodEnd >= @secondPeriodStart OR @firstPeriodEnd IS NULL OR @secondPeriodStart IS NULL)  
            THEN 1    
            ELSE 0    
        END    
    END    
    RETURN @thisPeriodsCross    
END 