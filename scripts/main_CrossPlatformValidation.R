##### Cross-System Data Reconciliation #####

# Script to cross-validate data between an EDC system and LIMS

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
  # select variables needed for QC
  select(
    record_id, event_name, screening_date, enrollment_status,
    screening_inst_complete, screenfail, baseline_procedures_date,
    biobank_tubes_collected, skinbiopsy_collected,
    baseline_procedures_inst_complete
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
    visit_type = event_name,
    visit_date = baseline_procedures_date
  )


# skip first 4 metadata rows for LIMS query export
lims <- read.csv("data/lims.csv", skip = 4, header = TRUE) %>%
  # split visit variable into sample and visit type
  mutate(
    visit_type = as.factor(sub(".*_([0-9]).*", "\\1", Visit_Name)),
    sample_type = sub(".*_.*?([A-Za-z]{2})$", "\\1", Visit_Name)
  ) %>%
  # standardize vars
  rename(
    pid = Participant_PPID,
    visit_date = Visit_Visit.Date,
    screening_date = Participant_Registration.Date
  ) %>%
  select(-Visit_Name)


# Prepare Data ------------------------------------------------------------


# replace blanks with NA
edc <- sub_na(edc)
lims <- sub_na(lims)

# format dates
edc <- format_datetimes(edc)
lims <- format_datetimes(lims)


# Data Subsets ------------------------------------------------------------

# v1/v2 only
edc_v1v2 <- edc %>%
  filter(visit_type %in% c(1, 2))

# v1 only
edc_v1 <- edc %>%
  filter(visit_type == 1 )

# v2 only
edc_v2 <- edc %>%
  filter(visit_type == 2)

# get completed screening visits
edc_v0_complete <- edc %>%
  filter(visit_type == 0 & screening_inst_complete == 1 & screenfail == 0)

# get completed baseline procedure visits
edc_v1_complete <- edc %>%
  filter(visit_type == 1 & baseline_procedures_inst_complete == 1)

# pivot lims to match row-by-row pid structure
lims_pivot <- lims %>%
  distinct(pid, visit_date, sample_type) %>%
  mutate(present = TRUE) %>%
  pivot_wider(
    names_from  = sample_type,
    values_from = present,
    values_fill = FALSE
  )


# Check Dates -------------------------------------------------------------

screening_discrepancies <- check_lims_screening_dates(edc_v0_complete, lims) %>%
  select(
    pid, visit_type.edc, screening_date.edc,
    screening_date.lims, screening_status
  )


visit_discrepancies <- check_lims_visit_dates(edc_v1_complete, lims) %>%
  select(
    pid, visit_type.edc, visit_date.edc,
    visit_date.lims, visit_status
  )


# Check Biobanking --------------------------------------------------------

biobanking_discrepancies <- check_lims_biobanking(edc_v1_complete, lims_pivot) %>%
  select(pid, visit_type, biobank_tubes_collected, skinbiopsy_collected,
         WB, SB, wb_status, sb_status)


# Output ------------------------------------------------------------------

render(
  input = here("reports", "CrossPlatformDiscrepancyReport.Rmd"),
  output_file = "CrossPlatformDiscrepancyReport.html",
  output_dir = here("outputs"),
  params = list(run_date = Sys.Date()),
  envir = new.env()
)
