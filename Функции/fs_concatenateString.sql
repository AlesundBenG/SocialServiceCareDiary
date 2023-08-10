-- =============================================  
-- Author:  Баташев П.А.  
-- Create date: 22.02.2023  
-- Description:   
/*  
Входные параметры:  
    @string1    --Первая строка.
    @string2    --Вторая строка.
    @separator  --Разделитель между соединяемыми строками.
Выходные параметры:  
    Строка, состоящая из объединения двух строк и разделителя между ними. 
    В случае, если одна из строк пустая или равняется NULL, то разделитель и соответствующая строка не присоединяется.
*/  
-- =============================================  
ALTER FUNCTION [dbo].[fs_concatenateString](@string1 VARCHAR(MAX),  @string2 VARCHAR(MAX), @separator VARCHAR(MAX))  
RETURNS VARCHAR(MAX) AS     
BEGIN     
    DECLARE @result VARCHAR(MAX)
    SET @result = ISNULL(@string1, '') 
    SET @result = @result + CASE WHEN ISNULL(@string1, '') <> '' AND ISNULL(@string2, '') <> '' THEN  @separator ELSE '' END --Вставка разделителя, в случае наличия обоих строк.
    SET @result = @result + ISNULL(@string2, '')
    RETURN @result
END  