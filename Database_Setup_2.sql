-- Creating TABLE for student
-- ────────────────────────────────────────────────────────────────

CREATE TABLE arts.student (
    student_id              SERIAL                   PRIMARY KEY,
    student_full_name       VARCHAR(250)             NOT NULL,
    matric_number           VARCHAR(25)              NOT NULL,
    year_of_entry           SMALLINT                 NOT NULL,
    mode_of_entry           arts.entry_mode          NOT NULL,
    current_academic_year   arts.level_label,
    expected_graduation_year SMALLINT                NOT NULL,
    department_id           INTEGER                  NOT NULL,
    academic_standing       arts.academic_standing,
    current_cgpa            NUMERIC(3,2),
    major_id                INTEGER,           -- NULL for single-major depts

    -- ── Operational columns
    student_status          arts.student_status      NOT NULL DEFAULT 'Active',
    personal_email          CITEXT,
    university_email        CITEXT,
    phone                   VARCHAR(25),
    date_of_birth           DATE,
    gender                  VARCHAR(20),
	
    -- Security layer
    password_hash           VARCHAR(256)             NOT NULL DEFAULT 'PENDING',
    password_salt           VARCHAR(128)             NOT NULL DEFAULT 'PENDING',
    failed_login_attempts   SMALLINT                 NOT NULL DEFAULT 0,
    is_locked               BOOLEAN                  NOT NULL DEFAULT FALSE,
    last_login_at           TIMESTAMPTZ,
    -- Record metadata
    created_at              TIMESTAMPTZ              NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ              NOT NULL DEFAULT NOW(),

    -- ── Constraints ─────────────────────────────────────────
    CONSTRAINT uq_matric_number     UNIQUE  (matric_number),
    CONSTRAINT uq_personal_email    UNIQUE  (personal_email),
    CONSTRAINT uq_university_email  UNIQUE  (university_email),
    CONSTRAINT chk_cgpa             CHECK   (current_cgpa IS NULL
                                             OR current_cgpa BETWEEN 0.00 AND 4.00),
    CONSTRAINT chk_entry_year       CHECK   (year_of_entry BETWEEN 2000 AND 2100),
    CONSTRAINT chk_grad_year        CHECK   (expected_graduation_year >= year_of_entry),
    CONSTRAINT fk_student_dept      FOREIGN KEY (department_id)
                                    REFERENCES arts.department(department_id),
    CONSTRAINT fk_student_major     FOREIGN KEY (major_id)
                                    REFERENCES arts.major(major_id)
);

COMMENT ON COLUMN arts.student.matric_number IS
    'Format: YEAR/DEPTCODE/SERIAL e.g. 2021/ENG/0042';
COMMENT ON COLUMN arts.student.academic_standing IS
    'Green=Good(≥3.00), Blue=Warning(2.00–2.99), Black=Probation(1.00–1.99), Red=Risk(<1.00). NULL = no CGPA yet.';
COMMENT ON COLUMN arts.student.major_id IS
    'NULL for Philosophy, Music, Religious Studies, Dramatic Arts, English, History. Required for Linguistics and Foreign Languages.';
COMMENT ON COLUMN arts.student.password_hash IS
    'Store bcrypt or Argon2 hash only. NEVER plain text.';


-- Index creation for student table
CREATE INDEX ix_student_dept          ON arts.student(department_id);
CREATE INDEX ix_student_standing      ON arts.student(academic_standing);
CREATE INDEX ix_student_entry_year    ON arts.student(year_of_entry);
CREATE INDEX ix_student_mode          ON arts.student(mode_of_entry);
CREATE INDEX ix_student_major         ON arts.student(major_id);
CREATE INDEX ix_student_acad_year     ON arts.student(current_academic_year);
CREATE INDEX ix_student_status        ON arts.student(student_status);
CREATE INDEX ix_student_cgpa          ON arts.student(current_cgpa);

-- Other common dashboard filter combination
CREATE INDEX ix_student_dept_standing ON arts.student(department_id, academic_standing);
CREATE INDEX ix_student_dept_year     ON arts.student(department_id, year_of_entry);