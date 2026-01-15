##### Lab Results #####

# Script to flag participant lab results

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
  select(
    record_id, event_name, enrollment_status, cholesterol_result,
    cholesterol_refrange, trigly_result, trigly_refrange, hdl_result,
    hdl_refrange, ldl_result, ldl_refrange, hemoglobin_result,
    hemoglobin_refrange, wbc_result, wbc_refrange, platelet_result,
    platelet_refrange, crp_result, crp_refrange, esr_result, esr_refrange,
    c3_result, c3_refrange, c4_result, c4_refrange, antids_result,
    antids_refrange, baseline_labresults_inst_complete
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

# complete v1 only
edc_v1_complete <- edc %>%
  filter(visit_type == 1 & baseline_labresults_inst_complete == 1)


# Flag Special Characters -------------------------------------------------

edc_special_chars <- flag_special_chars(edc_v1_complete)


# Extract Reference Ranges ------------------------------------------------

refranges <- c(
  "cholesterol_refrange", "trigly_refrange", "hdl_refrange", "ldl_refrange",
  "hemoglobin_refrange", "wbc_refrange", "platelet_refrange", "crp_refrange",
  "esr_refrange", "c3_refrange", "c4_refrange", "antids_refrange"
)

extracted_ranges <- extract_ref_ranges(edc_v1_complete, refranges)


# Flag Out of Range Results -----------------------------------------------


map <- c(
  cholesterol_result = "cholesterol_refrange",
  trigly_result = "trigly_refrange",
  hdl_result = "hdl_refrange",
  ldl_result = "ldl_refrange",
  hemoglobin_result = "hemoglobin_refrange",
  wbc_result = "wbc_refrange",
  platelet_result = "platelet_refrange",
  crp_result = "crp_refrange",
  esr_result = "esr_refrange",
  c3_result = "c3_refrange",
  c4_result = "c4_refrange",
  antids_result = "antids_refrange"
)


outrange <- flag_outrange(extracted_ranges, map)


# Flagged Test Names ------------------------------------------------------

outrange_testnames <- get_flagged_test_names(outrange, flag_suffix = "_flag") %>%
  select(
    pid, OutOfRangeLow, OutOfRangeHigh, InRange, Missing, Invalid
  )


# Blood Pressure Flags ----------------------------------------------------

# < 90/60 or >140/90 refer participant to medical provider
# flagged_bp <- flag_bp(redcap_v1)


# Output ------------------------------------------------------------------

render(
  input = here("reports", "LabResultsReport.Rmd"),
  output_file = "LabResultsReport.html",
  output_dir = here("outputs"),
  params = list(run_date = Sys.Date()),
  envir = new.env()
)
