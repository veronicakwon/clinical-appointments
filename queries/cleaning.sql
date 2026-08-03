-- Clinic Appointments: SQL Cleaning Script

-- ---- Duplicate patient_id check ----
-- Confirmed: patient_id is not a real per-row key.
-- Every duplicate patient_id belongs to a DIFFERENT person (checked via name mismatch).
SELECT patient_id, COUNT(*)
FROM messy_clinic_appointments_original
GROUP BY patient_id
HAVING COUNT(*) > 1;

-- ---- 1. patient_id_fixed: unique row ID ----
ALTER TABLE messy_clinic_appointments_original
ADD patient_id_fixed INTEGER;

UPDATE messy_clinic_appointments_original
SET patient_id_fixed = ROWID;

-- ---- 2. gender_fixed: standardize Male/Female, null out unrecoverable 0/1 ----
ALTER TABLE messy_clinic_appointments_original
ADD gender_fixed TEXT;

UPDATE messy_clinic_appointments_original
SET gender_fixed = CASE
	WHEN UPPER(gender) = 'MALE' THEN 'Male'
	WHEN UPPER(gender) = 'FEMALE' THEN 'Female'
	WHEN UPPER(gender) = 'M' THEN 'Male'
	WHEN UPPER(gender) = 'F' THEN 'Female'
	ELSE NULL
END;

-- ---- 3. follow_up_required_fix: standardize Yes/No, null out unrecoverable 0/1 ----
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN follow_up_required_fix TEXT;

UPDATE messy_clinic_appointments_original
SET follow_up_required_fix = CASE
	WHEN UPPER(follow_up_required) = 'YES' THEN 'Yes'
	WHEN UPPER(follow_up_required) = 'NO' THEN 'No'
	WHEN UPPER(follow_up_required) = 'Y' THEN 'Yes'
	WHEN UPPER(follow_up_required) = 'N' THEN 'No'
	ELSE NULL
END;

-- ---- 4. identify_currency: detect currency from billing_amount prefix ----
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN identify_currency TEXT;

UPDATE messy_clinic_appointments_original
SET identify_currency = CASE
	WHEN billing_amount LIKE '$%' THEN 'USD'
	WHEN billing_amount LIKE '¬£%' THEN 'GBP'
	WHEN billing_amount LIKE '‚Ç¨%' THEN 'EUR'
	WHEN billing_amount LIKE 'Rs%' THEN 'INR'
	ELSE NULL
END;

-- ---- 5. extract_number: strip currency prefix, leave numeric amount ----
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN extract_number NUMERIC;

UPDATE messy_clinic_appointments_original
SET extract_number = CASE
	WHEN billing_amount LIKE '$%' THEN REPLACE(billing_amount, '$', '')
	WHEN billing_amount LIKE '¬£%' THEN REPLACE(billing_amount, '¬£', '')
	WHEN billing_amount LIKE '‚Ç¨%' THEN REPLACE(billing_amount, '‚Ç¨', '')
	WHEN billing_amount LIKE 'Rs%' THEN REPLACE(billing_amount, 'Rs', '')
	ELSE NULL
END;

-- ---- 6. billing_amount_fixed: convert to USD ----
-- Rates: GBP 1.27, EUR 1.09, INR 0.012 (approximate, documented assumption)
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN billing_amount_fixed NUMERIC;

UPDATE messy_clinic_appointments_original
SET billing_amount_fixed = CASE
	WHEN identify_currency = 'USD' THEN extract_number * 1
	WHEN identify_currency = 'GBP' THEN extract_number * 1.27
	WHEN identify_currency = 'EUR' THEN extract_number * 1.09
	WHEN identify_currency = 'INR' THEN extract_number * 0.012
	ELSE NULL
END;

-- ---- 7. appointment_date_final / booking_date_final: standardize to ISO (YYYY-MM-DD) ----
-- Raw dates come in two mixed formats: M/D/YY (slashes) and D-Mon-YY (dashes).
-- SQLite's date functions only parse ISO format, so both formats get broken into
-- day/month/year pieces, padded to 2 digits, and reassembled with hyphens.

-- appointment_date: day
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN appointment_date_day;

