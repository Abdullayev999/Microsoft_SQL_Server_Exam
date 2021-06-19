CREATE DATABASE EventsPosters

GO
USE EventsPosters


CREATE TABLE Countries
(
    Id INT PRIMARY KEY IDENTITY,
	[Name] NVARCHAR(30) NOT NULL,

	CONSTRAINT CK_Countrys_Name CHECK([Name] != ' '),
	CONSTRAINT UQ_Countrys_Name UNIQUE([Name])
)


CREATE TABLE Cities
(
    Id INT PRIMARY KEY IDENTITY,
	[Name] NVARCHAR(30) NOT NULL,

	CONSTRAINT CK_Cities_Name CHECK([Name] != ' '),
	CONSTRAINT UQ_Cities_Name UNIQUE([Name])
)
   

CREATE TABLE Categories
(
    Id INT PRIMARY KEY IDENTITY,
	[Name] NVARCHAR(30) NOT NULL,

	CONSTRAINT CK_Categories_Name CHECK([Name] != ' '),
	CONSTRAINT UQ_Categories_Name UNIQUE([Name])
)
 

CREATE TABLE Providences 
(
    Id INT PRIMARY KEY IDENTITY,
	CountriyId INT NOT NULL,
	CityId INT NOT NULL,
	Street nvarchar(50) NOT NULL,  

	CONSTRAINT FK_Providences_CountriyId FOREIGN KEY (CountriyId) REFERENCES Countries(Id),
	CONSTRAINT FK_Providences_CityId FOREIGN KEY (CityId) REFERENCES Cities(Id),
	CONSTRAINT CK_Providences_Street CHECK(Street != ' ')
 )
  

CREATE TABLE Clients
(
	 Id INT PRIMARY KEY IDENTITY,
	 FullName NVARCHAR(30) NOT NULL, 
	 Email NVARCHAR(30) ,--почта может и не быть
	 YearOfBirth DATE NOT NULL,
	   
	 CONSTRAINT CK_Clients_FullName CHECK(FullName != ' '),
	 CONSTRAINT CK_Clients_YearOfBirth CHECK((Year(GETDATE()) - YEAR(YearOfBirth) BETWEEN 5 AND 85)), --врядли 85+ клиенты будут
	 --CONSTRAINT UQ_Clients_FullName UNIQUE(FullName),
	 -- из за нижнего задания убрал уникальность, буду проверять через трригер
	 --(При вставке нового клиента нужно проверять, нет ли его уже в базе данных. Если такой клиент есть, генерировать ошибку с описанием возникшей проблемы)
) 
   
   

CREATE TABLE Images 
(
    Id INT PRIMARY KEY IDENTITY,
	Files VARBINARY(MAX) NOT NULL
)



CREATE TABLE Events
(
	 Id INT PRIMARY KEY IDENTITY,
	 [Name] NVARCHAR(30) NOT NULL, 
	 CategoriyId INT NOT NULL, 
	 [Description] TEXT NOT NULL, 
	 Restriction INT NOT NULL DEFAULT(6), 
	 ImageId INT NOT NULL, 

	 CONSTRAINT CK_Events_Name CHECK([Name] != ' '),
	 CONSTRAINT CK_Events_Restriction CHECK(Restriction BETWEEN 6 AND 18), 
     CONSTRAINT FK_Events_CategoriyId FOREIGN KEY (CategoriyId) REFERENCES Categories(Id), 
	 CONSTRAINT FK_Events_ImageId FOREIGN KEY (ImageId) REFERENCES Images(Id),
	 --CONSTRAINT UQ_Events_Name UNIQUE([Name])
	 -- из за нижнего задания убрал уникальность, буду проверять через трригер
	 --При вставке нового события нужно проверять, нет ли его уже в базе данных. Если такое событие есть, генерировать ошибку с описанием возникшей проблемы
)  
   


CREATE TABLE Schedules
(
    Id INT PRIMARY KEY IDENTITY,
	EventId INT NOT NULL,
	ProvidenceId INT NOT NULL,
	CountTickets INT NOT NULL ,
	[DateTime] DATETIME NOT NULL, 
	DurationDay INT NOT NULL DEFAULT(1),
	SoldTickets INT NOT NULL DEFAULT(0), 
	[Status] NVARCHAR(30) NOT NULL DEFAULT('Planned'), --планируеться

	CONSTRAINT FK_Schedules_EventId FOREIGN KEY (EventId) REFERENCES Events(Id),
	CONSTRAINT CK_Schedules_CountTickets CHECK(CountTickets>=100),--обычно минимум зрителей 100
	CONSTRAINT FK_Schedules_ProvidenceId FOREIGN KEY (ProvidenceId) REFERENCES Providences(Id)
 )


 CREATE TABLE Archives
(
	Id INT PRIMARY KEY IDENTITY, 
	EventId INT NOT NULL,
	ProvidenceId INT NOT NULL,
	CountTickets INT NOT NULL ,
	[DateTime] DATETIME NOT NULL, 
	DurationDay INT NOT NULL ,
	SoldTickets INT NOT NULL DEFAULT(0), 
	[Status] NVARCHAR(30) NOT NULL DEFAULT('Completed successfully'), 

	CONSTRAINT FK_Archives_EventId FOREIGN KEY (EventId) REFERENCES Events(Id),
	CONSTRAINT CK_Archives_CountTickets CHECK(CountTickets>=100),--обычно минимум зрителей 100
	CONSTRAINT FK_Archives_ProvidenceId FOREIGN KEY (ProvidenceId) REFERENCES Providences(Id)
)  



 CREATE TABLE Sales
(
	Id INT PRIMARY KEY IDENTITY,
	ScheduleId INT NOT NULL, 
	CountTickets INT NOT NULL , 
	ClientId INT NOT NULL,
	[Date] DATE NOT NULL DEFAULT(GETDATE()), --время продажи билета для нижнего задания

	CONSTRAINT FK_Sales_ScheduleId FOREIGN KEY (ScheduleId) REFERENCES Schedules(Id),
	CONSTRAINT FK_Sales_ClientId FOREIGN KEY (ClientId) REFERENCES Clients(Id),  
	CONSTRAINT CK_Sales_CountTickets CHECK(CountTickets>=1) 
) 

 

