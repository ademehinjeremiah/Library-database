-- Create The Library Database
CREATE DATABASE Library;
GO

USE Library;
GO

-- Create Members Table
CREATE TABLE Members (
MemberID int NOT NULL IDENTITY(1,1) PRIMARY KEY,
MemberFirstName nvarchar(50) NOT NULL,
MemberLastName nvarchar(50) NOT NULL,
MemberAddress nvarchar(100) NOT NULL,
MemberDOB date NOT NULL,
MemberUsername nvarchar(50) NOT NULL UNIQUE,
MemberPassword nvarchar(50) NOT NULL,
MemberEmail nvarchar(100)  NULL UNIQUE CHECK(MemberEmail LIKE '%_@_%._%'),
MemberTelephone nvarchar(20) NULL,
MemberDateJoined date NOT NULL,
MemberDateLeft date
);


--Create Items table
CREATE TABLE Items (
ItemID INT PRIMARY KEY,
ItemTitle nvarchar(100) NOT NULL,
ItemType nvarchar(20) NOT NULL,
Author nvarchar(50) NOT NULL,
YearOfPublication int NOT NULL,
DateAdded date NOT NULL,
Status nvarchar(20) NOT NULL,
DateIdentified date,
ISBN nvarchar(20),
);


--Create Loans Table
CREATE TABLE Loans (
LoanID int PRIMARY KEY,
MemberID int NOT NULL,
ItemID int NOT NULL,
DateTakenOut date NOT NULL,
DateDueBack date NOT NULL,
DateReturned date,
CONSTRAINT FK_Loans_Members FOREIGN KEY (MemberID) REFERENCES Members(MemberID),
CONSTRAINT FK_Loans_Items FOREIGN KEY (ItemID) REFERENCES Items(ItemID)
);


--To calculate Overdue fee
SELECT LoanID, DATEDIFF(day, DateDueBack, GETDATE()) * 0.10 AS OverdueFee
FROM Loans
WHERE DateReturned IS NULL AND GETDATE() > DateDueBack


--Create LoanPayments Table
CREATE TABLE LoanPayments (
PaymentID int NOT NULL PRIMARY KEY,
LoanID int NOT NULL,
MemberID int NOT NULL,
PaymentDate date NOT NULL,
Amount decimal(10,2) NOT NULL,
CONSTRAINT FK_LoanPayments_Loans FOREIGN KEY (LoanID) REFERENCES Loans(LoanID),
CONSTRAINT FK_LoanPayments_Members FOREIGN KEY (MemberID) REFERENCES Members(MemberID)
);


--Create OverdueLoanFines Table
CREATE TABLE OverdueLoanFines (
FineID int IDENTITY NOT NULL PRIMARY KEY,
MemberID int NOT NULL,
LoanID int NOT NULL,
FineAmount DECIMAL(10,2) NOT NULL,
AmountRepaid DECIMAL(10,2) NOT NULL,
OutstandingBalance DECIMAL(10,2) NOT NULL,
DateIssued date NOT NULL,
CONSTRAINT FK_OverdueLoanFines_Members FOREIGN KEY (MemberID) REFERENCES Members(MemberID),
CONSTRAINT FK_OverdueLoanFines_Loans FOREIGN KEY (LoanID) REFERENCES Loans(LoanID)
);

--adding overdue loans into the OverdueLoanFines table
INSERT INTO OverdueLoanFines (MemberID, LoanID, FineAmount, AmountRepaid, OutstandingBalance, DateIssued)
SELECT Loans.MemberID, Loans.LoanID, DATEDIFF(day, Loans.DateDueBack, GETDATE()) * 0.10 AS FineAmount, 0.00 AS AmountRepaid, DATEDIFF(day, Loans.DateDueBack, GETDATE()) * 0.10 AS OutstandingBalance, GETDATE() AS DateIssued
FROM Loans
WHERE Loans.DateReturned IS NULL AND GETDATE() > Loans.DateDueBack;


