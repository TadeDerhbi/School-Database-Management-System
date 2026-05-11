-- AUDIT LOG
-- ────────────────────────────────────────────────────────────────

CREATE TABLE audit.student_log (
    log_id      BIGSERIAL   PRIMARY KEY,
    student_id  INTEGER     NOT NULL,
    action      VARCHAR(10) NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
    changed_by  VARCHAR(120) NOT NULL DEFAULT CURRENT_USER,
    changed_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    old_data    JSONB,
    new_data    JSONB,
    CONSTRAINT chk_log_action CHECK (action IN ('INSERT','UPDATE','DELETE'))
);

CREATE INDEX ix_log_student  ON audit.student_log(student_id);
CREATE INDEX ix_log_time     ON audit.student_log(changed_at DESC);
