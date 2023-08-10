-- =============================================  
-- Author:  Баташев П.А.  
-- Create date: 19.07.2023  
-- Description:   
/*  
Входные параметры:    
    @date --Дата, для которой необходимо определить номер недели.
Выходные параметры:    
    Номер недели, в которой находится указанная дата. 
*/  
-- =============================================  
ALTER FUNCTION [dbo].[fs_getNumberWeekOfMonth](@date DATE)  
RETURNS INT AS  
BEGIN  
    DECLARE @firstDayOfMonth DATE = dbo.fs_getFirstDayOfMonth(YEAR(@date), MONTH(@date))
    DECLARE @weekNumber INT = 1 
    DECLARE @weekLastDay DATE = dbo.fs_getLastDayOfWeek(@firstDayOfMonth)
    --Сдвигаем недели и ждем, пока последний день текущей недели не будет больше или равен указанной даты.
    WHILE @weekLastDay < @date BEGIN
        SET @weekNumber = @weekNumber + 1 
        SET @weekLastDay = DATEADD(DAY, 7, @weekLastDay)    
    END
    RETURN @weekNumber
END  