--Тригер Архивирует мероприятие если оно произошло уже
CREATE TRIGGER FineshedEvents ON Schedules
INSTEAD OF INSERT
AS
BEGIN
	   DECLARE @DateTime DATETIME;
	   DECLARE @DurationDay INT;    --продолжительность мероприятия
	   DECLARE @ProvidenceId INT;
	   DECLARE @CountTickets INT;
	   DECLARE @SoldTickets INT;
	   DECLARE @EventId INT;

       SELECT @DateTime=inserted.[DateTime],@DurationDay=inserted.DurationDay,@ProvidenceId = inserted.ProvidenceId,
	          @CountTickets = inserted.CountTickets,@SoldTickets = inserted.SoldTickets,@EventId = inserted.EventId
	   FROM inserted

	   IF DATEADD(DAY, @DurationDay, @DateTime) < GETDATE()
	       BEGIN -- завершившиеся мероприятие
				insert into Archives (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) 
				values (@EventId, @ProvidenceId, @CountTickets, @DateTime, @DurationDay);
	       END
	   ELSE
	       BEGIN -- меровприятие которое в процессе или ещё не начилось
				insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) 
				values (@EventId, @ProvidenceId, @CountTickets, @DateTime, @DurationDay);
	       END
END
 

 --- При вставке нового клиента нужно проверять, нет ли его уже в базе данных. Если такой клиент есть, генерировать ошибку с описанием возникшей проблемы

CREATE TRIGGER AddClientCheck ON Clients
INSTEAD OF INSERT
AS
BEGIN 
		DECLARE @FullName NVARCHAR(30);
		DECLARE @YearOfBirth DATE;
		DECLARE @Email NVARCHAR(30); 

          SELECT @FullName = inserted.FullName , @YearOfBirth = inserted.YearOfBirth , @Email = inserted.Email
		  FROM inserted

		  DECLARE @Check INT;
		  
		  SELECT @Check = Id 
		  FROM Clients
		  WHERE @FullName LIKE FullName AND @Email LIKE Email AND @YearOfBirth LIKE YearOfBirth

		  IF @Check IS NULL
			BEGIN
					insert into Clients (FullName, Email, YearOfBirth) 
					values (@FullName, @Email, @YearOfBirth);
			END
		 ELSE 
			PRINT 'This client exists , adding canceled'
END

 


 --- При удалении прошедших событий необходимо их переносить в архив событий  
--(Противоречит тригеру (--Тригер Архивирует мероприятие если оно произошло уже))
-- Поменял условие на это
-- При удалении события из расписания поместить его в Архим и пометить как Отмененое событие

CREATE TRIGGER DeleteEvent ON Schedules
INSTEAD OF DELETE 
AS 
BEGIN
       DECLARE @DateTime DATETIME;
	   DECLARE @DurationDay INT;   
	   DECLARE @ProvidenceId INT;
	   DECLARE @CountTickets INT;
	   DECLARE @SoldTickets INT;
	   DECLARE @EventId INT;
	   DECLARE @Status NVARCHAR(30) = 'Annulled' --анулирован


       SELECT @DateTime=deleted.[DateTime],@DurationDay=deleted.DurationDay,@ProvidenceId = deleted.ProvidenceId,
	          @CountTickets = deleted.CountTickets,@SoldTickets = deleted.SoldTickets,@EventId = deleted.EventId
	   FROM deleted

	    insert into Archives (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay,[Status]) 
		values (@EventId, @ProvidenceId, @CountTickets, @DateTime, @DurationDay,@Status); 
END





--- При вставке нового события нужно проверять, нет ли его уже в базе данных. Если такое событие есть, генерировать ошибку с описанием возникшей проблемы

CREATE TRIGGER AddEventCheck ON Events
INSTEAD OF INSERT
AS
BEGIN 
		DECLARE @Name NVARCHAR(30);
		DECLARE @CategoryId INT;
		DECLARE @Description NVARCHAR(MAX); 
		DECLARE @Restriction INT;
		DECLARE @ImageId INT;
		 
          SELECT @Name = [Name] , @Description = [Description] , @Restriction = Restriction,
		         @CategoryId = CategoriyId ,@ImageId = ImageId
		  FROM inserted

		  DECLARE @Check INT;
		  
		  SELECT @Check = Id 
		  FROM Events
		  WHERE @Name LIKE [Name] AND @Description LIKE [Description] AND @Restriction LIKE Restriction AND
		         @CategoryId LIKE CategoriyId AND @ImageId LIKE ImageId

		  IF @Check IS NULL
			BEGIN
					insert into Events (Restriction, [Name], CategoriyId, [Description], ImageId) 
                    values (@Restriction,@Name, @CategoryId, @Description, @ImageId);  
			END
		 ELSE 
			PRINT 'This event exists , adding canceled'
END






 --Тригер выполняет следущие функции  
--уменьшает количество билетов в налиичии при продаже билетов ( проверка количество свободных билетов)
--При попытке покупки билета проверять не достигнуто ли уже максимальное количество билетов.
--Если максимальное количество достигнуто, генерировать ошибку с информацией о возникшей проблеме
--При попытке покупки билета проверять возрастные ограничения. Если возрастное ограничение нарушено, генерировать ошибку с информацией о возникшей проблеме

 CREATE TRIGGER SellTicketsCheckAgeAndIsTicket ON Sales
 INSTEAD OF INSERT
 AS
 BEGIN
		 DECLARE @CountBuyTicketsByClient INT;
		 DECLARE @AllQuantityTickets INT;
		 DECLARE @AllSoldTickets INT;
		 DECLARE @IdSchedule INT;
		 DECLARE @ScheduleId INT;
		 DECLARE @ClientId INT; 
		 DECLARE @ClientAge INT;
		 DECLARE @EventAgeRestriction INT;

		 SELECT @IdSchedule = Schedules.Id, @CountBuyTicketsByClient = inserted.CountTickets  , @ScheduleId = Schedules.Id,
		        @AllSoldTickets = Schedules.SoldTickets , @AllQuantityTickets = Schedules.CountTickets , @ClientId = inserted.ClientId,
				@EventAgeRestriction = Events.Restriction,@ClientAge = YEAR(GETDATE())-YEAR(Clients.YearOfBirth)
		 FROM inserted ,Schedules ,Events,Clients
		 WHERE inserted.ScheduleId  = Schedules.Id AND Schedules.EventId = Events.Id AND Clients.Id = inserted.ClientId
		  
		IF	@ClientAge >= @EventAgeRestriction
			BEGIN --клиент проходит возрастную категорию мероприятия 
				 IF @AllQuantityTickets > @AllSoldTickets
					BEGIN
					    IF	@AllQuantityTickets >= (@AllSoldTickets + @CountBuyTicketsByClient)
				        	BEGIN -- Билеты есть в наличии 
						    
							UPDATE Schedules --обновляем количество проданных билетов
						    SET SoldTickets = SoldTickets + @CountBuyTicketsByClient
					        WHERE Id = @IdSchedule

						    insert into Sales (ScheduleId, CountTickets, ClientId) 
						    values (@ScheduleId,@CountBuyTicketsByClient, @ClientId);
		        	        END
	                    ELSE 
			                PRINT 'This number of tickets is not available'  -- Билеты нет в наличии  
					END
				ELSE 
					PRINT 'All tickets sold out'
			END
		ELSE
		PRINT 'The client does not pass the age category of the event'  -- не проходит по возрастному категорию
 END
   
  