--QUESTION 2
--2A
--Stored procedure for searching the catalogue for matching character strings by title.
CREATE PROCEDURE SearchItemsByTitle
    @SearchString nvarchar(100)
AS
BEGIN
    SELECT * FROM Items
    WHERE ItemTitle LIKE '%' + @SearchString + '%'
    ORDER BY YearOfPublication DESC
END


--2B
--A Function that returns a full list of all items currently on loan which have a due date of less than five days from the current date 
CREATE FUNCTION GetOverdueLoans()
RETURNS TABLE
AS
RETURN 
    SELECT *
    FROM Loans
    WHERE DateDueBack <= DATEADD(day, 5, GETDATE())
      AND DateReturned IS NULL;


--2C
--Stored procedure for inserting a new member into the database
CREATE PROCEDURE InsertMember
    @MemberFirstName NVARCHAR(50),
    @MemberLastName NVARCHAR(50),
    @MemberAddress nvarchar(100),
    @MemberDOB DATE,
    @MemberUsername NVARCHAR(50),
    @MemberPassword NVARCHAR(50),
    @MemberEmail NVARCHAR(100),
    @MemberTelephone NVARCHAR(20),
    @MemberDateJoined DATE,
    @MemberID int OUTPUT
AS
BEGIN
    INSERT INTO Members (MemberFirstName, MemberLastName, MemberAddress, MemberDOB, MemberUsername, MemberPassword, MemberEmail, MemberTelephone, MemberDateJoined)
    VALUES (@MemberFirstName, @MemberLastName, @MemberAddress, @MemberDOB, @MemberUsername, @MemberPassword, @MemberEmail, @MemberTelephone, @MemberDateJoined)
    SET @MemberID = SCOPE_IDENTITY()
END


--2D
--Stored procedure for updating the details for an existing member
CREATE PROCEDURE UpdateMemberDetails
    @MemberID INT,
    @MemberFirstName NVARCHAR(50),
    @MemberLastName NVARCHAR(50),
    @MemberAddress nvarchar(100),
    @MemberDOB DATE,
    @MemberUsername NVARCHAR(50),
    @MemberPassword NVARCHAR(50),
    @MemberEmail NVARCHAR(100),
    @MemberTelephone NVARCHAR(20)
AS
BEGIN
    UPDATE Members
    SET MemberFirstName = @MemberFirstName,
        MemberLastName = @MemberLastName,
        MemberAddress = @MemberAddress,
        MemberDOB = @MemberDOB,
        MemberUsername = @MemberUsername,
        MemberPassword = @MemberPassword,
        MemberEmail = @MemberEmail,
        MemberTelephone = @MemberTelephone
    WHERE MemberID = @MemberID
END


--QUESTION 3
CREATE VIEW LoanHistory AS
SELECT Loans.LoanID, Members.MemberFirstName, Members.MemberLastName, Items.ItemTitle, Loans.DateTakenOut AS DateBorrowed, Loans.DateDueBack, Loans.DateReturned, 
    DATEDIFF(day, Loans.DateDueBack, COALESCE(Loans.DateReturned, GETDATE())) * 0.10 AS FineAmount
FROM Loans
INNER JOIN Members ON Loans.MemberID = Members.MemberID
INNER JOIN Items ON Loans.ItemID = Items.ItemID;


--QUESTION 4
CREATE TRIGGER update_item_status
ON Loans
AFTER UPDATE
AS
BEGIN
    IF UPDATE(DateReturned)
    BEGIN
        UPDATE Items
        SET Status = 'Available'
        FROM Items i
        INNER JOIN inserted ins ON i.ItemID = ins.ItemID
        WHERE ins.DateReturned IS NOT NULL
    END
END;


--QUESTION 5
SELECT COUNT(*) AS TotalLoans
FROM Loans
WHERE DateTakenOut = 'YYYY-MM-DD';


