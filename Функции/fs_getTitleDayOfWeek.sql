-- =============================================  
-- Author:  Баташев П.А.  
-- Create date: 08.08.2023
-- Description:   
/*  
Входные параметры:  
    @dayOfWeek  --День недели.
    @monday     --Заголовок понедельника.
    @tuesday    --Заголовок вторника.
    @wednesday  --Заголовок среды.
    @thursday   --Заголовок четверга.
    @friday     --Заголово пятницы.
    @saturday   --Заголовок субботы.
    @sunday     --Заголовок воскресенья.
Выходные параметры:  
    Заголовок дня недели.
*/  
-- =============================================  
CREATE FUNCTION [dbo].[fs_getTitleDayOfWeek](@dayOfWeek INT,  
    @monday     VARCHAR(16) = 'Пн', 
    @tuesday    VARCHAR(16) = 'Вт', 
    @wednesday  VARCHAR(16) = 'Ср', 
    @thursday   VARCHAR(16) = 'Чт', 
    @friday     VARCHAR(16) = 'Пт', 
    @saturday   VARCHAR(16) = 'Сб',
    @sunday     VARCHAR(16) = 'Вс'
)  
RETURNS VARCHAR(16) AS     
BEGIN     
    --Вставка вычисленных часов и минут в шаблон.
    DECLARE @title VARCHAR(16) = CASE @dayOfWeek
        WHEN 1 THEN @monday
        WHEN 2 THEN @tuesday
        WHEN 3 THEN @wednesday
        WHEN 4 THEN @thursday
        WHEN 5 THEN @friday
        WHEN 6 THEN @saturday
        WHEN 7 THEN @sunday
        ELSE ''
    END
    RETURN @title
END  