BULK INSERT Countries
FROM 'C:\ExamSql\Countries.csv'
WITH (
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n'
)

BULK INSERT Cities
FROM 'C:\ExamSql\Cities.csv'
WITH (
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n'
)

BULK INSERT Categories
FROM 'C:\ExamSql\Categories.csv'
WITH (
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n'
)

BULK INSERT Providences
FROM 'C:\ExamSql\Providences.csv'
WITH (
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n'
)

BULK INSERT Clients
FROM 'C:\ExamSql\Clients.csv'
WITH (
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n'
)
							   
														   
(SELECT BulkColumn FROM OPENROWSET(BULK N'C:\ExamSql\1.jpg', SINGLE_BLOB) image);
insert into Images (Files) 
(SELECT BulkColumn FROM OPENROWSET(BULK N'C:\ExamSql\2.jpg', SINGLE_BLOB) image);
insert into Images (Files) 
(SELECT BulkColumn FROM OPENROWSET(BULK N'C:\ExamSql\3.jpg', SINGLE_BLOB) image);
insert into Images (Files) 
(SELECT BulkColumn FROM OPENROWSET(BULK N'C:\ExamSql\4.jpg', SINGLE_BLOB) image);
insert into Images (Files) 
(SELECT BulkColumn FROM OPENROWSET(BULK N'C:\ExamSql\5.jpg', SINGLE_BLOB) image); 
insert into Images (Files) 
(SELECT BulkColumn FROM OPENROWSET(BULK N'C:\ExamSql\6.jpg', SINGLE_BLOB) image);  
insert into Images (Files) 
(SELECT BulkColumn FROM OPENROWSET(BULK N'C:\ExamSql\7.jpg', SINGLE_BLOB) image);
  

BULK INSERT Events
FROM 'C:\ExamSql\Events.csv'
WITH (
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n'
) 



-- Если добовлять через булк инсерт то тригеры которые я на них повесил
-- не сработают поэтому придеться добавить в коде
 
-- BULK INSERT Schedules
--FROM 'C:\ExamSql\Schedules.csv'
--WITH (
--	FIELDTERMINATOR = ',',
--	ROWTERMINATOR = '\n'
--)



