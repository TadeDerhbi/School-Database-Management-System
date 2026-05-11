-- TRIGGER: keep updated_at current
-- ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION arts.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.academic_standing := arts.standing_from_cgpa(NEW.current_cgpa);
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION arts.sync_standing_from_cgpa IS
    'BEFORE trigger function: overwrites academic_standing with the value '
    'derived from current_cgpa on every INSERT and UPDATE. '
    'Prevents the two columns from drifting out of sync.';

CREATE TRIGGER trg_student_sync_standing
    BEFORE INSERT OR UPDATE OF current_cgpa ON arts.student
    FOR EACH ROW EXECUTE FUNCTION arts.sync_standing_from_cgpa();

-- ────────────────────────────────────────────────────────────────
-- TRIGGER: audit log on student
-- ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION arts.log_student_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit.student_log(student_id, action, new_data)
        VALUES (NEW.student_id, 'INSERT',
            jsonb_build_object(
                'matric',    NEW.matric_number,
                'name',      NEW.student_full_name,
                'dept_id',   NEW.department_id,
                'standing',  NEW.academic_standing,
                'cgpa',      NEW.current_cgpa
            ));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit.student_log(student_id, action, old_data, new_data)
        VALUES (NEW.student_id, 'UPDATE',
            jsonb_build_object('standing',OLD.academic_standing,'cgpa',OLD.current_cgpa,
                               'status',OLD.student_status),
            jsonb_build_object('standing',NEW.academic_standing,'cgpa',NEW.current_cgpa,
                               'status',NEW.student_status));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit.student_log(student_id, action, old_data)
        VALUES (OLD.student_id, 'DELETE',
            jsonb_build_object('matric',OLD.matric_number,'name',OLD.student_full_name));
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_student_audit
    AFTER INSERT OR UPDATE OR DELETE ON arts.student
    FOR EACH ROW EXECUTE FUNCTION arts.log_student_change();





-- ────────────────────────────────────────────────────────────────
-- FUNCTION: derive academic standing from CGPA
-- ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION arts.enforce_major_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_dept_name VARCHAR(150);
BEGIN
    SELECT department_name
      INTO v_dept_name
      FROM arts.department
     WHERE department_id = NEW.department_id;

    IF v_dept_name IN ('Linguistics and African Languages', 'Foreign Languages')
       AND NEW.major_id IS NULL
    THEN
        RAISE EXCEPTION
            'Students in % must have a major_id assigned. '
            'Check the arts.major table for valid options.',
            v_dept_name;
    END IF;

    -- Also block major_id being set for departments that have no majors
    IF v_dept_name NOT IN ('Linguistics and African Languages', 'Foreign Languages')
       AND NEW.major_id IS NOT NULL
    THEN
        RAISE EXCEPTION
            '% is a single-major department. major_id must be NULL for this department.',
            v_dept_name;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION arts.enforce_major_id IS
    'BEFORE trigger: raises an exception if a student in a multi-major department '
    '(Linguistics & African Languages, Foreign Languages) has major_id = NULL, '
    'or if a student in any other department has major_id set (which would be invalid).';

CREATE TRIGGER trg_student_major_id
    BEFORE INSERT OR UPDATE OF department_id, major_id ON arts.student
    FOR EACH ROW EXECUTE FUNCTION arts.enforce_major_id();

	

-- ────────────────────────────────────────────────────────────────
-- VIEWS
-- ────────────────────────────────────────────────────────────────

-- Primary view: matches the 10 columns in the Excel dataset
CREATE OR REPLACE VIEW arts.vw_student_profile AS
SELECT
    s.student_full_name,
    s.matric_number,
    s.year_of_entry,
    s.mode_of_entry,
    s.current_academic_year,
    s.expected_graduation_year,
    d.department_name   AS department,
    s.academic_standing,
    s.current_cgpa,
    m.major_name        AS major
