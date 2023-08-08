-- =============================================  
-- Author:  Баташев П.А.  
-- Create date: 03.10.2022  
-- Description:   
/*  
Входные параметры:  
    @year   --Год даты.
    @month  --Месяц даты. 
    @day    --День даты.
Выходные параметры:  
    Дата, собранная из трех ее составляющих.
*/  
-- =============================================  
CREATE FUNCTION [dbo].[fs_getDate](@year INT, @month INT, @day INT)  
RETURNS DATE AS     
BEGIN     
    DECLARE @date DATE = CAST(CAST(@year * 10000 + @month * 100 + @day AS VARCHAR) AS DATE)
    RETURN @date
END  