--QUESTION 6
--Inserting values into the Members table
INSERT INTO Members (MemberFirstName, MemberLastName, MemberAddress, MemberDOB, MemberUsername, MemberPassword, MemberEmail, MemberTelephone, MemberDateJoined, MemberDateLeft)
VALUES 
('Poppy', 'Scott', '86 Bulb Street, London', '1994-05-01', 'poppy_scott', 'Zeba$123', 'poppyy_scott@gmail.com', '+44 7113 486789', '2022-01-01', NULL),
('Bob', 'Clark', '456 Main Street, Manchester', '1985-05-12', 'bobbyclark', 'Pluto_456', 'bob.clark@yahoo.com', NULL, '2021-08-14', '2022-01-16'),
('Mia', 'Brown', '78 Elm Street, Birmingham', '1998-09-21', 'mialieb', 'Suid#789', 'm_brown@gmail.com', '+44 7236 567800', '2020-11-30', NULL),
('Diana', 'Wood', '246 Park Avenue, Glasgow', '1992-03-18', 'dianaw', 'Gorilla!246', NULL, '+44 7045 677901', '2023-03-01', NULL),
('Edward', 'Jackson', '15 Oxford Road, Leicester', '1989-11-02', 'edjackson', 'Banana_15', 'ed.jackson@google.com', NULL, '2021-07-10', NULL),
('Sophia', 'Lee', '57 Bristol Street, Manchester', '1997-06-30', 'slee', 'Giraffe$57', 'slee@yahoo.com', '+44 7457 783012', '2022-10-17', NULL),
('George', 'King', '13 Rox Road, London', '1987-04-17', 'georgek', 'Flamingo_13', 'george_k@gmail.com', NULL, '2021-05-01', NULL),
('Hannah', 'Taylor', '67 Rush Street, Bristol', '1999-12-20', 'hannaht', 'Tiger#67', 'hannah.taylor@yahoo.com', NULL, '2023-01-15', NULL),
('Noah', 'Robinson', '90 Rexel Street, Liverpool', '1996-08-08', 'ianrobinson', 'Elephant$90', 'noahrobinso@imessage.com', '+44 7567 890123', '2021-12-01', '2022-11-17'),
('Jane', 'Clark', '35 King Street, London', '1987-02-28', 'janeclark', 'Hippo_345', 'jane_clark@gmail.com', NULL, '2020-06-15', NULL);


--To check that the values have been inserted into the members table
SELECT * FROM Members;


--Inserting values into the Items table
INSERT INTO Items (ItemID, ItemTitle, ItemType, Author, YearOfPublication, DateAdded, Status, DateIdentified, ISBN)
VALUES
(1, 'The Art of Mindfulness', 'Book', 'Evan Hartley', 1982, '2022-06-01', 'Available', NULL, '9780446310789'),
(2, 'The Last Survivors', 'Book', 'Harper Bishop', 1937, '2021-08-14', 'On Loan', NULL, '97801414582636'),
(3, 'The Science of Sleep', 'Book', 'Parker Shepard', 1948, '2020-08-30', 'Available', NULL, '9780316069174'),
(4, 'The Language of Music', 'Book', 'Ryder Blake', 2010, '2023-07-01', 'Lost/Removed', '2023-03-05', '9780307454546'),
(5, 'Journal of Human-Robot Interaction and Collaboration', 'Journal', 'Various', 1896, '1987-08-08', 'Available', NULL, NULL),
(6, 'Journal of Sports Analytics and Performance Tracking', 'Journal', 'Various', 1888, '1997-09-15', 'Available', NULL, NULL),
(7, 'Island of the Cursed Skull', 'DVD', 'Olivia Knight', 1992, '2020-07-20', 'Available', NULL, NULL),
(8, 'The Witches of Darkwood', 'DVD', 'Quinn Walsh', 1992, '2019-07-04', 'On Loan', NULL, NULL),
(9, 'The Legend of the Enchanted Sword', 'DVD', 'Sadie Nicholsr', 2019, '2020-09-10', 'Available', NULL, NULL),
(10, 'The Shadow in the Mirror', 'Other Media', 'Isla Cooper', 2018, '2022-11-17', 'Available', NULL, NULL),
(11, 'Journal of Health and Medical Research', 'Journal', 'Various', 1995, '2005-06-01', 'Available', NULL, NULL),
(12, 'Cold Stone', 'DVD', 'Naomi Baker', 1999, '2017-11-22', 'On Loan', NULL, NULL),
(13, 'Quills', 'Journal', 'Various', 1917, '2002-09-18', 'Available', NULL, NULL),
(14, 'Shadow of the Moon', 'Other Media', 'Stephen Hillenburg', 1999, '2021-07-15', 'Available', NULL, NULL),
(15, 'Rex', 'DVD', 'The Wachowskis', 1999, '2023-06-28', 'Overdue', NULL, NULL);
--To check that the values have been inserted into the table
SELECT * FROM Items;


