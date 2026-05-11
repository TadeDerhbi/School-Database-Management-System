-- ================================================================
-- FACULTY OF ARTS — STUDENT RECORDS MANAGEMENT SYSTEM
-- PostgreSQL Schema | Tailored to match the generated dataset
-- Normalized to 3NF | March 2026
--
--       Faculty: Arts
-- Departments (8): 
-- 1. Philosophy
-- 2. Music, 
-- 3. Religious Studies,
-- 4. Linguistics & African Languages
-- 5. Dramatic Arts
-- 6. English
-- 7. History
-- 8. Foreign Languages

-- Multi-major departments: 
-- 1. Linguistics & African Languages,
-- 2. Foreign Languages
-- ================================================================
-- Database: Student Management Database System

-- DROP DATABASE IF EXISTS "Student Management Database System";

CREATE DATABASE "Student Management Database System"
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'English_United Kingdom.1252'
    LC_CTYPE = 'English_United Kingdom.1252'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- password hashing
CREATE EXTENSION IF NOT EXISTS "citext";    -- case-insensitive email

-- Schemas
CREATE SCHEMA IF NOT EXISTS arts;
CREATE SCHEMA IF NOT EXISTS audit;

-- Enum
CREATE TYPE arts.entry_mode AS ENUM (
    'UTME', 'Pre-Degree', 'JUPEB', 'Direct Entry'
);

CREATE TYPE arts.academic_standing AS ENUM (
    'Green',   -- CGPA 3.00–4.00  Good Standing
    'Blue',    -- CGPA 2.00–2.99  Warning
    'Black',   -- CGPA 1.00–1.99  Probation
    'Red'      -- CGPA 0.00–0.99  Suspension Risk
);

CREATE TYPE arts.level_label AS ENUM (
    '100 Level', '200 Level', '300 Level',
    '400 Level', '500 Level (Extra Year)'
);

CREATE TYPE arts.student_status AS ENUM (
    'Active', 'Graduated', 'Suspended', 'Withdrawn', 'Deferred'
);

