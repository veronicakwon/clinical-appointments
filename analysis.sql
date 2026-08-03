-- Clinic Appointments: Analysis Queries
-- Run after queries/cleaning.sql has been applied.

-- follow_up_required rate by age bracket
SELECT age_bracket, SUM(follow_up_required_fix='Yes') as yes,  SUM(follow_up_required_fix='No') as no
FROM messy_clinic_appointments_original
GROUP BY age_bracket;

-- follow_up_required rate by gender
SELECT gender_fixed, SUM(follow_up_required_fix='Yes') as yes,  SUM(follow_up_required_fix='No') as no
FROM messy_clinic_appointments_original
GROUP BY gender_fixed;

-- avg billing_amount_fixed by follow_up_required status
SELECT follow_up_required_fix, AVG(billing_amount_fixed) as avg_billing_amount
FROM messy_clinic_appointments_original
GROUP BY follow_up_required_fix;

-- follow_up_required rate by lead time category (with Yes Rate)
SELECT lead_time_category AS Category, SUM(follow_up_required_fix='Yes') AS Yes, SUM(follow_up_required_fix='No') AS No, CAST(SUM(follow_up_required_fix='Yes') AS REAL)/COUNT(follow_up_required_fix) AS 'Yes Rate'
FROM messy_clinic_appointments_original
GROUP BY Category;
