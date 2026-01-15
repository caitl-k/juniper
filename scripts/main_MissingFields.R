##### Missing CRF Fields #####

# Script to flag CRF instruments marked complete but have missing fields


# Setup -------------------------------------------------------------------


if (!requireNamespace("pacman", quietly = TRUE)) {
  install.packages("pacman")
}

library(pacman)

p_load(knitr, readr, tidyverse, rmarkdown, here, kableExtra)

source(here("scripts", "functions.R"))


# Load/Select Data --------------------------------------------------------


edc <- read.csv(
  "data/edc.csv"
) %>%
  # factor visit types
  mutate(
    event_name = factor(
      event_name,
      levels = c(
        "screening",
        "baseline",
        "follow1"
      ),
      labels = c(0, 1, 2),
    ) 
  ) %>%
  # standardize vars
  rename(
    pid = record_id,
    visit_type = event_name
  )


# Prepare Data ------------------------------------------------------------


# replace blanks with NA (required)
edc <- sub_na(edc)

# format dates (required)
edc <- format_datetimes(edc)


# Screening Instrument ----------------------------------------------------

screening_vars <- c(
  "pid", "visit_type", "screening_date", "dob", "age", "sex", "race",
  "pregnant", "diagnosis_provided", "symptom_duration_weeks",
  "other_autoimmune", "procedure_consent", "screenfail", "enrollment_status",
  "screening_inst_complete"
)


edc_screening <- edc %>%
  filter(visit_type == 0 & screening_inst_complete == 1)

screening_missing <- get_missing_fields(edc_screening, screening_vars) %>%
  select(pid, missing_fields)


# Health History Instrument -----------------------------------------------

health_vars <- c(
  "pid", "health_hist_date", "smoking", "alcohol", "medications_current",
  "comorbidities", "family_history", "weight_kg", "height_cm",
  "health_hist_inst_complete"
)

edc_health <- edc %>%
  filter(visit_type == 1 & health_hist_inst_complete == 1)

health_missing <- get_missing_fields(edc_health, health_vars) %>%
  select(pid, missing_fields)


# Baseline Procedures Instrument ------------------------------------------

v1_procedure_vars <- c(
  "pid", "baseline_procedures_date", "local_labs_collected", 
  "biobank_tubes_collected", "cpt_biobank_count", "sst_biobank_count",
  "ultrasound_completed", "skinbiopsy_collected",
  "baseline_procedures_inst_complete"
)

v1_procedures <- edc %>%
  filter(visit_type == 1 & baseline_procedures_inst_complete == 1) 

v1_procedures_missing <- get_missing_fields(v1_procedures, v1_procedure_vars) %>%
  select(pid, missing_fields)


# Baseline Lab Results Instrument -----------------------------------------

v1_labresults_vars <- c(
  "pid", "cholesterol_result", "cholesterol_refrange", "trigly_result",
  "trigly_refrange", "hdl_result", "hdl_refrange", "ldl_result", "ldl_refrange",
  "hemoglobin_result", "hemoglobin_refrange", "wbc_result", "wbc_refrange",
  "platelet_result", "platelet_refrange", "crp_result", "crp_refrange",
  "esr_result", "esr_refrange", "ana_result", "c3_result", "c3_refrange",
  "c4_result", "c4_refrange", "antids_result", "antids_refrange",
  "baseline_labresults_inst_complete"
)

v1_labresults <- edc %>%
  filter(visit_type == 1 & baseline_labresults_inst_complete == 1)

v1_labresults_missing <- get_missing_fields(v1_labresults, v1_labresults_vars) %>%
  select(pid, missing_fields)


# Output ------------------------------------------------------------------

render(
  input = here("reports", "MissingCRFFieldsReport.Rmd"),
  output_file = "MissingCRFFieldsReport.html",
  output_dir = here("outputs"),
  params = list(run_date = Sys.Date()),
  envir = new.env()
)
