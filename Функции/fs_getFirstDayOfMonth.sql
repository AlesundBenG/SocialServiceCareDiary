-- =============================================  
-- Author:  Баташев П.А.  
-- Create date: 19.07.2022  
-- Description:   
/*  
Входные параметры:    
    @year   --Год месяца.  
    @month  --Месяц.  
Выходные параметры:    
    Дата первого дня месяца.  
*/  
-- =============================================  
CREATE FUNCTION [dbo].[fs_getFirstDayOfMonth](@year INT,  @month INT)  
RETURNS DATE AS  
BEGIN  
    DECLARE @firstDayOfMonth DATE = dbo.fs_getDate(@year, @month, 1)
    RETURN @firstDayOfMonth  
END  
