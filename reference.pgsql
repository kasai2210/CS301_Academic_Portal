CREATE TRIGGER student_registers
BEFORE INSERT
ON STUDCOURSE
FOR EACH ROW
EXECUTE PROCEDURE studReg();
		
CREATE OR REPLACE FUNCTION studReg()
	RETURNS trigger AS
	$$
	DECLARE
		recSC RECORD;
		curSC CURSOR
			FOR SELECT *
			FROM STUDCOURSE
			WHERE sname = NEW.sname;
		recC RECORD;
		curC CURSOR
			FOR SELECT *
			FROM CATALOGUE AS cat
			WHERE cat.course = NEW.course;
		recO RECORD;
		curO CURSOR
			FOR SELECT *
			FROM OFFER AS off
			WHERE off.course = NEW.course AND off.fname = NEW.fname AND off.timeslot = NEW.timeslot AND off.batches=NEW.batch;
		recS RECORD;
		curS CURSOR
			FOR SELECT *
			FROM STUDENT AS st
			WHERE st.name = NEW.sname AND st.batch=NEW.batch;
		t1 INTEGER :=0;
		t2 INTEGER :=0;
		i INTEGER :=0;
		var INTEGER;
	BEGIN
		--RAISE NOTICE 'inside begin';
		OPEN curS;

		LOOP
			FETCH curS INTO recS;
			EXIT WHEN NOT FOUND;

			IF recS.lastC!=0 AND recS.prevC!=0 THEN 
				var := (recS.lastC+recS.prevC)*(3/4);
			ELSE 
				var := 21;
			END IF;

			IF recS.credit+NEW.credit <= var THEN
				OPEN curO;

				LOOP
				FETCH curO INTO recO;
				EXIT WHEN NOT FOUND;

				IF (NEW.CGcriteria <= recS.cgpa OR recS.cgpa=0) AND NEW.batch=recO.batches THEN
					OPEN curC;

					LOOP
					FETCH curC INTO recC;
					EXIT WHEN NOT FOUND;
						OPEN curSC;

						LOOP 
						FETCH curSC INTO recSC;
						EXIT WHEN NOT FOUND;
						IF recSC.timeslot!=NEW.timeslot and recSC.year=NEW.year THEN
							t1 := t1+1;
						END IF;
						IF recSC.course = recC.prereq  AND (recSC.grade='A' OR recSC.grade='B' OR recSC.grade='C' OR recSC.grade='D')  THEN
								i := i+1;
						END IF;
						IF recSC.batch=NEW.batch THEN
						t2:=t2+1;

						END LOOP;

						CLOSE curSC;
					IF i=recC.np AND t1=t2 THEN
					
						UPDATE STUDENT
						SET credit = credit + NEW.credit
						WHERE CURRENT OF curS;
						RETURN NEW;
					ELSE
						--RAISE EXCEPTION 'Pre-requisites not completed or another class at the given timeslot';
					END IF;

					END LOOP;
					CLOSE curC;

				ELSE
					--RAISE EXCEPTION 'cg criteria or batch criteria not fulfilled';
				END IF;

				END LOOP;
				CLOSE curO;

			ELSE

				IF NEW.approve = 'N' THEN
					
					INSERT INTO TICKET(sName, fName, cName, cCredit, currCredit, Approval) VALUES(NEW.sname, NEW.fname, NEW.course, NEW.credit, recS.credit, 'N' );

					--RAISE NOTICE 'Credits already completed';
					-- RETURN NEW;
				END IF;
				IF NEW.approve = 'Y' THEN
					RETURN NEW;
				END IF; 


			END IF;

		END LOOP;

		CLOSE curS;
		RETURN NULL;

	END;
	$$

	LANGUAGE plpgsql;



CREATE TRIGGER ticket_update
AFTER UPDATE 
ON TICKET 
FOR EACH ROW 
EXECUTE PROCEDURE ticketUpdate();