UPDATE messy_clinic_appointments_original
SET appointment_date_day=CASE
	WHEN appointment_date LIKE '%-%' THEN SUBSTR(appointment_date, 1, INSTR(appointment_date, '-') - 1)
	WHEN appointment_date LIKE '%/%' THEN SUBSTR(SUBSTR(appointment_date,  INSTR(appointment_date, '/')+1), 1, INSTR(SUBSTR(appointment_date,  INSTR(appointment_date, '/')+1),'/')-1)
ELSE NULL END;

-- appointment_date: day, padded to 2 digits
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN appointment_date_day_padded;

UPDATE messy_clinic_appointments_original
SET appointment_date_day_padded=CASE
	WHEN length(appointment_date_day) = 1 THEN '0'||appointment_date_day
	WHEN length(appointment_date_day) = 2 THEN appointment_date_day
ELSE NULL END;

-- appointment_date: month
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN appointment_date_month;

UPDATE messy_clinic_appointments_original
SET appointment_date_month=CASE
	WHEN appointment_date LIKE '%-%' THEN SUBSTR(SUBSTR(appointment_date,  INSTR(appointment_date, '-')+1), 1, INSTR(SUBSTR(appointment_date,  INSTR(appointment_date, '-')+1),'-')-1)
	WHEN appointment_date LIKE '%/%' THEN SUBSTR(appointment_date, 1, INSTR(appointment_date, '/') - 1)
ELSE NULL END;

-- appointment_date: month, padded to 2 digits + abbreviation converted to number
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN appointment_date_month_padded;

UPDATE messy_clinic_appointments_original
SET appointment_date_month_padded=CASE
	WHEN length(appointment_date_month) = 1 THEN '0'||appointment_date_month
	WHEN length(appointment_date_month) = 2 THEN appointment_date_month
	WHEN appointment_date_month = 'Jan' THEN '01'
	WHEN appointment_date_month = 'Feb' THEN '02'
	WHEN appointment_date_month = 'Mar' THEN '03'
	WHEN appointment_date_month = 'Apr' THEN '04'
	WHEN appointment_date_month = 'May' THEN '05'
	WHEN appointment_date_month = 'Jun' THEN '06'
	WHEN appointment_date_month = 'Jul' THEN '07'
	WHEN appointment_date_month = 'Aug' THEN '08'
	WHEN appointment_date_month = 'Sep' THEN '09'
	WHEN appointment_date_month = 'Oct' THEN '10'
	WHEN appointment_date_month = 'Nov' THEN '11'
	WHEN appointment_date_month = 'Dec' THEN '12'
ELSE NULL END;

-- appointment_date: year (always last 2 chars, assume 20xx)
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN appointment_date_year;

UPDATE messy_clinic_appointments_original
SET appointment_date_year=CASE
	WHEN appointment_date LIKE '%-%' THEN '20'||SUBSTR(appointment_date,-2)
	WHEN appointment_date LIKE '%/%' THEN '20'||SUBSTR(appointment_date,-2)
ELSE NULL END;

-- appointment_date: final ISO assembly
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN appointment_date_final;

UPDATE messy_clinic_appointments_original
SET appointment_date_final=appointment_date_year||'-'||appointment_date_month_padded||'-'||appointment_date_day_padded;

-- booking_date: day
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN booking_date_day;

UPDATE messy_clinic_appointments_original
SET booking_date_day=CASE
	WHEN booking_date LIKE '%-%' THEN SUBSTR(booking_date, 1, INSTR(booking_date, '-') - 1)
	WHEN booking_date LIKE '%/%' THEN SUBSTR(SUBSTR(booking_date,  INSTR(booking_date, '/')+1), 1, INSTR(SUBSTR(booking_date,  INSTR(booking_date, '/')+1),'/')-1)
ELSE NULL END;

-- booking_date: day, padded to 2 digits
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN booking_date_day_padded;

UPDATE messy_clinic_appointments_original
SET booking_date_day_padded=CASE
	WHEN length(booking_date_day) = 1 THEN '0'||booking_date_day
	WHEN length(booking_date_day) = 2 THEN booking_date_day
ELSE NULL END;

-- booking_date: month
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN booking_date_month;

