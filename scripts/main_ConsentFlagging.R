##### Participant Procedure Consents #####

# Script to flag participants who withdrew procedure consent between screening and execution.

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
  # select vars for QC
  select(
    record_id, procedure_consent, event_name, screening_date, enrollment_status,
    local_labs_collected, nolabs_reason, ultrasound_completed,
    ultrasound_decline_reason, skinbiopsy_collected, skinbiopsy_decline_reason,
    baseline_procedures_date, baseline_procedures_inst_complete
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


# Flag Conflicting Consenting Participants --------------------------------

consents <- flag_consents(edc) %>%
  select(
    pid, visit_type, baseline_procedures_date,
    Labs_DeclineReason, Ultrasound_DeclineReason, SkinBiopsy_DeclineReason
  )

# Output ------------------------------------------------------------------

render(
  input = here("reports", "ParticipantProcedureConsentReport.Rmd"),
  output_file = "ParticipantProcedureConsentReport.html",
  output_dir = here("outputs"),
  params = list(run_date = Sys.Date()),
  envir = new.env()
)
