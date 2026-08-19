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
Loaded the SQL-cleaned table into pandas, handled remaining nulls with a
strategy tailored to each variable's type and role (dropped rows missing the
target variable; imputed missing billing amounts with the median; recoded
unrecoverable missing gender values as `"Unknown"`), then built a full
exploratory analysis:
- Cross-validated grouped visualizations of follow-up rate by age bracket,
  gender, department, and lead time category (matching the SQL analysis)
- Scatter plots of age vs. billing amount (overall and split by currency)
- Line plots of average billing by age bracket and by month
- A two-variable heatmap of follow-up rate by age bracket x department,
  revealing an interaction the single-variable charts couldn't show
- A statistical follow-up (t-test) on an apparent billing difference by lead
  time category, which turned out **not** to be statistically significant

## Key finding

Across every dimension tested, only **age bracket** and **department**
showed a meaningful relationship with follow-up-required rate. Gender,
billing amount, and appointment lead time showed no meaningful pattern —
including a lead-time/billing difference that looked real visually but did
not hold up under a t-test (p = 0.14).

| Dimension | Range of follow-up "Yes" rate |
|---|---|
| Age bracket | ~52% – ~58% |
| Department | ~51% – ~58% |
| Gender | ~57% – ~57% (no real difference) |
| Billing amount | ~$223 vs ~$225 (no real difference) |
| Lead time category | ~52% – ~56% (no real difference) |

The age bracket x department heatmap further showed these two effects don't
act uniformly together: Neurology's follow-up rate stays consistently
moderate-high regardless of age, Cardiology shows the clearest age gradient,
and Orthopedics has an unexplained dip for Middle Aged patients.

**Data quality limitation**: billing amounts were converted to USD using
fixed nominal exchange rates, which does not account for regional
differences in healthcare cost structures — INR-converted amounts average
~3 USD, dramatically smaller than USD/GBP/EUR (~267–332 USD). All billing
comparisons in the Python EDA exclude INR to avoid this confound; this is
documented inline in `02_exploratory_analysis.ipynb`.

## Repo structure

```
data/           Raw and cleaned data files, SQLite database
queries/        SQL cleaning and analysis scripts
  cleaning.sql    Full raw -> clean transformation pipeline
  analysis.sql    Follow-up rate analysis queries
notebooks/      Python notebooks
  01_data_cleaning.ipynb       Load, null-handling, final column selection
  02_exploratory_analysis.ipynb  Full EDA: rate comparisons, scatter/line
                                  plots, heatmap, statistical testing
```

## Status

This project concludes at the EDA stage. Across every variable tested, only
age bracket and department showed a real (if modest) relationship with the
target variable — a genuine, honestly-tested finding rather than a gap in
the analysis. Rather than force a weak model onto this dataset, the planned
supervised/unsupervised learning stage will be carried out on a different
dataset with a clearer predictive signal.
