-- Q1: Probation rate per department 
SELECT department_name,
        SUM(CASE WHEN academic_standing='Black' THEN student_count ELSE 0 END) AS on_probation,
        SUM(student_count) AS total,
        ROUND(SUM(CASE WHEN academic_standing='Black' THEN student_count ELSE 0 END)
              * 100.0 / SUM(student_count), 1) AS probation_pct
FROM arts.vw_dept_standing_summary
GROUP BY department_name 
ORDER BY probation_pct DESC;

-- Q2: Average CGPA per department
SELECT department, ROUND(AVG(current_cgpa),2) AS avg_cgpa
FROM arts.vw_student_profile 
	WHERE current_cgpa IS NOT NULL
GROUP BY department 
ORDER BY avg_cgpa DESC;

-- Q3: Entry mode vs academic standing
SELECT * 
FROM arts.vw_entry_mode_vs_standing;

-- Q4: Year-on-year intake trend
SELECT * 
FROM arts.vw_intake_by_year;

-- Q5: Delayed graduation rate (Extra Year students)
SELECT year_of_entry, department, 
	COUNT(*) FILTER (WHERE current_academic_year='500 Level (Extra Year)') AS extra_year,
        COUNT(*) AS total,
       ROUND(COUNT(*) FILTER (WHERE current_academic_year='500 Level (Extra Year)')
              * 100.0 / COUNT(*), 1) AS extra_year_pct
FROM arts.vw_student_profile 
WHERE year_of_entry >= 2020
GROUP BY year_of_entry, department 
HAVING COUNT (*) FILTER (
		WHERE current_academic_year  = '500 Level (Extra Year)' ) > 0
ORDER BY extra_year_pct DESC;


-- Q6: Major performance (Linguistics + Foreign Languages)
SELECT *
FROM arts.vw_major_performance;

-- Q8: Data quality — missing values per department
SELECT department,
       COUNT(*) FILTER (WHERE current_cgpa IS NULL)       AS missing_cgpa,
       COUNT(*) FILTER (WHERE academic_standing IS NULL)  AS missing_standing,
       COUNT(*) FILTER (WHERE major IS NULL
           AND department IN ('Linguistics and African Languages','Foreign Languages')) AS missing_major
FROM arts.vw_student_profile
GROUP BY department ORDER BY missing_cgpa DESC;