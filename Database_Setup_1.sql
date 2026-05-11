-- TABLE 1 department
-- One row per department in the Faculty of Arts
-- ────────────────────────────────────────────────────────────────

CREATE TABLE arts.department (
    department_id   SERIAL       PRIMARY KEY,
    department_name VARCHAR(150) NOT NULL,
    department_code CHAR(6)      NOT NULL,
    office_location VARCHAR(150),
    contact_email   CITEXT,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_dept_code    UNIQUE  (department_code),
    CONSTRAINT uq_dept_name    UNIQUE  (department_name),
    CONSTRAINT chk_dept_email  CHECK   (contact_email ~* '^[^@]+@[^@]+\.[^@]+$')
);

-- Added documentation for department table. 
COMMENT ON TABLE  arts.department IS
    'Eight departments in the Faculty of Arts.';
COMMENT ON COLUMN arts.department.department_code IS
    'Short code used in matric number — e.g. ENG, HIS, FOL.';

-- Detailing all 8 departments
INSERT INTO arts.department (department_name, department_code, office_location, contact_email) VALUES
    ('Philosophy',                        'PHI001', 'Arts Building, Room 101', 'philosophy@university.edu.ng'),
    ('Music',                             'MUS001', 'Arts Building, Room 205', 'music@university.edu.ng'),
    ('Religious Studies',                 'REL001', 'Arts Building, Room 110', 'religion@university.edu.ng'),
    ('Linguistics and African Languages', 'LAL001', 'Arts Building, Room 302', 'linguistics@university.edu.ng'),
    ('Dramatic Arts',                     'DRA001', 'Pit Theatre Complex',    'drama@university.edu.ng'),
    ('English',                           'ENG001', 'Arts Building, Room 201', 'english@university.edu.ng'),
    ('History',                           'HIS001', 'Arts Building, Room 150', 'history@university.edu.ng'),
    ('Foreign Languages',                 'FOL001', 'Arts Building, Room 310', 'foreign.lang@university.edu.ng');


-- ────────────────────────────────────────────────────────────────
-- TABLE: major
-- This is only for the two multi-major departments:
--   Linguistics & African Languages, which has 5 majors
--   Foreign Languages, which also has majors
-- For all other departments that do not have varying majors, their major_id on the student will be NULL.
-- ────────────────────────────────────────────────────────────────

CREATE TABLE arts.major (
    major_id      SERIAL       PRIMARY KEY,
    department_id INTEGER      NOT NULL,
    major_name    VARCHAR(150) NOT NULL,
    CONSTRAINT uq_major       UNIQUE  (department_id, major_name),
    CONSTRAINT fk_major_dept  FOREIGN KEY (department_id)
        REFERENCES arts.department(department_id)
);

-- Added Table Documentation. 
COMMENT ON TABLE arts.major IS
    'Specialisation tracks. Only populated for Linguistics & African Languages and Foreign Languages.';

-- Detailing the majors for the two multi-major departments
INSERT INTO arts.major (department_id, major_name)
SELECT d.department_id, m.major_name
FROM (VALUES
    ('Linguistics and African Languages', 'Linguistics'),
    ('Linguistics and African Languages', 'Yoruba'),
    ('Linguistics and African Languages', 'Hausa'),
    ('Linguistics and African Languages', 'Igbo'),
    ('Linguistics and African Languages', 'African Languages'),
    ('Foreign Languages', 'French'),
    ('Foreign Languages', 'Arabic'),
    ('Foreign Languages', 'German'),
    ('Foreign Languages', 'Chinese'),
    ('Foreign Languages', 'Spanish')
) AS m(dept_name, major_name)
JOIN arts.department d ON d.department_name = m.dept_name;