-- BULK INSERT Sales
--FROM 'C:\ExamSql\Sales.csv'
--WITH (
--	FIELDTERMINATOR = ',',
--	ROWTERMINATOR = '\n'
--)


 
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 8, 669, '2020-10-08 13:21:30', 1); 
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 4, 594, '2020-12-30 05:38:06', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (1, 10, 495, '2021-07-25 00:59:54', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 8, 686, '2020-10-28 14:55:55', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 4, 352, '2022-04-30 19:09:01', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 5, 298, '2021-02-26 21:00:38', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 7, 912, '2021-09-19 21:44:39', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 9, 313, '2020-07-14 14:22:58', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 6, 127, '2021-01-30 02:34:43', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 2, 282, '2021-08-12 15:03:24', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (4, 6, 345, '2022-05-06 05:28:43', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 6, 452, '2021-07-03 21:45:29', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (4, 4, 407, '2021-09-29 05:01:54', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 2, 852, '2020-07-28 02:23:55', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (1, 9, 516, '2022-01-23 13:13:48', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 6, 314, '2022-03-07 01:00:23', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 3, 927, '2022-05-18 03:26:12', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 3, 359, '2022-03-28 19:48:51', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 7, 191, '2022-03-01 11:52:37', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 2, 101, '2020-10-15 00:48:44', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 4, 627, '2021-11-10 00:21:39', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 8, 328, '2021-05-28 17:18:15', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 6, 921, '2022-04-09 04:24:52', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (4, 6, 432, '2021-12-21 22:35:54', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 10, 201, '2020-08-09 09:47:38', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 1, 824, '2022-04-17 13:55:41', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 8, 506, '2021-12-12 19:46:03', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 5, 522, '2021-03-08 22:35:11', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 1, 867, '2021-04-03 18:53:11', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (1, 7, 532, '2021-11-16 05:41:43', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 10, 833, '2020-10-11 08:33:45', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 1, 484, '2021-06-26 11:06:28', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 3, 426, '2021-01-13 22:17:44', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 7, 593, '2020-06-22 04:06:26', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 2, 110, '2021-05-19 07:07:53', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 10, 810, '2021-04-10 11:16:15', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 1, 701, '2021-10-03 11:07:33', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 7, 555, '2021-08-10 09:58:36', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (1, 9, 769, '2021-11-20 10:33:57', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 7, 563, '2021-09-20 19:08:19', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (1, 9, 878, '2022-02-09 02:21:28', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (3, 4, 250, '2021-12-11 20:16:30', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (1, 2, 710, '2021-02-26 23:40:25', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (4, 3, 959, '2021-07-13 19:53:09', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (1, 1, 468, '2020-12-21 19:51:42', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (1, 4, 952, '2022-05-13 03:18:59', 1);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (4, 8, 747, '2020-10-19 09:05:30', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 2, 769, '2020-06-30 04:39:04', 2);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (5, 9, 371, '2022-02-13 02:01:50', 3);
insert into Schedules (EventId, ProvidenceId, CountTickets, [DateTime], DurationDay) values (2, 7, 939, '2021-05-23 07:30:01', 2);
 

insert into Sales (ScheduleId, CountTickets, ClientId) values (11, 4, 9);
insert into Sales (ScheduleId, CountTickets, ClientId) values (22, 3, 47);
insert into Sales (ScheduleId, CountTickets, ClientId) values (3, 1, 2);
insert into Sales (ScheduleId, CountTickets, ClientId) values (4, 4, 33);
insert into Sales (ScheduleId, CountTickets, ClientId) values (5, 5, 33);
insert into Sales (ScheduleId, CountTickets, ClientId) values (6, 4, 35);
insert into Sales (ScheduleId, CountTickets, ClientId) values (7, 5, 43);
insert into Sales (ScheduleId, CountTickets, ClientId) values (8, 5, 11);
insert into Sales (ScheduleId, CountTickets, ClientId) values (9, 1, 9);
insert into Sales (ScheduleId, CountTickets, ClientId) values (10, 3, 22);
insert into Sales (ScheduleId, CountTickets, ClientId) values (11, 1, 29);
insert into Sales (ScheduleId, CountTickets, ClientId) values (12, 2, 34);
insert into Sales (ScheduleId, CountTickets, ClientId) values (13, 1, 9);
insert into Sales (ScheduleId, CountTickets, ClientId) values (14, 5, 17);
insert into Sales (ScheduleId, CountTickets, ClientId) values (15, 4, 44);
insert into Sales (ScheduleId, CountTickets, ClientId) values (16, 5, 29);
insert into Sales (ScheduleId, CountTickets, ClientId) values (17, 5, 26);
insert into Sales (ScheduleId, CountTickets, ClientId) values (18, 3, 47);
insert into Sales (ScheduleId, CountTickets, ClientId) values (19, 3, 12);
insert into Sales (ScheduleId, CountTickets, ClientId) values (20, 5, 22);
insert into Sales (ScheduleId, CountTickets, ClientId) values (21, 3, 19);
insert into Sales (ScheduleId, CountTickets, ClientId) values (22, 3, 35);
insert into Sales (ScheduleId, CountTickets, ClientId) values (23, 4, 38);
insert into Sales (ScheduleId, CountTickets, ClientId) values (24, 4, 39);
insert into Sales (ScheduleId, CountTickets, ClientId) values (25, 5, 16);
insert into Sales (ScheduleId, CountTickets, ClientId) values (26, 2, 34);
insert into Sales (ScheduleId, CountTickets, ClientId) values (27, 1, 8);
insert into Sales (ScheduleId, CountTickets, ClientId) values (28, 2, 36);
insert into Sales (ScheduleId, CountTickets, ClientId) values (29, 5, 25);
insert into Sales (ScheduleId, CountTickets, ClientId) values (30, 5, 12);
insert into Sales (ScheduleId, CountTickets, ClientId) values (31, 3, 6);
insert into Sales (ScheduleId, CountTickets, ClientId) values (32, 2, 24);
insert into Sales (ScheduleId, CountTickets, ClientId) values (33, 2, 47);
insert into Sales (ScheduleId, CountTickets, ClientId) values (34, 4, 18);
insert into Sales (ScheduleId, CountTickets, ClientId) values (35, 4, 26);
insert into Sales (ScheduleId, CountTickets, ClientId) values (36, 2, 48);
insert into Sales (ScheduleId, CountTickets, ClientId) values (37, 5, 29);
insert into Sales (ScheduleId, CountTickets, ClientId) values (38, 3, 48);
insert into Sales (ScheduleId, CountTickets, ClientId) values (39, 4, 4);
insert into Sales (ScheduleId, CountTickets, ClientId) values (40, 1, 34);
insert into Sales (ScheduleId, CountTickets, ClientId) values (41, 5, 2);
insert into Sales (ScheduleId, CountTickets, ClientId) values (42, 3, 32);
insert into Sales (ScheduleId, CountTickets, ClientId) values (43, 2, 16);
insert into Sales (ScheduleId, CountTickets, ClientId) values (44, 4, 48);
insert into Sales (ScheduleId, CountTickets, ClientId) values (45, 2, 17);
insert into Sales (ScheduleId, CountTickets, ClientId) values (46, 3, 5);
insert into Sales (ScheduleId, CountTickets, ClientId) values (47, 1, 47);
insert into Sales (ScheduleId, CountTickets, ClientId) values (48, 5, 42);
insert into Sales (ScheduleId, CountTickets, ClientId) values (49, 4, 45);
insert into Sales (ScheduleId, CountTickets, ClientId) values (50, 3, 25);
insert into Sales (ScheduleId, CountTickets, ClientId) values (11,  5, 19);
insert into Sales (ScheduleId, CountTickets, ClientId) values (22,  2, 29);
insert into Sales (ScheduleId, CountTickets, ClientId) values (3,  1, 32);
insert into Sales (ScheduleId, CountTickets, ClientId) values (4,  4, 22);
insert into Sales (ScheduleId, CountTickets, ClientId) values (5,  3, 50);
insert into Sales (ScheduleId, CountTickets, ClientId) values (6,  4, 12);
insert into Sales (ScheduleId, CountTickets, ClientId) values (7,  4, 30);
insert into Sales (ScheduleId, CountTickets, ClientId) values (8,  2, 45);
insert into Sales (ScheduleId, CountTickets, ClientId) values (9,  5, 23);
insert into Sales (ScheduleId, CountTickets, ClientId) values (10, 1, 30);
insert into Sales (ScheduleId, CountTickets, ClientId) values (11,5, 36);
insert into Sales (ScheduleId, CountTickets, ClientId) values (12,4, 34);
insert into Sales (ScheduleId, CountTickets, ClientId) values (13,1, 45);
insert into Sales (ScheduleId, CountTickets, ClientId) values (14,4, 42);
insert into Sales (ScheduleId, CountTickets, ClientId) values (15,1, 19);
insert into Sales (ScheduleId, CountTickets, ClientId) values (16,2, 3);
insert into Sales (ScheduleId, CountTickets, ClientId) values (17,1, 43);
insert into Sales (ScheduleId, CountTickets, ClientId) values (18,2, 49);
insert into Sales (ScheduleId, CountTickets, ClientId) values (19,4, 18);
insert into Sales (ScheduleId, CountTickets, ClientId) values (20,4, 44);
insert into Sales (ScheduleId, CountTickets, ClientId) values (21,3, 4);
insert into Sales (ScheduleId, CountTickets, ClientId) values (22,4, 24);
insert into Sales (ScheduleId, CountTickets, ClientId) values (23,1, 39);
insert into Sales (ScheduleId, CountTickets, ClientId) values (24,3, 1);
insert into Sales (ScheduleId, CountTickets, ClientId) values (25,1, 27);
insert into Sales (ScheduleId, CountTickets, ClientId) values (26,4, 48);
insert into Sales (ScheduleId, CountTickets, ClientId) values (27,5, 14);
insert into Sales (ScheduleId, CountTickets, ClientId) values (28,1, 27);
insert into Sales (ScheduleId, CountTickets, ClientId) values (29,5, 4);
insert into Sales (ScheduleId, CountTickets, ClientId) values (30,5, 33);
insert into Sales (ScheduleId, CountTickets, ClientId) values (31,4, 6);
insert into Sales (ScheduleId, CountTickets, ClientId) values (32,4, 30);
insert into Sales (ScheduleId, CountTickets, ClientId) values (33,2, 34);
insert into Sales (ScheduleId, CountTickets, ClientId) values (34,2, 17);
insert into Sales (ScheduleId, CountTickets, ClientId) values (35,5, 21);
insert into Sales (ScheduleId, CountTickets, ClientId) values (36,5, 26);
insert into Sales (ScheduleId, CountTickets, ClientId) values (37,5, 1);
insert into Sales (ScheduleId, CountTickets, ClientId) values (38,1, 12);
insert into Sales (ScheduleId, CountTickets, ClientId) values (39,1, 16);
insert into Sales (ScheduleId, CountTickets, ClientId) values (40,3, 3);
insert into Sales (ScheduleId, CountTickets, ClientId) values (41,4, 42);
insert into Sales (ScheduleId, CountTickets, ClientId) values (42,5, 34);
insert into Sales (ScheduleId, CountTickets, ClientId) values (43,1, 1);
insert into Sales (ScheduleId, CountTickets, ClientId) values (44,1, 15);
insert into Sales (ScheduleId, CountTickets, ClientId) values (45,5, 36);
insert into Sales (ScheduleId, CountTickets, ClientId) values (46,1, 12);
insert into Sales (ScheduleId, CountTickets, ClientId) values (47,1, 13);
insert into Sales (ScheduleId, CountTickets, ClientId) values (48,2, 14);
insert into Sales (ScheduleId, CountTickets, ClientId) values (49,4, 31);
insert into Sales (ScheduleId, CountTickets, ClientId) values (1,495, 6);
insert into Sales (ScheduleId, CountTickets, ClientId) values (2,910, 3); 






--Часто исползуемый код
CREATE FUNCTION AvailableTicket(@CountTickets INT ,@SoldTickets INT)
RETURNS NVARCHAR(30)
AS
BEGIN
     RETURN(CASE
	      WHEN @CountTickets = @SoldTickets THEN 'No tickets available'
	      WHEN @CountTickets-1 = @SoldTickets THEN 'Last Ticket'
	      WHEN @CountTickets-2 = @SoldTickets THEN 'Available 2 tickets'
		  WHEN @CountTickets-3 = @SoldTickets THEN 'Available 3 tickets'
		  WHEN @CountTickets > @SoldTickets THEN 'Available many tickets' 
         END)
END





--С помощью представлений, хранимых процедур, пользовательских функций, триггеров
--реализуйте следующую функциональность:
--- Отобразите все актуальные события на конкретную дату. Дата указывается в качестве параметра

CREATE PROC ViewEventsByDate
@date DATE
AS
BEGIN 
            SELECT  Events.[Name],Categories.[Name] AS 'Categoriy',Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, 
	        dbo.AvailableTicket(Schedules.CountTickets,Schedules.SoldTickets) AS Tickets,'in Feature' AS [Status]
	        FROM Schedules
	        JOIN Events ON Schedules.EventId = Events.Id
	        JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	        JOIN Countries ON Providences.CountriyId = Countries.Id
	        JOIN Cities ON Cities.Id = Providences.CityId
	        JOIN Categories ON Categories.Id = Events.CategoriyId
	        WHERE CONVERT(date,  Schedules.[DateTime]) LIKE @date 
			UNION
			SELECT  Events.[Name],Categories.[Name] AS 'Categoriy',Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, 
	        dbo.AvailableTicket(Archives.CountTickets,Archives.SoldTickets) AS Tickets,'in Past' AS [Status]
	        FROM Archives
	        JOIN Events ON Archives.EventId = Events.Id
	        JOIN Providences ON Providences.Id = Archives.ProvidenceId
	        JOIN Countries ON Providences.CountriyId = Countries.Id
	        JOIN Cities ON Cities.Id = Providences.CityId
	        JOIN Categories ON Categories.Id = Events.CategoriyId
	        WHERE CONVERT(date,  Archives.[DateTime]) LIKE @date 
END 

EXEC ViewEventsByDate '2021-07-25' 
 



--- Отобразите все актуальные события из конкретной категории. Категория указывается в качестве
--параметра

CREATE PROC ViewEventsByCategory
@Category NVARCHAR(30)
AS
BEGIN 
     SELECT Events.[Name],CONVERT(date,  Schedules.[DateTime]) AS 'Date','in Feature' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, 
	 dbo.AvailableTicket(Schedules.CountTickets,Schedules.SoldTickets) AS Tickets
	 FROM Schedules
	 JOIN Events ON Schedules.EventId = Events.Id
	 JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	 JOIN Countries ON Providences.CountriyId = Countries.Id
	 JOIN Cities ON Cities.Id = Providences.CityId
	 JOIN Categories ON Categories.Id = Events.CategoriyId
	 WHERE Categories.[Name] LIKE @Category 
	 UNION
	 SELECT Events.[Name],CONVERT(date,  Archives.[DateTime]) AS 'Date', 'in Past' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, 
	 dbo.AvailableTicket(Archives.CountTickets,Archives.SoldTickets) AS Tickets
	 FROM Archives
	 JOIN Events ON Archives.EventId = Events.Id
	 JOIN Providences ON Providences.Id = Archives.ProvidenceId
	 JOIN Countries ON Providences.CountriyId = Countries.Id
	 JOIN Cities ON Cities.Id = Providences.CityId
	 JOIN Categories ON Categories.Id = Events.CategoriyId
	 WHERE Categories.[Name] LIKE @Category 
END

EXEC ViewEventsByCategory 'The circus' 




--- Отобразите все актуальные события со стопроцентной продажей билетов	
CREATE PROC AllSoldTickets
AS
BEGIN
     SELECT Events.[Name],CONVERT(date,  Schedules.[DateTime]) AS 'Date','in Feature' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, 
	 dbo.AvailableTicket(Schedules.CountTickets,Schedules.SoldTickets) AS Tickets
	 FROM Schedules
	 JOIN Events ON Schedules.EventId = Events.Id
	 JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	 JOIN Countries ON Providences.CountriyId = Countries.Id
	 JOIN Cities ON Cities.Id = Providences.CityId
	 JOIN Categories ON Categories.Id = Events.CategoriyId
	 WHERE Schedules.CountTickets = Schedules.SoldTickets
	 UNION
	 SELECT Events.[Name],CONVERT(date,  Archives.[DateTime]) AS 'Date','in Past' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, 
	 dbo.AvailableTicket(Archives.CountTickets,Archives.SoldTickets) AS Tickets
	 FROM Archives
	 JOIN Events ON Archives.EventId = Events.Id
	 JOIN Providences ON Providences.Id = Archives.ProvidenceId
	 JOIN Countries ON Providences.CountriyId = Countries.Id
	 JOIN Cities ON Cities.Id = Providences.CityId
	 JOIN Categories ON Categories.Id = Events.CategoriyId
	 WHERE Archives.CountTickets = Archives.SoldTickets
END

EXEC AllSoldTickets



---+ Отобразите топ-3 самых популярных актуальных событий (по количеству приобретенных
--  билетов)

-- -1 for finish event
--  0 for all event
--  1 for feature event
CREATE PROC PopularEventsBySoldTickets
@IsFinishEvents INT = 0,
@Top INT = 3
AS
BEGIN
     IF @IsFinishEvents = -1
	    BEGIN 
		     SELECT TOP (@Top) Events.[Name], Archives.[DateTime],'in Past' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, Archives.SoldTickets,Archives.[Status]
	         FROM Archives
	         JOIN Events ON Archives.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Archives.ProvidenceId
	         JOIN Countries ON Providences.CountriyId = Countries.Id
	         JOIN Cities ON Cities.Id = Providences.CityId
	         JOIN Categories ON Categories.Id = Events.CategoriyId 
			 ORDER BY Archives.SoldTickets DESC 
		END
	 ELSE IF @IsFinishEvents = 1
		BEGIN
		     SELECT TOP (@Top) Events.[Name], Schedules.[DateTime],'in Feature' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, Schedules.SoldTickets
	         FROM Schedules
	         JOIN Events ON Schedules.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	         JOIN Countries ON Providences.CountriyId = Countries.Id
	         JOIN Cities ON Cities.Id = Providences.CityId
	         JOIN Categories ON Categories.Id = Events.CategoriyId 
			 ORDER BY Schedules.SoldTickets DESC
		END
	 ELSE IF @IsFinishEvents = 0
		BEGIN
		     DECLARE @ResultTable TABLE ([Name] NVARCHAR(20),[DateTime] DATETIME,[Status] NVARCHAR(20),Countriy NVARCHAR(20),City NVARCHAR(20),Street NVARCHAR(20),SoldTickets NVARCHAR(20))
             INSERT INTO @ResultTable 
		     SELECT TOP (@Top) Events.[Name], Archives.[DateTime],'in Past' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, Archives.SoldTickets
	         FROM Archives
	         JOIN Events ON Archives.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Archives.ProvidenceId
	         JOIN Countries ON Providences.CountriyId = Countries.Id
	         JOIN Cities ON Cities.Id = Providences.CityId
	         JOIN Categories ON Categories.Id = Events.CategoriyId   
			 UNION
		     SELECT TOP (@Top) Events.[Name], Schedules.[DateTime],'in Feature' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, Schedules.SoldTickets
	         FROM Schedules
	         JOIN Events ON Schedules.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	         JOIN Countries ON Providences.CountriyId = Countries.Id
	         JOIN Cities ON Cities.Id = Providences.CityId
	         JOIN Categories ON Categories.Id = Events.CategoriyId  

			 SELECT TOP (@Top) * FROM @ResultTable
	         ORDER BY SoldTickets DESC
		END
	ELSE 
	    PRINT 'Incorrect data'
END  


--FOR CHECK
EXEC PopularEventsBySoldTickets -1  
EXEC PopularEventsBySoldTickets 0,5
 

--- Отобразите топ-3 самых популярных категорий событий (по количеству всех приобретенных
--билетов). Архив событий учитывается

CREATE PROC PopularCategoryByTop
@Top INT = 3
AS
BEGIN

	   DECLARE @ResultTable TABLE ([Name] NVARCHAR(20),[DateTime] DATETIME,[Status] NVARCHAR(20),Countriy NVARCHAR(20),City NVARCHAR(20),Street NVARCHAR(20),SoldTickets NVARCHAR(20))
       INSERT INTO @ResultTable 
       SELECT Events.[Name], Archives.[DateTime],'in Past' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, Archives.SoldTickets
	   FROM Archives
	   JOIN Events ON Archives.EventId = Events.Id
	   JOIN Providences ON Providences.Id = Archives.ProvidenceId
	   JOIN Countries ON Providences.CountriyId = Countries.Id
	   JOIN Cities ON Cities.Id = Providences.CityId
	   JOIN Categories ON Categories.Id = Events.CategoriyId   
	   UNION
	   SELECT  Events.[Name], Schedules.[DateTime],'in Feature' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, Schedules.SoldTickets
	   FROM Schedules
	   JOIN Events ON Schedules.EventId = Events.Id
	   JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	   JOIN Countries ON Providences.CountriyId = Countries.Id
	   JOIN Cities ON Cities.Id = Providences.CityId
	   JOIN Categories ON Categories.Id = Events.CategoriyId   

	   SELECT TOP (@Top) * FROM @ResultTable
	   ORDER BY SoldTickets DESC 
END

--FOR CHECK
EXEC PopularCategoryByTop 
EXEC PopularCategoryByTop 5



--- Отобразите самое популярное событие в конкретном городе. Город указывается в качестве параметра

-- -1 for finish event
--  0 for all event
--  1 for feature event
CREATE PROC PopularEventByCity
@City NVARCHAR(30),
@IsFinishEvents INT = 0,
@Top INT = 1
AS
BEGIN
     IF @IsFinishEvents = -1
	    BEGIN 
		     SELECT TOP (@Top) Cities.Name, Events.[Name] , COUNT(*) AS CountEvents
	         FROM Archives
	         JOIN Events ON Archives.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Archives.ProvidenceId 
	         JOIN Cities ON Cities.Id = Providences.CityId 
			 GROUP BY Cities.Name,Events.[Name]
			 HAVING Cities.Name LIKE @City
			 ORDER BY COUNT(*) DESC 
		END
	 ELSE IF @IsFinishEvents = 1
		BEGIN
		     SELECT TOP (@Top)  Cities.Name, Events.[Name] , COUNT(*) AS CountEvents
	         FROM Schedules
	         JOIN Events ON Schedules.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Schedules.ProvidenceId 
	         JOIN Cities ON Cities.Id = Providences.CityId 
			 GROUP BY Cities.Name,Events.[Name]
			 HAVING Cities.Name LIKE @City
			 ORDER BY COUNT(*) DESC 
		END
	 ELSE IF @IsFinishEvents = 0
		BEGIN
		     DECLARE @ResultTable TABLE ([CityName] NVARCHAR(20),EventsName NVARCHAR(20),CountEvent INT)
             INSERT INTO @ResultTable 
		     SELECT Cities.Name, Events.[Name] , COUNT(*) AS CountEvents
	         FROM Archives
	         JOIN Events ON Archives.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Archives.ProvidenceId 
	         JOIN Cities ON Cities.Id = Providences.CityId 
			 GROUP BY Cities.Name,Events.[Name] 

			 INSERT INTO @ResultTable 
		     SELECT Cities.Name, Events.[Name] , COUNT(*) AS CountEvents
	         FROM Schedules
	         JOIN Events ON Schedules.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Schedules.ProvidenceId 
	         JOIN Cities ON Cities.Id = Providences.CityId 
			 GROUP BY Cities.Name,Events.[Name] 

			 SELECT TOP (@Top) [CityName], EventsName ,SUM(CountEvent)  AS CountEvents
			 FROM @ResultTable
			 GROUP BY [CityName], EventsName
			 HAVING CityName LIKE @City
			 ORDER BY SUM(CountEvent)   DESC
		END
	ELSE 
	    PRINT 'Incorrect data'
END


--FOR CHECK
EXEC PopularEventByCity 'Sankt-Piterburg' ,0

EXEC PopularEventByCity 'Sankt-Piterburg' ,1

EXEC PopularEventByCity 'Sankt-Piterburg' ,-1 



--- Покажите информацию о самом активном клиенте (по количеству купленных билетов) (ведь может быть на первом месте сразу несколько клиентов с одинаковым количеством покупки)
CREATE PROC ActivClient  
@IsOneAnswer INT = 1
AS
BEGIN 
		IF @IsOneAnswer = 1
		     BEGIN
			     DECLARE @IdClietn INT;
				 DECLARE @CountId INT;
				 
				 SELECT TOP 1 @IdClietn = Sales.ClientId , @CountId = COUNT(*)
				 FROM Sales
				 GROUP BY ClientId
				 ORDER BY COUNT(*) DESC
				 
				 SELECT Clients.FullName,Clients.Email,Clients.YearOfBirth, @CountId AS 'Count buy'
				 FROM Clients
				 WHERE Id LIKE @IdClietn 
			 END
		ELSE IF @IsOneAnswer = 0
			 BEGIN
			 DECLARE @Size INT;
			 SELECT TOP 1  @SIZE =COUNT(*)
	         FROM Sales
			 GROUP BY ClientId
			 ORDER BY COUNT(*) DESC

			 SELECT Clients.FullName,Clients.Email,Clients.YearOfBirth, @Size AS 'Count buy'
			 FROM Clients
			 WHERE Clients.Id = ANY(SELECT ClientId
			                        FROM Sales
			                        GROUP BY ClientId
			                        HAVING COUNT(*) =@SIZE)

			END
		ELSE
		    PRINT 'Incorrect data' 
END

--FOR CHECK
EXEC ActivClient 0
EXEC ActivClient 1




--- Покажите события о самой непопулярной категории (по количеству событий). Архив событий учитывается. 

-- -1 for finish event
--  0 for all event
--  1 for feature event
CREATE PROC UnPopularEventByCategory 
@IsFinishEvents INT = 0,
@CountCategory INT = 1
AS
BEGIN
		     DECLARE @UnPopularCategory NVARCHAR(30);
     IF @IsFinishEvents = -1
	    BEGIN  
			 SELECT Events.[Name], Archives.[DateTime],'in Past' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Street,Archives.CountTickets, Archives.SoldTickets
			 FROM Archives
			 JOIN Events ON Archives.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Archives.ProvidenceId
	         JOIN Countries ON Providences.CountriyId = Countries.Id
	         JOIN Cities ON Cities.Id = Providences.CityId
	         JOIN Categories ON Categories.Id = Events.CategoriyId   
			 WHERE Categories.Name = ANY(SELECT TOP (@CountCategory) Categories.Name
	                                     FROM Archives
	                                     JOIN Events ON Archives.EventId = Events.Id  
			                             JOIN Categories ON Events.CategoriyId = Categories.Id
			                             GROUP BY Categories.Name 
			                             ORDER BY COUNT(*)) 
		END
	 ELSE IF @IsFinishEvents = 1
		BEGIN  
			 SELECT Events.[Name], [DateTime],'in Past' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Street,CountTickets, SoldTickets
			 FROM Schedules
			 JOIN Events ON Schedules.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	         JOIN Countries ON Providences.CountriyId = Countries.Id
	         JOIN Cities ON Cities.Id = Providences.CityId
	         JOIN Categories ON Categories.Id = Events.CategoriyId   
			 WHERE Categories.Name = ANY(SELECT TOP (@CountCategory) Categories.Name
	                                     FROM Schedules
	                                     JOIN Events ON Schedules.EventId = Events.Id  
			                             JOIN Categories ON Events.CategoriyId = Categories.Id
			                             GROUP BY Categories.Name 
			                             ORDER BY COUNT(*))
		END
	 ELSE IF @IsFinishEvents = 0
		BEGIN
		     DECLARE @ResultTable TABLE ([CityName] NVARCHAR(20),CountCategorys INT)
             INSERT INTO @ResultTable  
			 SELECT Categories.Name ,COUNT(*) 
	         FROM Schedules
	         JOIN Events ON Schedules.EventId = Events.Id  
			 JOIN Categories ON Events.CategoriyId = Categories.Id
			 GROUP BY Categories.Name
			  
			 INSERT INTO @ResultTable  
			 SELECT Categories.Name ,COUNT(*) 
	         FROM Archives
	         JOIN Events ON Archives.EventId = Events.Id  
			 JOIN Categories ON Events.CategoriyId = Categories.Id
			 GROUP BY Categories.Name
			  
			  
			 SELECT Events.[Name], [DateTime],'in Past' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Street,CountTickets, SoldTickets
			 FROM Schedules
			 JOIN Events ON Schedules.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	         JOIN Countries ON Providences.CountriyId = Countries.Id
	         JOIN Cities ON Cities.Id = Providences.CityId
	         JOIN Categories ON Categories.Id = Events.CategoriyId   
			 WHERE Categories.Name =  ANY(SELECT TOP (@CountCategory) [CityName] 
			                             FROM @ResultTable
			                             GROUP BY [CityName]
			                             ORDER BY  SUM(CountCategorys))
		     UNION
			 SELECT Events.[Name], [DateTime],'in Past' AS [Status],Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Street,CountTickets, SoldTickets
			 FROM Archives
			 JOIN Events ON Archives.EventId = Events.Id
	         JOIN Providences ON Providences.Id = Archives.ProvidenceId
	         JOIN Countries ON Providences.CountriyId = Countries.Id
	         JOIN Cities ON Cities.Id = Providences.CityId
	         JOIN Categories ON Categories.Id = Events.CategoriyId   
			 WHERE Categories.Name = ANY(SELECT TOP (@CountCategory) [CityName] 
			                             FROM @ResultTable
			                             GROUP BY [CityName]
			                             ORDER BY  SUM(CountCategorys))
		END
	ELSE 
	    PRINT 'Incorrect data'
END

EXEC UnPopularEventByCategory 1,2
EXEC UnPopularEventByCategory -1
EXEC UnPopularEventByCategory 0

			 

--- Покажите название городов, в которых сегодня пройдут события (добавил количество событий чтоб знать в каком городе сколько)

CREATE PROC ViewCitysTodayEvent
AS
BEGIN
       SELECT Cities.Name , COUNT(*) AS 'Count events'
	   FROM Schedules
	   JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	   JOIN Cities ON Providences.CityId = Cities.Id
	   WHERE CONVERT(date,  Schedules.[DateTime]) LIKE GETDATE() 
	   GROUP BY Cities.Name
END

--В зависимости когда проверять будете надо добавить время для проверки
EXEC ViewCitysTodayEvent



--- Покажите все события, которые пройдут сегодня в указанное время. Время передаётся в качестве параметра 
CREATE PROC ViewTodayEventByTime
@Time TIME
AS
BEGIN
       SELECT Events.Name AS 'Event',Countries.Name AS 'Country',Cities.Name AS 'City',Categories.Name AS 'Category',Events.Description
	   FROM Schedules
	   JOIN Events ON Schedules.EventId = Events.Id
	   JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	   JOIN Categories ON Categories.Id = Events.CategoriyId
	   JOIN Countries ON Providences.CountriyId = Countries.Id
	   JOIN Cities ON Providences.CityId = Cities.Id
	   WHERE cast(Schedules.DateTime as time) LIKE @Time AND CONVERT(date,  Schedules.[DateTime]) LIKE GETDATE()
END

--В зависимости когда проверять будете надо добавить время для проверки
EXEC ViewTodayEventByTime '19:09:01'
 


--- Отобразите топ-3 набирающих популярность событий (по количеству проданных билетов за 5 дней)

CREATE PROC PopularCategoryByTopForFiveDay
@Top INT = 3
AS
BEGIN
       SELECT DISTINCT TOP (@Top) Events.[Name],Schedules.DateTime , Countries.[Name] AS 'Countriy',Cities.[Name] AS 'City',Providences.Street, Schedules.SoldTickets
	   FROM Schedules
	   JOIN Events ON Schedules.EventId = Events.Id 
	   JOIN Providences ON Providences.Id = Schedules.ProvidenceId
	   JOIN Countries ON Providences.CountriyId = Countries.Id
	   JOIN Cities ON Cities.Id = Providences.CityId
	   JOIN Sales ON  Schedules.Id = Sales.ScheduleId
	   JOIN Categories ON Categories.Id = Events.CategoriyId   
	   WHERE DATEADD(day, -5, GETDATE()) < Sales.Date -- дата продажи билета
	   ORDER BY Schedules.SoldTickets DESC 
END

--FOR CHECK
EXEC PopularCategoryByTopForFiveDay 
EXEC PopularCategoryByTopForFiveDay 12
 

  

--- При вставке нового клиента нужно проверять, нет ли его уже в базе данных. Если такой клиент есть, генерировать ошибку с описанием возникшей проблемы
 
--FOR CHECK
insert into Clients (FullName, Email, YearOfBirth) values ('Wain Kynder', 'wkynder9@symantec.com', '2009-05-17'); -- существует 
insert into Clients (FullName, Email, YearOfBirth) values ('Ivan Ivanov', 'ivanka@mail.com', '2009-05-17'); --не существует 




--- При вставке нового события нужно проверять, нет ли его уже в базе данных. Если такое событие есть, генерировать ошибку с описанием возникшей проблемы 

--FOR CHECK
insert into Events (Restriction, [Name], CategoriyId, [Description], ImageId) values (14, 'Olimpiyskie iqri', 5, 'Letnie Olimpiyskie Iqri', 7); -- существует 
insert into Events (Restriction, [Name], CategoriyId, [Description], ImageId) values (6, 'Detskoe vremya', 10, 'Mejdunarodniy den detey prazdin posvewenniy detyam', 6); -- не существует 




--- При удалении прошедших событий необходимо их переносить в архив событий  
--(Противоречит тригеру (--Тригер Архивирует мероприятие если оно произошло уже))
-- Поменял условие на это
-- При удалении события из расписания поместить его в Архим и пометить как Отмененое событие

--FOR CHECK
DELETE FROM Schedules WHERE Id = 1;

SELECT * FROM Archives
WHERE Status LIKE 'Annulled'


 --Тригер выполняет следущие функции  
--уменьшает количество билетов в налиичии при продаже билетов ( проверка количество свободных билетов)
--При попытке покупки билета проверять не достигнуто ли уже максимальное количество билетов.
--Если максимальное количество достигнуто, генерировать ошибку с информацией о возникшей проблеме
--При попытке покупки билета проверять возрастные ограничения. Если возрастное ограничение нарушено, генерировать ошибку с информацией о возникшей проблеме

 --FOR CHECK
select * 
from Schedules

insert into Sales (ScheduleId, CountTickets, ClientId) values (1,4, 54); --не проходит по возрастному категорию





--При проектировании базы данных обязательно используйте индексы. За отсутствие индексов или неправильное использование экзаменационная оценка может быть уменьшена. 
--Продумайте систему безопасности. Обязательные требования к ней:  
--- Пользователь с полным доступом ко всей информации 

CREATE LOGIN Dima WITH PASSWORD = '11111111'
CREATE USER [User] FOR LOGIN Dima 

--полный доступ (CRUD) 
GRANT SELECT TO [User] 
GRANT INSERT  TO [User]  
GRANT UPDATE TO [User] 
GRANT DELETE TO [User]

 
--- Пользователь с правом только на чтение данных 
CREATE LOGIN Andrey WITH PASSWORD = '22222222'
CREATE USER User2 FOR LOGIN Andrey 

GRANT SELECT TO User2 


--- Пользователь с правом резервного копирования и восстановления данных 
CREATE LOGIN Anton WITH PASSWORD = '33333333'
CREATE USER User3 FOR LOGIN Anton 

ALTER ROLE db_backupoperator ADD MEMBER User3  


--- Пользователь с правом создания и удаления пользователей. 
CREATE LOGIN Farid WITH PASSWORD = '44444444'
CREATE USER User4 FOR LOGIN Farid 

ALTER ROLE db_accessadmin ADD MEMBER User3 

 

--- Настроить создание резервных копий с периодичностью раз в день. 

BACKUP DATABASE EventsPosters 
TO  DISK = 'C:\ExamSql\EventsPosters.bak'
WITH  RETAINDAYS = 1, NOFORMAT, NOINIT,  NAME = 'EventsPosters_backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10