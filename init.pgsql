CREATE TABLE Student{
    Primary Key Student_ID Integer
    Sname Varchar(20)
    Batch Integer
    Department Varchar(20)
    Advisor Varchar(20)
    TranscriptID Varchar(20)
};
CREATE TABLE Faculty{
    Primary Key Faculty_ID Integer
    Fname Varchar(20)
    Department Varchar(20)
};
CREATE TABLE CourseOfferings{
    Primary Key CourseID Varchar(10)
    Cname Varchar(20)
    Slot Integer
    Semester Integer
};
CREATE TABLE Catalogue{
    Primary Key CourseID Varchar(10)
    L-T-P-S Varchar(10)
    Credits Integer
    CGcutoff Integer
    Prereq Varchar(10)[]
}