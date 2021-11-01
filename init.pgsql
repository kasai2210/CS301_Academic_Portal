CREATE TABLE Students (
    StudentID Varchar(20),
    Sname Varchar(20),
    Batch Integer,
    Department Varchar(20),
    Primary Key (StudentID)
);
CREATE TABLE Catalogue (
    CourseID Varchar(20),
    Slot Varchar(20),
    Credit Integer,
    LTPS Varchar(20),
    Primary Key (CourseID)
);
CREATE TABLE Faculty (
    FacultyID Varchar(20),
    FName Varchar(20),
    Department Varchar(30),
    Primary Key (FacultyID)
);
CREATE TABLE CourseOfferings (
    CourseID Varchar(20),
    Slot Varchar(20),
    Semester Integer,
    CurrentYear Integer,
    Primary Key(CourseID)
);
CREATE TABLE StudPastRecord (
    StudentID Varchar(20),
    CGPA Float,
    PastTotalCredit Integer,
    AvgofLast2Sems Integer,
    CurrCredits Integer,
    Primary Key (StudentID)
);
CREATE TABLE CourseCriteria(
    CGCutOff Float,
    Prerequisite Varchar(20),
    CourseID Varchar(20),
    AllowedBatches Integer,
    Primary Key (CourseID)
);
CREATE TABLE Advisor(
    FacultyID Varchar(20),
    Batch Integer,
    Department Varchar(30),
    Primary Key (FacultyID)
);
CREATE TABLE Tickets(
    StudentID Varchar(20),
    SectionID Varchar(20),
    FacultyResponse Varchar(5),
    AdvisorResponse Varchar(5),
    Dean Response Varchar(5),
    Primary Key (StudentID, SectionID)
);