CREATE OR REPLACE FUNCTION ticketUpdate()
	RETURNS TRIGGER AS
	$$
	DECLARE
	recS2 RECORD;
	curS2 CURSOR
		FOR SELECT *
		FROM STUDENT
		WHERE name = NEW.sName;
	recO2 RECORD;
	curO2 CURSOR
		FOR SELECT *
		FROM OFFER
		WHERE course=NEW.cName AND fname=NEW.fName ;
	cre INTEGER :=0;
	BEGIN
		RAISE DEBUG 'hiiiii\n';
		IF NEW.Approval='YES' OR NEW.Approval='Yes' OR NEW.Approval='yes' THEN
			OPEN curS2;
			LOOP
				FETCH curS2 INTO recS2;
				EXIT WHEN NOT FOUND;

				OPEN curO2;
				LOOP
					FETCH curO2 INTO recO2;
					EXIT WHEN NOT FOUND;
					RAISE INFO 'hi\n';
					IF recO2.batches = recS2.batch THEN
						cre = NEW.cCredit + NEW.currCredit;
						INSERT INTO STUDCOURSE(sname, batch, course, fname, credit, grade, timeslot, fadv, approve) VALUES(NEW.sName, recS2.batch, NEW.cName, NEW.fName, NEW.cCredit, 'N', recO2.timeslot, 'facadv', 'Y');
						RAISE DEBUG 'updated\n';
					END IF;
				END LOOP;
				CLOSE curO2;
			END LOOP;
			CLOSE curS2;
		END IF;
		RETURN NEW;

	END;
	$$
	LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION updateCG()
      RETURNS VOID AS
      $$
      DECLARE
      recS RECORD;
      curS CURSOR
        FOR SELECT * 
        FROM STUDENT;

      recSC RECORD;
      curSC CURSOR
        FOR SELECT *
        FROM STUDCOURSE;

      totalGrade FLOAT;
      totalCredit FLOAT;

      BEGIN
      OPEN curS;

      LOOP
        FETCH curS INTO recS;
        EXIT WHEN NOT FOUND;

        totalGrade := 0;
        totalCredit := 0;

        OPEN curSC;
        LOOP
          FETCH curSC INTO recSC;
          EXIT WHEN NOT FOUND;

          IF recSC.sname = recS.name THEN
              
            IF recSC.grade='E' THEN 
              totalGrade := totalGrade + recSC.credit*(6);
            END IF;
            IF recSC.grade='D' THEN
              totalGrade := totalGrade + recSC.credit*(7);
            END IF; 
            IF recSC.grade='C' THEN
              totalGrade := totalGrade + recSC.credit*(8);
            END IF; 
            IF recSC.grade='B' THEN
              totalGrade := totalGrade + recSC.credit*(9);
            END IF; 
            IF recSC.grade='A' THEN
              totalGrade := totalGrade + recSC.credit*(10);
            END IF; 
            totalCredit := totalCredit + recSC.credit;
          END IF;

        END LOOP;
        RAISE NOTICE 'Arrived here\n';
        IF totalCredit!=0 THEN 
          UPDATE STUDENT
          SET cgpa = totalGrade/totalCredit
          WHERE CURRENT OF curS;
         
        END IF;
        CLOSE curSC;
      END LOOP;
      CLOSE curS;

      END;

      $$
      LANGUAGE plpgsql;

--insert a course in a course catalogue

INSERT INTO COURSE VALUES(course TEXT, credits FLOAT, lecture INTEGER, tutorial INTEGER, practical INTEGER);
INSERT INTO CATALOGUE VALUES(course TEXT, credits FLOAT, prereq TEXT, np INTEGER);

INSERT INTO OFFER VALUES(course TEXT, timeslot VARCHAR, fname TEXT, batches TEXT, leastCG FLOAT);

CREATE TRIGGER check_course
	BEFORE INSERT
	ON OFFER
	FOR EACH ROW
	EXECUTE PROCEDURE courseOffered();

CREATE OR REPLACE FUNCTION courseOffered()
	RETURNS TRIGGER AS
	$$
	DECLARE
	recC RECORD
	curC CURSOR
		FOR SELECT *
		FROM CATALOGUE;
	BEGIN
	OPEN curC;
	LOOP
		FETCH curC INTO recC;
		EXIT WHEN NOT FOUND;

		IF NEW.course = recC.course THEN
			RETURN NEW;
		END IF;

	END LOOP;
	CLOSE curC;
	RETURN NULL;
	END;
	$$
	LANGUAGE plpgsql;