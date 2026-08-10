# Clinical Appointments Data Pipeline

A data cleaning and analysis project working through a messy 1,000-row clinical
appointments dataset, using Excel, SQL, and Python — with the eventual goal of
predicting whether a patient will require a follow-up appointment.

## Pipeline

**1. Excel — audit & first-pass cleaning**
Manually audited the raw dataset for data quality issues: non-unique
`patient_id`s (confirmed to be genuine ID collisions across different people,
not repeat visits), inconsistent categorical encodings (`Male`/`male`/`M` for
gender; `Yes`/`Y`/`1` for follow-up status), mixed currency formats across 4
currencies (USD, GBP, EUR, INR — including two currency symbols corrupted by an
encoding issue), and two conflicting date formats.

**2. SQL (SQLite) — independent cleaning pipeline + analysis**
Rebuilt the full cleaning pipeline from the raw data in SQL, independently of
the Excel pass, to cross-validate both approaches against each other:
- Generated a real unique row ID (`patient_id` was not usable as one)
- Standardized gender and follow-up status categories
- Detected and converted 4 currencies to USD (correcting an issue where ~76%
  of billing records would have been silently mislabeled as USD)
- Parsed two inconsistent date formats (`M/D/YY` and `D-Mon-YY`) into ISO 8601
  using manual string parsing, since SQLite has no built-in flexible date parser
- Engineered `age_bracket` and a percentile-based `lead_time_category`
  (via a `PERCENT_RANK()` window function) for analysis

Then ran exploratory queries measuring follow-up-required rate by age bracket,
gender, department, billing amount, and appointment lead time.

**3. Python (pandas) — cleaning, nulls, and EDA**
Loaded the SQL-cleaned table into pandas, handled remaining nulls (dropped
rows missing the target variable; imputed missing billing amounts with the
median; recoded unrecoverable missing gender values as `"Unknown"`), and
built cross-validated grouped visualizations of follow-up rate by age bracket,
gender, department, and lead time category.

## Key finding

Across all five dimensions tested, only **age bracket** and **department**
showed a meaningful relationship with follow-up-required rate. Gender,
billing amount, and appointment lead time showed no meaningful pattern.

| Dimension | Range of follow-up "Yes" rate |
|---|---|
| Age bracket | ~52% – ~58% |
| Department | ~51% – ~58% |
| Gender | ~57% – ~57% (no real difference) |
| Billing amount | ~$223 vs ~$225 (no real difference) |
| Lead time category | ~52% – ~56% (no real difference) |

## Repo structure

```
data/           Raw and cleaned data files, SQLite database
queries/        SQL cleaning and analysis scripts
  cleaning.sql    Full raw -> clean transformation pipeline
  analysis.sql    Follow-up rate analysis queries
notebooks/      Python notebooks
  01_data_cleaning.ipynb       Load, null-handling, final column selection
  02_exploratory_analysis.ipynb  Grouped visualizations, rate analysis
```

## Next steps

- Supervised learning: logistic regression predicting `follow_up_required`
  from age bracket, department, and other features
- Unsupervised learning: exploratory clustering of patients (e.g. by billing,
  age, lead time) to check for natural patient segments
