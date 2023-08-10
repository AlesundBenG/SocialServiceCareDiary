-- =============================================  
-- Author:  Баташев П.А.  
-- Create date: 19.07.2022  
-- Description:   
/*  
Входные параметры:    
    @year   --Год месяца.  
    @month  --Месяц.  
Выходные параметры:    
    Дата последнего дня месяца.   
*/  
-- =============================================  
CREATE FUNCTION [dbo].[fs_getLastDayOfMonth](@year INT,  @month INT)  
RETURNS DATE AS  
BEGIN  
    DECLARE @firstDayOfMonth        DATE = dbo.fs_getFirstDayOfMonth(@year, @month)  
    DECLARE @firstDayOfNextMonth    DATE = DATEADD(MONTH, 1, @firstDayOfMonth)  
    DECLARE @lastDayOfMonth         DATE = DATEADD(DAY, - 1, @firstDayOfNextMonth)  
    RETURN @lastDayOfMonth
END  