UPDATE messy_clinic_appointments_original
SET booking_date_month=CASE
	WHEN booking_date LIKE '%-%' THEN SUBSTR(SUBSTR(booking_date,  INSTR(booking_date, '-')+1), 1, INSTR(SUBSTR(booking_date,  INSTR(booking_date, '-')+1),'-')-1)
	WHEN booking_date LIKE '%/%' THEN SUBSTR(booking_date, 1, INSTR(booking_date, '/') - 1)
ELSE NULL END;

-- booking_date: month, padded to 2 digits + abbreviation converted to number
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN booking_date_month_padded;

UPDATE messy_clinic_appointments_original
SET booking_date_month_padded=CASE
	WHEN length(booking_date_month) = 1 THEN '0'||booking_date_month
	WHEN length(booking_date_month) = 2 THEN booking_date_month
	WHEN booking_date_month = 'Jan' THEN '01'
	WHEN booking_date_month = 'Feb' THEN '02'
	WHEN booking_date_month = 'Mar' THEN '03'
	WHEN booking_date_month = 'Apr' THEN '04'
	WHEN booking_date_month = 'May' THEN '05'
	WHEN booking_date_month = 'Jun' THEN '06'
	WHEN booking_date_month = 'Jul' THEN '07'
	WHEN booking_date_month = 'Aug' THEN '08'
	WHEN booking_date_month = 'Sep' THEN '09'
	WHEN booking_date_month = 'Oct' THEN '10'
	WHEN booking_date_month = 'Nov' THEN '11'
	WHEN booking_date_month = 'Dec' THEN '12'
ELSE NULL END;

-- booking_date: year (always last 2 chars, assume 20xx)
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN booking_date_year;

UPDATE messy_clinic_appointments_original
SET booking_date_year=CASE
	WHEN booking_date LIKE '%-%' THEN '20'||SUBSTR(booking_date,-2)
	WHEN booking_date LIKE '%/%' THEN '20'||SUBSTR(booking_date,-2)
ELSE NULL END;

-- booking_date: final ISO assembly
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN booking_date_final;

UPDATE messy_clinic_appointments_original
SET booking_date_final=booking_date_year||'-'||booking_date_month_padded||'-'||booking_date_day_padded;

-- ---- 8. age_bracket: bucket age into Young Adult / Middle Aged / Elderly ----
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN age_bracket;

UPDATE messy_clinic_appointments_original
SET age_bracket=CASE
	WHEN age<40 THEN 'Young Adult'
	WHEN age>=40 AND age <65 THEN 'Middle Aged'
	WHEN age>=65 THEN 'Elderly'
ELSE NULL END;

-- ---- 9. lead_time_days: days between booking and appointment ----
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN lead_time_days;

UPDATE messy_clinic_appointments_original
SET lead_time_days=julianday(appointment_date_final) - julianday(booking_date_final);

-- ---- 10. lead_time_ranges: percentile rank (0-1) of lead_time_days ----
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN lead_time_ranges;

UPDATE messy_clinic_appointments_original
SET lead_time_ranges=percent_rank_value.computed_value
FROM (
	SELECT patient_id_fixed, percent_rank() OVER
		(ORDER BY lead_time_days) AS computed_value
		FROM messy_clinic_appointments_original) AS percent_rank_value
		WHERE messy_clinic_appointments_original.patient_id_fixed=percent_rank_value.patient_id_fixed;

-- ---- 11. lead_time_category: bucket lead_time_ranges into wait categories ----
-- Note: 0.75 and 0.9 boundaries overlap between adjacent WHEN clauses; CASE stops at
-- the first match, so exact boundary values land in the earlier (lower) bucket.
-- Left as-is deliberately: PERCENT_RANK() produces high-precision decimals, so landing
-- on an exact boundary value in practice is effectively a non-issue.
ALTER TABLE messy_clinic_appointments_original
ADD COLUMN lead_time_category;

UPDATE messy_clinic_appointments_original
SET lead_time_category=CASE
	WHEN lead_time_ranges < 0.5 THEN 'Standard Wait'
	WHEN lead_time_ranges BETWEEN 0.5 AND 0.75 THEN 'Moderate Wait'
	WHEN lead_time_ranges BETWEEN 0.75 AND 0.9 THEN 'Long Wait'
	WHEN lead_time_ranges > 0.9 THEN 'Extreme Wait'
ELSE NULL END;
