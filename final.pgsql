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
    Primary Key(CourseID, Slot, Semester, CurrentYear)
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
CREATE TABLE dean(
    StudentID Varchar(20),
    SectionID Varchar(20),
    FacultyResponse Varchar(5),
    AdvisorResponse Varchar(5),
    DeanResponse Varchar(5),
    Primary Key (StudentID, SectionID)
);

create user dean with password '1';
GRANT USAGE ON SCHEMA public TO dean;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dean;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO dean;

create group studentgroup;
create group facultygroup;
create group advisorgroup;

CREATE TRIGGER add_student
AFTER INSERT 
ON Students
FOR EACH ROW
EXECUTE PROCEDURE student_add();

CREATE OR REPLACE FUNCTION student_add()
    RETURNS TRIGGER AS
    $$
    BEGIN
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

CREATE TRIGGER add_faculty
AFTER INSERT 
ON Faculty
FOR EACH ROW
EXECUTE PROCEDURE faculty_add();

CREATE OR REPLACE FUNCTION faculty_add()
    RETURNS TRIGGER AS
    $$
    BEGIN
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
    END;
$$ language plpgsql;

CREATE TRIGGER add_advisor
AFTER INSERT 
ON Advisor
FOR EACH ROW
EXECUTE PROCEDURE advisor_add();