FROM arts.student       s
JOIN arts.department    d ON d.department_id = s.department_id
LEFT JOIN arts.major    m ON m.major_id      = s.major_id;

COMMENT ON VIEW arts.vw_student_profile IS
    'Direct equivalent of the Excel dataset — 10 columns, one row per student.';

CREATE OR REPLACE VIEW arts.vw_dept_standing_summary AS
SELECT
    d.department_name,
    s.academic_standing,
    COUNT(*)                                                         AS student_count,
    ROUND(AVG(s.current_cgpa), 2)                                   AS avg_cgpa,
    ROUND(
        COUNT(*)::NUMERIC
        / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY d.department_id), 0)
        * 100, 1
    )                                                                AS pct_of_dept
FROM arts.student      s
JOIN arts.department   d ON d.department_id = s.department_id
WHERE s.student_status = 'Active'
GROUP BY d.department_id, d.department_name, s.academic_standing
ORDER BY d.department_name, s.academic_standing;

CREATE OR REPLACE VIEW arts.vw_entry_mode_vs_standing AS
SELECT
    mode_of_entry,
    academic_standing,
    COUNT(*)                     AS student_count,
    ROUND(AVG(current_cgpa), 2)  AS avg_cgpa
FROM arts.student
WHERE student_status = 'Active'
  AND current_cgpa   IS NOT NULL
GROUP BY mode_of_entry, academic_standing
ORDER BY mode_of_entry, academic_standing;

CREATE OR REPLACE VIEW arts.vw_major_performance AS
SELECT
    d.department_name,
    m.major_name,
    COUNT(s.student_id)          AS student_count,
    ROUND(AVG(s.current_cgpa),2) AS avg_cgpa,
    MIN(s.current_cgpa)          AS min_cgpa,
    MAX(s.current_cgpa)          AS max_cgpa
FROM arts.student      s
JOIN arts.department   d ON d.department_id = s.department_id
JOIN arts.major        m ON m.major_id      = s.major_id
WHERE s.student_status = 'Active'
  AND s.current_cgpa   IS NOT NULL
GROUP BY d.department_name, m.major_name
ORDER BY d.department_name, avg_cgpa DESC;

CREATE OR REPLACE VIEW arts.vw_intake_by_year AS
SELECT
    year_of_entry,
    COUNT(*)                     AS total_students,
    COUNT(*) FILTER (WHERE mode_of_entry = 'UTME')       AS utme_count,
    COUNT(*) FILTER (WHERE mode_of_entry = 'JUPEB')      AS jupeb_count,
    COUNT(*) FILTER (WHERE mode_of_entry = 'Pre-Degree') AS predegree_count
FROM arts.student
GROUP BY year_of_entry
ORDER BY year_of_entry;


-- ────────────────────────────────────────────────────────────────
-- VIEW — surface students with incomplete security setup
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW arts.vw_pending_credentials AS
SELECT
    student_id,
    student_full_name,
    matric_number,
    university_email,
    student_status,
    created_at
FROM arts.student
WHERE password_hash = 'PENDING'
   OR password_salt = 'PENDING'
ORDER BY created_at DESC;

COMMENT ON VIEW arts.vw_pending_credentials IS
    'Lists students whose password_hash or password_salt is still the default '
    '''PENDING'' placeholder. Use for administrative follow-up to ensure all '
    'accounts have proper credentials set before student portal access is granted.';



COMMENT ON SCHEMA arts IS
    'Core schema for the Faculty of Arts Student Records Management System. '
    'Contains all student, department, and major tables, plus analytical views, '
    'trigger functions, and utility functions. Normalized to 3NF.';

COMMENT ON SCHEMA audit IS
    'Append-only audit schema. Stores a full change history for arts.student '
    'via the trg_student_audit trigger. Application roles should have INSERT '
    'access granted only through the SECURITY DEFINER trigger function — '
    'not direct table access.';