--Inserting values into the Loans table
INSERT INTO Loans (LoanID, MemberID, ItemID, DateTakenOut, DateDueBack, DateReturned)
VALUES (1, 1, 12, '2022-01-01', '2022-03-15', NULL),
       (2, 3, 10, '2022-02-02', '2022-04-16', NULL),
       (3, 4, 8, '2022-01-08', '2022-03-17', '2022-03-15'),
       (4, 6, 14, '2022-05-04', '2022-05-18', '2022-05-23'),
       (5, 7, 9, '2022-01-05', '2022-01-19', NULL),
       (6, 8, 6, '2022-03-07', '2022-03-21', '2022-03-28'),
       (7, 10, 1, '2022-01-08', '2022-01-22', NULL)
--To check that the values have been inserted into the table
SELECT * FROM Loans;


--Testing the parameters
--2A
EXEC SearchItemsByTitle 'the'

--2B
SELECT * FROM GetOverdueLoans();

--2C
DECLARE @NewMemberID int
EXEC InsertMember 
    @MemberFirstName = 'Jeremiah',
    @MemberLastName = 'Ademehin',
    @MemberAddress = '89 Weaste Street, Manchester',
    @MemberDOB = '1998-09-28',
    @MemberUsername = 'jadem',
    @MemberPassword = 'sculli',
    @MemberEmail = 'jade@gmail.com',
    @MemberTelephone = '+44 7096 267100',
    @MemberDateJoined = '2023-04-17',
    @MemberID = @NewMemberID OUTPUT
SELECT @NewMemberID AS NewMemberID
--To check that the values have been inserted into the table 
SELECT * FROM Members

--2D
EXEC UpdateMemberDetails
    @MemberID = 11,
    @MemberFirstName = 'Jeremiah',
    @MemberLastName = 'Ademehin',
    @MemberAddress = '95 Kwins Street, Manchester',
    @MemberDOB = '1998-09-28',
    @MemberUsername = 'jadem',
    @MemberPassword = 'rowit5',
    @MemberEmail = 'jade@gmail.com',
    @MemberTelephone = '+44 7138 4965014';
--To check that the values have been updated in the table
SELECT * FROM Members

--3
SELECT * FROM LoanHistory;


--4
--check the status of item 12 before updating the return date 
SELECT * FROM Items WHERE ItemID = 12;
--update the return date of item 12 
UPDATE Loans
SET DateReturned = '2022-03-10'
WHERE LoanID = 1;
--check the status of item 12 after updating the return date 
SELECT * FROM Items WHERE ItemID = 12;

--5
SELECT COUNT(*) AS TotalLoans
FROM Loans
WHERE DateTakenOut = '2022-05-04';

-- QUESTION 7
CREATE VIEW PopularItems AS
SELECT TOP 3 Items.ItemTitle, COUNT(*) AS BorrowCount
FROM Loans
INNER JOIN Items ON Loans.ItemID = Items.ItemID
WHERE Loans.DateReturned IS NULL
GROUP BY Items.ItemTitle
ORDER BY BorrowCount DESC;










