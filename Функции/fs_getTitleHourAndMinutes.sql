-- =============================================  
-- Author:  Баташев П.А.  
-- Create date: 08.08.2023
-- Description:   
/*  
Входные параметры:  
    @minuteTotal    --Суммарное время в минутах.
    @pattern        --Шаблон строки вывода ({H} - место вставки часов; {M} - место вставки для минут).
Выходные параметры:  
    Суммарное время в минутах, отображенные в строковом представлении в соответствии с шаблоном, отображающего часы и минуты.
*/  
-- =============================================  
CREATE FUNCTION [dbo].[fs_getTitleHourAndMinutes](@minuteTotal INT, @pattern VARCHAR(256) = '{H} ч. {M} мин.')  
RETURNS VARCHAR(256) AS     
BEGIN     
    --Вычисление целых часов и минут.
    DECLARE @hours   VARCHAR(4) = CONVERT(VARCHAR, @minuteTotal / 60)
    DECLARE @minutes VARCHAR(4) = CONVERT(VARCHAR, @minuteTotal % 60)
    IF LEN(@hours) < 2 BEGIN
        SET @hours = '0' + @hours
    END
    IF LEN(@minutes) < 2 BEGIN
        SET @minutes = '0' + @minutes
    END
    --Вставка вычисленных часов и минут в шаблон.
    DECLARE @title VARCHAR(256) = REPLACE(REPLACE(@pattern, 
        '{H}', @hours), 
        '{M}', @minutes
    )
    RETURN @title
END  