CREATE OR REPLACE FUNCTION advisor_add()
    RETURNS TRIGGER AS
    $$
    DECLARE
        S text;
    BEGIN
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
        ', CONCAT('adv_', NEW.FacultyID) , CONCAT('adv_', NEW.FacultyID));
        EXECUTE format('
            DROP TRIGGER IF EXISTS %I ON %I;
            CREATE TRIGGER %s
            AFTER UPDATE OF AdvisorResponse
            ON %I
            FOR EACH ROW
            EXECUTE PROCEDURE dean_tickets();
        ', CONCAT('trigg_', NEW.FacultyID), CONCAT('adv_', NEW.FacultyID), CONCAT('trigg_', NEW.FacultyID), CONCAT('adv_', NEW.FacultyID));
        S = CONCAT('GRANT INSERT ON ', CONCAT('adv_', NEW.FacultyID), ' TO facultygroup');
        EXECUTE S;
        RETURN NEW; 
    END;
$$ language plpgsql;

GRANT INSERT ON Enrolls TO studentgroup;
GRANT SELECT ON Students TO studentgroup;
GRANT SELECT ON Dean TO studentgroup;
GRANT SELECT ON Catalogue TO studentgroup;
GRANT SELECT ON Teaches TO studentgroup;
GRANT SELECT ON StudPastRecord TO studentgroup;
GRANT SELECT ON CourseCriteria TO studentgroup;
GRANT SELECT ON CourseOfferings TO studentgroup;

CREATE OR REPLACE FUNCTION newStudent(username NAME, pass text)
    RETURNS VOID
    LANGUAGE plpgsql
    SECURITY definer
    AS
    $$
    DECLARE  
        S text;
        StudentID1 Varchar(20);
    BEGIN 
        SELECT split_part(username, '_', 1) INTO StudentID1;
        S = CONCAT('CREATE USER ', username, ' WITH PASSWORD ', ''' pass ''');
        EXECUTE S;
        S = CONCAT('ALTER GROUP studentgroup ADD USER ', username);
        EXECUTE S;
        S = CONCAT('GRANT SELECT ON ', StudentID1, ' TO ', username);
        EXECUTE S;
        S = CONCAT('GRANT INSERT ON ', StudentID1, ' TO facultygroup');
        EXECUTE S;
    END;
$$;

CREATE TABLE tempo(
    StudentID Varchar(20),
    Grade Integer,
    Primary Key(StudentID)
);

GRANT INSERT ON Teaches TO facultygroup;
GRANT INSERT ON CourseOfferings TO facultygroup;
GRANT SELECT ON Teaches TO facultygroup; 
GRANT SELECT ON Students TO facultygroup;
GRANT SELECT ON Advisor TO facultygroup;
GRANT ALL PRIVILEGES ON tempo to facultygroup;

CREATE OR REPLACE FUNCTION newFaculty(username NAME, pass text)
    RETURNS VOID
    LANGUAGE plpgsql
    SECURITY definer
    AS
    $$
    DECLARE  
        S text;
        FacultyID1 Varchar(20);
    BEGIN 
        SELECT split_part(username, '_', 1) INTO FacultyID1;
        S = CONCAT('CREATE USER ', username, ' WITH PASSWORD ', ''' pass ''');
        EXECUTE S;
        S = CONCAT('ALTER GROUP facultygroup ADD USER ', username);
        EXECUTE S;
        S = CONCAT('ALTER TABLE ', FacultyID1, ' OWNER TO ', username);
        EXECUTE S;
        S = CONCAT('GRANT SELECT ON ', FacultyID1, ' TO ', username);
        EXECUTE S;
        S = CONCAT('GRANT INSERT ON ', FacultyID1, ' TO studentgroup');
        EXECUTE S;
    END;
$$;

GRANT INSERT ON dean TO advisorgroup;
GRANT SELECT ON Teaches to advisorgroup;
GRANT SELECT ON Students to advisorgroup;
GRANT SELECT ON Advisor to advisorgroup;

CREATE OR REPLACE FUNCTION newAdvisor(username NAME, pass text)
    RETURNS VOID
    LANGUAGE plpgsql
    SECURITY definer
    AS
    $$
    DECLARE  
        S text;
        AdvisorID1 Varchar(20);
    BEGIN 
        SELECT split_part(username, '_', 2) INTO AdvisorID1;
        S = CONCAT('CREATE USER ', username, ' WITH PASSWORD ', ''' pass ''');
        EXECUTE S;
        S = CONCAT('ALTER GROUP advisorgroup ADD USER ', username);
        EXECUTE S;
        S = CONCAT('ALTER TABLE ', CONCAT('adv_', AdvisorID1), ' OWNER TO ', username);
        EXECUTE S;
    END;
$$;

CREATE TRIGGER faculty_teach
AFTER INSERT
ON Teaches
FOR EACH ROW
EXECUTE PROCEDURE faculty_teaches();

CREATE OR REPLACE FUNCTION faculty_teaches()
    RETURNS trigger AS
    $$
    DECLARE
        S text;
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
            DROP TRIGGER IF EXISTS %I ON %I;
            CREATE TRIGGER %s
            AFTER UPDATE OF FacultyResponse
            ON %I
            FOR EACH ROW
            EXECUTE PROCEDURE advisor_tickets();
        ', CONCAT('trig_', NEW.FacultyID),  NEW.FacultyID, CONCAT('trig_', NEW.FacultyID), NEW.FacultyID);
        S = CONCAT('GRANT INSERT ON ', NEW.SectionID, ' TO studentgroup');
        EXECUTE S;
        S = CONCAT('GRANT ALL PRIVILEGES ON ', NEW.SectionID, ' TO ', CONCAT(NEW.FacultyID, '_aims'));
        EXECUTE S;
        RETURN NEW;
    END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION advisor_tickets()
    RETURNS TRIGGER AS
    $$
    DECLARE
        FacultyID1 Varchar(20);
        AdvID1 Varchar(20);
        StudentID1 Varchar(20) := NEW.StudentID;
        SectionID1 Varchar(20) := NEW.SectionID;
        FacultyResponse1 Varchar(5) := NEW.FacultyResponse;
        AdvisorResponse1 Varchar(5) := NEW.AdvisorResponse;
        DeanResponse1 Varchar(5) := NEW.DeanResponse;
        Batch1 Integer;
        Department1 Varchar(30);
    BEGIN
        SELECT FacultyID FROM Teaches WHERE SectionID1=Teaches.SectionID INTO FacultyID1;
        SELECT Batch FROM Students WHERE Students.StudentID=StudentID1 INTO Batch1;
        SELECT Department FROM Students WHERE Students.StudentID=StudentID1 INTO Department1;
        SELECT FacultyID FROM Advisor WHERE Batch=Batch1 AND Department=Department1 INTO AdvID1;
        EXECUTE FORMAT('
            DELETE FROM %I WHERE StudentID = $1
        ', FacultyID1) using StudentID1;
        EXECUTE FORMAT('
            INSERT INTO %I VALUES ($1, $2, $3, $4, $5)
        ', CONCAT('adv_', AdvID1)) using StudentID1, SectionID1, FacultyResponse1, AdvisorResponse1, DeanResponse1;
        RAISE NOTICE 'Ticket forwarded to advisor';
        RETURN NEW;
    END
$$ language plpgsql;

CREATE TRIGGER dean_trig
AFTER UPDATE OF DeanResponse
ON dean
FOR EACH ROW
EXECUTE PROCEDURE ticket_result();

CREATE OR REPLACE FUNCTION ticket_result()
    RETURNS TRIGGER AS
    $$
    DECLARE
        FacultyID1 Varchar(20);
        AdvID1 Varchar(20);
        StudentID1 Varchar(20) := NEW.StudentID;
        SectionID1 Varchar(20) := NEW.SectionID;
        FacultyResponse1 Varchar(5) := NEW.FacultyResponse;
        AdvisorResponse1 Varchar(5) := NEW.AdvisorResponse;
        DeanResponse1 Varchar(5) := NEW.DeanResponse;
        CourseID1 Varchar(20);
        Batch1 Integer;
        Department1 Varchar(30);
    BEGIN
        SELECT FacultyID FROM Teaches WHERE SectionID1=Teaches.SectionID INTO FacultyID1;
        SELECT Batch FROM Students WHERE Students.StudentID=StudentID1 INTO Batch1;
        SELECT Department FROM Students WHERE Students.StudentID=StudentID1 INTO Department1;
        SELECT FacultyID FROM Advisor WHERE Batch=Batch1 AND Department=Department1 INTO AdvID1;
        SELECT CourseID FROM Teaches WHERE Teaches.SectionID=SectionID1 INTO CourseID1;
        INSERT INTO Enrolls VALUES(StudentID1, SectionID1, CourseID1);
        END IF;
        RETURN NEW;
    END
$$ language plpgsql;

CREATE OR REPLACE FUNCTION dean_tickets()
    RETURNS TRIGGER AS
    $$
    DECLARE
        FacultyID1 Varchar(20);
        AdvID1 Varchar(20);
        StudentID1 Varchar(20) := NEW.StudentID;
        SectionID1 Varchar(20) := NEW.SectionID;
        FacultyResponse1 Varchar(5) := NEW.FacultyResponse;
        AdvisorResponse1 Varchar(5) := NEW.AdvisorResponse;
        DeanResponse1 Varchar(5) := NEW.DeanResponse;
        Batch1 Integer;
        Department1 Varchar(30);
    BEGIN
        SELECT FacultyID FROM Teaches WHERE SectionID1=Teaches.SectionID INTO FacultyID1;
        SELECT Batch FROM Students WHERE Students.StudentID=StudentID1 INTO Batch1;
        SELECT Department FROM Students WHERE Students.StudentID=StudentID1 INTO Department1;
        SELECT FacultyID FROM Advisor WHERE Batch=Batch1 AND Department=Department1 INTO AdvID1;
        EXECUTE FORMAT('
            DELETE FROM %I WHERE StudentID = $1
        ', CONCAT('adv_', AdvID1)) using StudentID1;
        EXECUTE FORMAT('
            INSERT INTO dean VALUES ($1, $2, $3, $4, $5)
        ') using StudentID1, SectionID1, FacultyResponse1, AdvisorResponse1, DeanResponse1;
        RAISE NOTICE 'Ticket forwarded to dean';
        RETURN NEW;
    END
$$ language plpgsql;

CREATE TRIGGER enrolled
AFTER INSERT
ON Enrolls
FOR EACH ROW
EXECUTE PROCEDURE enroll_section();

CREATE OR REPLACE FUNCTION enroll_section()
    RETURNS TRIGGER AS
    $$
    DECLARE
        S text;
    BEGIN
        EXECUTE FORMAT('INSERT INTO %I VALUES($1,$2)',NEW.SectionID) using NEW.StudentID,0;
        RETURN NEW;
    END;
$$ language plpgsql;

CREATE TRIGGER student_enroll
BEFORE INSERT
ON Enrolls
FOR EACH ROW
EXECUTE PROCEDURE Enrolling();

CREATE OR REPLACE FUNCTION Enrolling()
    RETURNS TRIGGER AS
    $$
    DECLARE
        S text;
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
        DeanResponse1 Varchar(5);
        semester1 Integer;
        currentyear1 Integer;
        slot2 Varchar(20);
        semester2 Integer;
        currentyear2 Integer;
        fac1 Varchar(20);
        bh Integer;
    BEGIN
        SELECT Batch FROM Students WHERE Students.StudentID = NEW.StudentID INTO bh;
        SELECT DeanResponse FROM dean WHERE dean.StudentID=NEW.StudentID AND dean.SectionID=NEW.SectionID INTO DeanResponse1;
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
                                RETURN NULL;
                            END IF;
                            IF criteria.Prerequisite = enrl.CourseID AND semester1 != semester2 AND currentyear1 != currentyear2 THEN
                                i := i + 1;
                            END IF;
                        END LOOP;
                        CLOSE curenroll;
                        IF i = 1 THEN
                            UPDATE StudPastRecord SET CurrCredits = CurrCredits + crd WHERE CURRENT OF curpast;
                            S = CONCAT('GRANT INSERT ON ', NEW.SectionID, ' TO ', CONCAT(NEW.StudentID, '_aims'));
                            EXECUTE S;
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
                IF(DeanResponse1='Y') THEN
                    RAISE NOTICE 'Dean accepted ticket';
                    RETURN NEW;
                END IF;
                IF(DeanResponse1='N') THEN
                    RAISE EXCEPTION 'Dean rejected ticket';
                    RETURN NULL;
                END IF;
                RAISE NOTICE 'Ticket generated';
                EXECUTE FORMAT('INSERT INTO %I VALUES ($1,$2,$3,$4,$5)', fac1) using NEW.StudentID,NEW.SectionID,'NA','NA','NA';
                RETURN NULL;
            END IF;
        END LOOP;
        CLOSE curpast;
        S = CONCAT('GRANT INSERT ON ', NEW.SectionID, ' TO ', CONCAT(NEW.StudentID, '_aims'));
        EXECUTE S;
        RETURN NEW;
    END;
$$ language plpgsql;

\copy tempo(StudentID, Grade) FROM '/home/bhoopen/Desktop/puneet.csv' DELIMITER ',' CSV HEADER;

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

CREATE OR REPLACE FUNCTION cgcalculate(id varchar(20))
    RETURNS FLOAT AS
    $$
    DECLARE
    total Integer;
    total1 Integer;
    var Integer;
    per INTEGER;
    gpa Float;
    sect Varchar(20);
    my_sec varchar(20);
    output Float := 0;
    past RECORD;
    curpast CURSOR
        FOR select *
        FROM StudPastRecord
        WHERE StudPastRecord.StudentID = id;
    ids refcursor; transcript RECORD;
    BEGIN
        SELECT PastTotalCredit FROM StudPastRecord WHERE StudPastRecord.StudentID = id INTO total;
        total1 := total;
        SELECT CGPA FROM StudPastRecord WHERE StudPastRecord.StudentID = id INTO gpa;
        OPEN ids FOR EXECUTE FORMAT('select * from %I',id);
        LOOP
            FETCH ids INTO transcript;
            EXIT WHEN NOT FOUND;
            EXECUTE FORMAT('select grade from %I',id) INTO var;
            EXECUTE FORMAT('select sectionid from %I',id) INTO sect;
            SELECT split_part(sect, '_', 1) INTO my_sec;
            SELECT Credit FROM Catalogue WHERE Catalogue.CourseID = my_sec INTO per;
            output :=  output + per * var;
            total1 = total1 + per;
        END LOOP;
        CLOSE ids;
        output := output + total*gpa;
        output := output/total1;
        RETURN output;
    END;
$$ language plpgsql;


insert into students values('eeb1151', 'Bhoopen', 2019, 'ee');
select newstudent('eeb1151_aims', '1');
alter user eeb1151_aims with password '1';
insert into catalogue values('cs101', 'cs', 4, '1111');
INSERT INTO CourseCriteria VALUES(7,'cs101','ee101', 2019);
insert into studpastrecord values('eeb1151', 9, 18, 9, 5);
insert into faculty values('gunturi', 'Vishwanath', 'cs');
select newfaculty('gunturi_aims', '1');
alter user gunturi_aims with password '1';
insert into advisor values('roy', 2019, 'ee');
insert into teaches values('gunturi', 'cs101_2019_2_cs', 'cs101');
select newadvisor('adv_roy_aims', '1');
alter user adv_roy_aims with password '1';
insert into enrolls values('eeb1151', 'cs101_2019_2_cs', 'cs101');
UPDATE StudPastRecord SET CurrCredits = 25 WHERE StudentID = 'eeb1151';
UPDATE saifu SET FacultyResponse = 'Y' WHERE StudentID = 'eeb1151';
UPDATE adv_roy SET AdvisorResponse = 'N' WHERE StudentID = 'eeb1151';
UPDATE dean SET DeanResponse = 'N' WHERE StudentID = 'eeb1151' AND SectionID = 'ee102_2019_2_ee';










INSERT INTO Advisor VALUES('dkm', 2019, 'me');
INSERT INTO Advisor VALUES('roy', 2019, 'ee');
INSERT INTO Students VALUES('meb12002019', 'Goutam',2019, 'me');
INSERT INTO StudPastRecord VALUES('meb12002019', 9, 18, 9,5);
UPDATE StudPastRecord SET CurrCredits = 25 WHERE StudentID = 'meb12002019'; 
INSERT INTO Enrolls VALUES('meb12002019','cs202_2021_2_s3','cs202');
INSERT INTO Enrolls VALUES('2019meb1185','cs201_2019_1_s1','cs201');
INSERT INTO Students VALUES('2019eeb1151', 'Bhoopen',2019, 'cse');
INSERT INTO Catalogue VALUES('cs201', 's1', 4, '3-1-0-5');
INSERT INTO Catalogue VALUES('cs201', 's1', 4, '3-1-0-5');
INSERT INTO Catalogue VALUES('ee209', 's2', 4, '3-1-0-5');
INSERT INTO Catalogue VALUES('ee205', 's2', 4, '3-1-0-5');
INSERT INTO Faculty VALUES('gunturi', 'Vishwanathan' , 'cse');
INSERT INTO Faculty VALUES('sahambi', 'Jyoti' , 'ee');
INSERT INTO Faculty VALUES('dkm', 'Mahajan' , 'me');
INSERT INTO Faculty VALUES('saifu', 'Allah' , 'ee');
INSERT INTO StudPastRecord VALUES('2019eeb1151', 6, 18, 9, 1);
INSERT INTO CourseCriteria VALUES(7,'cs201','cs301', 2019);
INSERT INTO Enrolls VALUES('2019eeb1181','cs201_2019_1_s1','cs201');
INSERT INTO Teaches VALUES('gunturi','cs301_2020_2_cs','cs301');
INSERT INTO Teaches VALUES('saifu','ee205_2019_1_s2','ee205');
INSERT INTO CourseCriteria VALUES(7,'cs201','ee207', 2019);
INSERT INTO CourseCriteria VALUES(7,'cs201','ee205', 2019);
INSERT INTO Enrolls VALUES('2019eeb1185','cs301_2020_2_cs','cs301');
INSERT INTO Enrolls VALUES('2019eeb1151','cs201_2019_1_s1','cs201');
INSERT INTO Enrolls VALUES('2019eeb1151','ee205_2019_1_s2','ee205');
INSERT INTO Catalogue VALUES('cs301', 'cs', 4, '3-1-0-5');
INSERT INTO Faculty VALUES('puneet', 'goyal' , 'cse');
INSERT INTO Teaches VALUES('puneet','cs201_2019_1_s1','cs201');
UPDATE brijesh SET FacultyResponse = 'Y' WHERE StudentID = 'meb1002';
UPDATE adv_dkm SET AdvisorResponse = 'N' WHERE StudentID = 'meb1002';
UPDATE dean SET DeanResponse = 'Y' WHERE StudentID = 'meb12002019' AND SectionID = 'cs202_2021_2_s3';
INSERT INTO Enrolls VALUES('meb12002019','cs301_2020_2_cs','cs301');

INSERT INTO Catalogue VALUES('cs501', 's2', 3, '3-1-0-5');
INSERT INTO Teaches VALUES('puneet','cs501_2021_3_s2','cs501');
INSERT INTO CourseCriteria VALUES(8,'cs301','cs501', 2019);
INSERT INTO Enrolls VALUES('2019eeb1185','cs501_2021_3_s2','cs501');
INSERT INTO Students VALUES('2019eeb1185', 'Riya',2019, 'ee');
INSERT INTO StudPastRecord VALUES('2019eeb1185', 9, 18, 20,12);
INSERT INTO Enrolls VALUES('2019eeb1185','cs301_2020_2_cs','cs301');
INSERT INTO Enrolls VALUES('2019eeb1183','cs301_2020_2_cs','cs301');

