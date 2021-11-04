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
CREATE TABLE CourseCriteria(
    CGCutOff Float,
    Prerequisite Varchar(20),
    CourseID Varchar(20),
    AllowedBatches Integer,
    Primary Key (CourseID)
);
CREATE TABLE StudPastRecord (
    StudentID Varchar(20),
    CGPA Float,
    PastTotalCredit Integer,
    AvgofLast2Sems Float,
    CurrCredits Integer,
    Primary Key (StudentID)
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
    DeanResponse Varchar(5),
    Primary Key (StudentID, SectionID)
);

CREATE TABLE Teaches(
    FacultyID Varchar(20),
    SectionID Varchar(20),
    CourseID Varchar(20),
    Primary Key (SectionID, FacultyID, CourseID)
);
CREATE TABLE Enrolls(
    StudentID Varchar(20),
    SectionID Varchar(20),
    CourseID Varchar(20),
    Primary Key (SectionID, StudentID, CourseID)
);

CREATE TRIGGER student_enroll
BEFORE INSERT
ON Enrolls
FOR EACH ROW
EXECUTE PROCEDURE Enrolling();


CREATE TRIGGER enrolled
AFTER INSERT
ON Enrolls
FOR EACH ROW
EXECUTE PROCEDURE enroll_section();

CREATE OR REPLACE FUNCTION enroll_section()
    RETURNS TRIGGER AS
    $$
    BEGIN
        EXECUTE FORMAT('INSERT INTO %I VALUES($1,$2)',NEW.SectionID) using NEW.StudentID,0;
        EXECUTE format('
            DROP TABLE IF EXISTS %I;
            CREATE TABLE %s(
                SectionID Varchar(20),
                Grade Integer,
                Primary Key (SectionID)
            )
        ', NEW.StudentID, NEW.StudentID);
        RETURN NEW;
    END;
$$ language plpgsql;

CREATE OR REPLACE FUNCTION Enrolling()
    RETURNS TRIGGER AS
    $$
    DECLARE
        crd Integer;
        stud RECORD;
        curstudents CURSOR
            FOR SELECT *
            FROM Student
            WHERE Student.StudentID = NEW.StudentID;
        past RECORD;
        curpast CURSOR
            FOR SELECT *
            FROM StudPastRecord
            WHERE StudPastRecord.StudentID = NEW.StudentID;
        enrl RECORD;
	    curenroll CURSOR
		    FOR SELECT *
		    FROM Enrolls
		    WHERE StudentID = NEW.StudentID;
        cat RECORD;
	    curCat CURSOR
		    FOR SELECT *
		    FROM CATALOGUE
		    WHERE Catalogue.CourseID = NEW.CourseID ;
	    Offered RECORD;
	    curOffer CURSOR
	    	FOR SELECT *
		    FROM CourseOfferings
		    WHERE CourseOfferings.CourseID = NEW.CourseID;
        criteria RECORD;
        curcriteria CURSOR
            FOR SELECT *
		    FROM CourseCriteria
		    WHERE CourseCriteria.CourseID = NEW.CourseID;
    	i INTEGER :=0;
	    limits INTEGER;
        slot1 Varchar(20);
        semester1 Integer;
        currentyear1 Integer;
        slot2 Varchar(20);
        semester2 Integer;
        currentyear2 Integer;
        fac1 Varchar(20);
        bh Integer;
    BEGIN
        SELECT Batch FROM Students WHERE Students.StudentID = NEW.StudentID INTO bh;
        SELECT Credit FROM Catalogue WHERE Catalogue.CourseID = NEW.CourseID INTO crd;
        SELECT split_part(NEW.SectionID, '_', 4) INTO slot1;
        SELECT split_part(NEW.SectionID, '_', 3) INTO semester1;
        SELECT split_part(NEW.SectionID, '_', 2) INTO currentyear1;
        SELECT FacultyID FROM Teaches WHERE NEW.SectionID = Teaches.SectionID INTO fac1;
        OPEN curpast;
        LOOP
            FETCH curpast INTO past;
			EXIT WHEN NOT FOUND;
            IF past.AvgofLast2Sems != 0 THEN
                limits := past.AvgofLast2Sems * 5/4;
            ELSE
                limits := 21;
            END IF;
            IF past.CurrCredits  +  crd <= limits THEN
                OPEN curcriteria;
                LOOP
                    FETCH curcriteria INTO criteria;
				    EXIT WHEN NOT FOUND;
                    IF criteria.AllowedBatches = bh AND (criteria.CGCutOff <= past.CGPA OR past.CGPA = 0) THEN
                        OPEN curenroll;
                        LOOP
					        FETCH curenroll INTO enrl;
                            EXIT WHEN NOT FOUND;
                            SELECT split_part(enrl.SectionID, '_', 4) INTO slot2;
                            SELECT split_part(enrl.SectionID, '_', 3) INTO semester2;
                            SELECT split_part(enrl.SectionID, '_', 2) INTO currentyear2;
					    
                            IF slot1 = slot2 AND semester1 = semester2 AND currentyear1 = currentyear2 THEN 
                                RAISE EXCEPTION 'Slot conflict';
                            END IF;
                            IF criteria.Prerequisite = enrl.CourseID AND semester1 != semester2 AND currentyear1 != currentyear2 THEN
                                i := i + 1;
                            END IF;
                        END LOOP;
                        CLOSE curenroll;
                        IF i = 1 THEN
                            UPDATE StudPastRecord SET CurrCredits = CurrCredits + crd WHERE CURRENT OF curpast;
                            RETURN NEW;
                        ELSE
                            RAISE EXCEPTION 'Prerequisite not done';
                            RETURN NULL;
                        END IF;
                    ELSE
                        RAISE EXCEPTION 'cutoff not cleared or batch not allowed';
                        RETURN NULL;
                    END IF;
                END LOOP;
                CLOSE curcriteria;
            ELSE
                EXECUTE FORMAT('INSERT INTO %I VALUES ($1,$2,$3,$4,$5)', fac1 ) using NEW.StudentID,NEW.SectionID,'NA','NA','NA';
                RETURN NULL;
            END IF;
        END LOOP;
        CLOSE curpast;
        RETURN NEW;
    END;
$$ language plpgsql;

CREATE OR REPLACE FUNCTION faculty_teaches()
    RETURNS trigger AS
    $$
    DECLARE
        slot1 Varchar(20);
        semester1 Integer;
        currentyear1 Integer;
    BEGIN 
        SELECT split_part(NEW.SectionID, '_', 4) INTO slot1;
        SELECT split_part(NEW.SectionID, '_', 3) INTO semester1;
        SELECT split_part(NEW.SectionID, '_', 2) INTO currentyear1;
        INSERT INTO CourseOfferings(CourseID, Slot, Semester, CurrentYear) VALUES(NEW.CourseID, slot1, semester1, currentyear1);
        EXECUTE format('
            DROP TABLE IF EXISTS %I;
            CREATE TABLE %s(
                StudentID Varchar(20),
                Grade Integer,
                Primary Key (StudentID)
            );
        ', NEW.SectionID, NEW.SectionID);
        EXECUTE format('
            DROP TABLE IF EXISTS %I;
            CREATE TABLE %s(
                StudentID Varchar(20),
                SectionID Varchar(20),
                FacultyResponse Varchar(5),
                AdvisorResponse Varchar(5),
                DeanResponse Varchar(5),
                Primary Key (StudentID, SectionID)
            )
        ', NEW.FacultyID, NEW.FacultyID);
        RETURN NEW;
    END
$$ language 'plpgsql';

CREATE TRIGGER faculty_teach
AFTER INSERT
ON Teaches
FOR EACH ROW
EXECUTE PROCEDURE faculty_teaches();


CREATE TABLE tempo(
    StudentID Varchar(20),
    Grade Integer,
    Primary Key(StudentID)
);

\copy tempo(StudentID, Grade) FROM 'C:\Users\chhab\Desktop\puneet.csv' DELIMITER ',' CSV HEADER;

CREATE OR REPLACE FUNCTION add_grade(section Varchar(20))
    RETURNS RECORD AS
    $$
    DECLARE
        id Varchar(20);
        grades Integer;
        t RECORD;
        curtemp CURSOR
            FOR SELECT *
            FROM tempo;
        sections RECORD;
        sec CURSOR
            FOR SELECT * 
            FROM section
            WHERE section.SectionID = NEW.SectionID;
    BEGIN
        OPEN sec;
        LOOP
            FETCH sec INTO sections;
            EXIT WHEN NOT FOUND;
            RETURN sections;
        END LOOP;
        CLOSE sec;
    END;
$$ language plpgsql; 

CREATE TABLE result_tillnow(
    SectionID varchar(20),
    Primary Key(SectionID)
);
CREATE TRIGGER res
AFTER INSERT
ON result_tillnow
FOR EACH ROW
EXECUTE PROCEDURE add_grade();


CREATE OR REPLACE FUNCTION add_grade(section varchar(20))
    RETURNS VOID AS
    $$
    DECLARE
        id varchar(20);
        grades Integer;
        t RECORD;
        curtemp CURSOR
            FOR SELECT *
            FROM tempo;
        sec refcursor; sections RECORD;
    BEGIN
        
        OPEN sec FOR EXECUTE FORMAT('select * from %I',section);
        LOOP
            FETCH sec INTO sections;
            EXIT WHEN NOT FOUND;
            EXECUTE FORMAT('select StudentID from %I',section) INTO id;
            OPEN curtemp;
            LOOP
                FETCH curtemp INTO t;
                EXIT WHEN NOT FOUND;
                IF t.StudentID = id THEN
                    EXECUTE FORMAT('UPDATE %I SET Grade =$1 WHERE StudentID = $2',section) using t.grade,id;
                    EXECUTE FORMAT('INSERT INTO %I VALUES($1,$2)',id)using section,t.grade;
                END IF;
            END LOOP;
            CLOSE curtemp;
        END LOOP;
        CLOSE sec;
        Delete FROM tempo;
        
    END;
$$ language plpgsql;


                            
INSERT INTO Students VALUES('2019eeb1181', 'Raj',2019, 'ee');
INSERT INTO StudPastRecord VALUES('2019eeb1181', 9, 18, 9,1);
UPDATE StudPastRecord SET CurrCredits = 7 WHERE StudentID = '2019eeb1181'; 
INSERT INTO Enrolls VALUES('2019eeb1181','cs301_2020_2_cs','cs301');
INSERT INTO Students VALUES('2019eeb1151', 'Bhoopen',2019, 'cse');
INSERT INTO Catalogue VALUES('cs201', 's1', 4, '3-1-0-5');
INSERT INTO Faculty VALUES('gunturi', 'Vishwanathan' , 'cse');
INSERT INTO StudPastRecord VALUES('2019eeb1151', 6, 18, 9,1);
INSERT INTO CourseCriteria VALUES(7,'cs201','cs301', 2019);
INSERT INTO Enrolls VALUES('2019eeb1181','cs201_2019_1_s1','cs201');
INSERT INTO Teaches VALUES('gunturi','cs301_2020_2_cs','cs301');
INSERT INTO Enrolls VALUES('2019eeb1185','cs301_2020_2_cs','cs301');
INSERT INTO Enrolls VALUES('2019eeb1151','cs201_2019_1_s1','cs201');
INSERT INTO Enrolls VALUES('2019eeb1151','cs301_2020_2_cs','cs301');
INSERT INTO Catalogue VALUES('cs301', 'cs', 4, '3-1-0-5');
INSERT INTO Faculty VALUES('puneet', 'goyal' , 'cse');
INSERT INTO Teaches VALUES('puneet','cs201_2019_1_s1','cs201');

INSERT INTO Enrolls VALUES('2019eeb1185','cs201_2019_1_s1','cs201');

INSERT INTO Catalogue VALUES('cs501', 's2', 3, '3-1-0-5');
INSERT INTO Teaches VALUES('puneet','cs501_2021_3_s2','cs501');
INSERT INTO CourseCriteria VALUES(8,'cs301','cs501', 2019);
INSERT INTO Enrolls VALUES('2019eeb1185','cs501_2021_3_s2','cs501');
INSERT INTO Students VALUES('2019eeb1183', 'Ri',2019, 'me');
INSERT INTO StudPastRecord VALUES('2019eeb1183', 8, 18, 20,10);
INSERT INTO Enrolls VALUES('2019eeb1183','cs201_2019_1_s1','cs201');
INSERT INTO Enrolls VALUES('2019eeb1183','cs301_2020_2_cs','cs301');


INSERT INTO Students VALUES('eeb20191183', 'Ri',2019, 'me');
INSERT INTO StudPastRecord VALUES('eeb20191183', 8, 18, 20,10);
INSERT INTO Enrolls VALUES('eeb20191183','cs201_2019_1_s1','cs201');
INSERT INTO Enrolls VALUES('eeb20191183','cs301_2020_2_cs','cs301');