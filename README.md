# Faculty of Arts — Student Records Management System

A **PostgreSQL relational database** designed to manage student records across all eight departments of a university Faculty of Arts. The schema is normalized to **Third Normal Form (3NF)**, built around a clean separation of concerns across two schemas (`arts` and `audit`), and ships with views, triggers, and functions ready for dashboard consumption.

---

## Table of Contents

- [Overview](#overview)
- [Database Architecture](#database-architecture)
- [Schema Design](#schema-design)
  - [Enums](#enums)
  - [Tables](#tables)
  - [Views](#views)
  - [Functions](#functions)
  - [Triggers](#triggers)
- [Setup & Installation](#setup--installation)
- [Test Queries](#test-queries)
- [Design Decisions](#design-decisions)
- [Departments & Majors Reference](#departments--majors-reference)

---

## Overview

| Property | Detail |
|---|---|
| **Database** | PostgreSQL (v14+) |
| **Faculty** | Arts |
| **Departments** | 8 |
| **Multi-major Departments** | 2 (Linguistics & African Languages, Foreign Languages) |
| **Schemas** | `arts` (core), `audit` (change history) |
| **Normalization** | 3NF |
| **Extensions Required** | `pgcrypto`, `citext` |

---

## Database Architecture

```
Student Management Database System
│
├── Schema: arts
│   ├── Tables
│   │   ├── department          — 8 Faculty of Arts departments
│   │   ├── major               — Specialisation tracks (multi-major depts only)
│   │   └── student             — Core student records
│   │
│   ├── Views
│   │   ├── vw_student_profile          — Full student profile (10 columns)
│   │   ├── vw_dept_standing_summary    — Standing distribution per department
│   │   ├── vw_entry_mode_vs_standing   — Entry mode vs academic outcome
│   │   ├── vw_major_performance        — Major-level CGPA breakdown
│   │   └── vw_intake_by_year           — Year-on-year intake trend
│   │
│   ├── Functions
│   │   ├── set_updated_at()            — Timestamp maintenance
│   │   ├── log_student_change()        — Audit trigger function
│   │   └── standing_from_cgpa()        — CGPA → Academic Standing mapping
│   │
│   └── Triggers
│       ├── trg_student_updated_at      — Fires BEFORE UPDATE on student
│       └── trg_student_audit           — Fires AFTER INSERT/UPDATE/DELETE on student
│
└── Schema: audit
    └── Tables
        └── student_log         — Full change history (JSONB old/new state)
```

---

## Schema Design

### Enums

Enums enforce valid categorical values at the database level, eliminating the need for lookup tables for these fixed-list types.

| Enum | Values |
|---|---|
| `arts.entry_mode` | `UTME`, `Pre-Degree`, `JUPEB`, `Direct Entry` |
| `arts.academic_standing` | `Green` (≥3.00), `Blue` (2.00–2.99), `Black` (1.00–1.99), `Red` (<1.00) |
| `arts.level_label` | `100 Level` → `500 Level (Extra Year)` |
| `arts.student_status` | `Active`, `Graduated`, `Suspended`, `Withdrawn`, `Deferred` |

---

### Tables

#### `arts.department`
One row per department. Enforces unique department codes (used in matric number generation) and unique department names.

| Column | Type | Notes |
|---|---|---|
| `department_id` | SERIAL PK | Auto-incremented |
| `department_name` | VARCHAR(150) | Unique |
| `department_code` | CHAR(6) | Unique — used in matric numbers (e.g. `ENG001`) |
| `office_location` | VARCHAR(150) | |
| `contact_email` | CITEXT | Case-insensitive; regex-validated |
| `is_active` | BOOLEAN | Defaults to TRUE |

---

#### `arts.major`
Populated **only** for the two multi-major departments. All other departments leave `major_id` as NULL on the student record.

| Column | Type | Notes |
|---|---|---|
| `major_id` | SERIAL PK | |
| `department_id` | INTEGER FK | References `arts.department` |
| `major_name` | VARCHAR(150) | Unique per department |

**Majors seeded:**
- **Linguistics & African Languages:** Linguistics, Yoruba, Hausa, Igbo, African Languages
- **Foreign Languages:** French, Arabic, German, Chinese, Spanish

---

#### `arts.student`
Core table. Holds academic, operational, and security data per student.

**Key columns:**

| Column | Type | Notes |
|---|---|---|
| `student_id` | SERIAL PK | |
| `matric_number` | VARCHAR(25) | Unique — format: `YEAR/DEPTCODE/SERIAL` |
| `year_of_entry` | SMALLINT | Constrained to 2000–2100 |
| `mode_of_entry` | `arts.entry_mode` | UTME, JUPEB, Pre-Degree, Direct Entry |
| `current_academic_year` | `arts.level_label` | 100–500 Level |
| `expected_graduation_year` | SMALLINT | Must be ≥ year of entry |
| `department_id` | INTEGER FK | References `arts.department` |
| `academic_standing` | `arts.academic_standing` | Derived from CGPA |
| `current_cgpa` | NUMERIC(3,2) | Constrained to 0.00–4.00 |
| `major_id` | INTEGER FK | NULL for single-major departments |
| `student_status` | `arts.student_status` | Defaults to `Active` |
| `password_hash` | VARCHAR(256) | bcrypt/Argon2 only — never plaintext |

**Indexes:** 10 indexes covering common filter patterns (department, standing, year of entry, mode, CGPA) plus two composite indexes for common dashboard filter combinations.

---

#### `audit.student_log`
Append-only change history for the student table. Captures old and new state as JSONB for flexible querying.

| Column | Type | Notes |
|---|---|---|
| `log_id` | BIGSERIAL PK | |
| `student_id` | INTEGER | References the affected student |
| `action` | VARCHAR(10) | `INSERT`, `UPDATE`, or `DELETE` |
| `changed_by` | VARCHAR(120) | Defaults to `CURRENT_USER` |
| `changed_at` | TIMESTAMPTZ | Defaults to `NOW()` |
| `old_data` | JSONB | State before change (NULL for INSERT) |
| `new_data` | JSONB | State after change (NULL for DELETE) |

---

### Views

| View | Purpose |
|---|---|
| `vw_student_profile` | Full student profile — 10-column flat view matching the source dataset |
| `vw_dept_standing_summary` | Count and percentage of each standing per department |
| `vw_entry_mode_vs_standing` | Cross-tab of entry mode against academic outcome |
| `vw_major_performance` | CGPA stats (avg, min, max) per major |
| `vw_intake_by_year` | Year-on-year intake counts split by entry mode |

All views filter on `student_status = 'Active'` where relevant to exclude withdrawn, deferred, or graduated students from active reporting.

---

### Functions

#### `arts.set_updated_at()`
Trigger function that stamps `updated_at = NOW()` on every UPDATE. Called by `trg_student_updated_at`.

#### `arts.log_student_change()`
`SECURITY DEFINER` trigger function. Writes a JSONB snapshot of changed fields to `audit.student_log` on every INSERT, UPDATE, or DELETE against `arts.student`.

#### `arts.standing_from_cgpa(p_cgpa NUMERIC)`
Pure deterministic function (`IMMUTABLE`) for mapping a CGPA value to an `arts.academic_standing` label. Useful for backfilling or validating the `academic_standing` column.

```sql
SELECT arts.standing_from_cgpa(3.45);  -- Returns 'Green'
SELECT arts.standing_from_cgpa(1.78);  -- Returns 'Black'
```

---

### Triggers

| Trigger | Table | Fires | Function Called |
|---|---|---|---|
| `trg_student_updated_at` | `arts.student` | BEFORE UPDATE | `arts.set_updated_at()` |
| `trg_student_audit` | `arts.student` | AFTER INSERT / UPDATE / DELETE | `arts.log_student_change()` |

---

## Setup & Installation

Run the SQL files **in this order**:

```
1. Initial_Database_Setup.sql          — Create database, schemas, extensions, enums
2. Database_Setup_1.sql                — Create department and major tables; seed data
3. Database_Setup_2.sql                — Create student table and indexes
4. Database_Setup_3.sql                — Create audit.student_log table
5. Database_Setup_4_Views_Triggers_and_Functions.sql  — Views, triggers, functions
```

> **Note:** All scripts assume a running PostgreSQL instance with a superuser role able to create databases, schemas, and extensions.

### Prerequisites

- PostgreSQL 14 or higher
- The `pgcrypto` and `citext` extensions (installed automatically by `Initial_Database_Setup.sql`)

### Matric Number Format

```
YEAR/DEPTCODE/SERIAL
e.g. 2021/ENG001/0042
```

---

## Test Queries

The file `Test_Queries.sql` contains eight ready-to-run analytical queries:

| Query | Description |
|---|---|
| Q1 | Probation rate per department |
| Q2 | Average CGPA per department |
| Q3 | Entry mode vs academic standing cross-tab |
| Q4 | Year-on-year intake trend |
| Q5 | Delayed graduation (Extra Year) rate |
| Q6 | Major performance — Linguistics & Foreign Languages |
| Q8 | Data quality audit — missing values per department |

Run against the views directly after seeding student data:

```sql
-- Example: departments ranked by probation rate
SELECT department_name,
       SUM(CASE WHEN academic_standing='Black' THEN student_count ELSE 0 END) AS on_probation,
       SUM(student_count) AS total,
       ROUND(SUM(CASE WHEN academic_standing='Black' THEN student_count ELSE 0 END)
             * 100.0 / SUM(student_count), 1) AS probation_pct
FROM arts.vw_dept_standing_summary
GROUP BY department_name
ORDER BY probation_pct DESC;
```

---

## Design Decisions

**Why separate `arts` and `audit` schemas?**
Separating concerns at the schema level makes permission management cleaner — application roles can be granted access to `arts` without touching `audit`, and the audit schema can be write-protected for all but the trigger function.

**Why enums instead of lookup tables for standing and status?**
The valid values for academic standing, entry mode, level, and student status are fixed and defined by faculty policy. Enums enforce this at the type level with zero join overhead, while still being easy to extend with `ALTER TYPE ... ADD VALUE`.

**Why is `major_id` nullable?**
Only two of the eight departments have sub-specialisations. Rather than creating a redundant "General" major row for the other six departments, `major_id` is left NULL, which the views handle cleanly with a `LEFT JOIN`.

**Why `CITEXT` for emails?**
University and personal emails are case-insensitive in practice. `CITEXT` enforces uniqueness without needing to normalize case on every write.

**Why `SECURITY DEFINER` on the audit trigger?**
The audit log should be written regardless of which role triggers the change. `SECURITY DEFINER` ensures the function executes with the privileges of its owner (typically a superuser or dedicated audit role), so application roles cannot accidentally lack INSERT permission on `audit.student_log`.

---

## Departments & Majors Reference

| # | Department | Code | Majors |
|---|---|---|---|
| 1 | Philosophy | PHI001 | — |
| 2 | Music | MUS001 | — |
| 3 | Religious Studies | REL001 | — |
| 4 | Linguistics & African Languages | LAL001 | Linguistics, Yoruba, Hausa, Igbo, African Languages |
| 5 | Dramatic Arts | DRA001 | — |
| 6 | English | ENG001 | — |
| 7 | History | HIS001 | — |
| 8 | Foreign Languages | FOL001 | French, Arabic, German, Chinese, Spanish |