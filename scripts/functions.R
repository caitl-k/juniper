# Functions for use in juniper scripts


# Setup -------------------------------------------------------------------

if (!requireNamespace("pacman", quietly = TRUE)) {
  install.packages("pacman")
}

library(pacman)

p_load(tidyverse)


# Pre-Processing ----------------------------------------------------------

#' Substitute Blank Values
#'
#' @param df 
#'
#' @return dataframe with imputed NA values
sub_na <- function(df) {
  df <- df %>%
    mutate(across(where(~ is.character(.) || is.factor(.)),
                  ~ na_if(as.character(.), "")))
  return(df)
}


#' Format Dates & Times
#'
#' @param df
#' @param cols 
#'
#' @return
format_datetimes <- function(df, cols = NULL) {
  
  # subset if specific cols are passed
  if (!is.null(cols)) df <- df[, cols, drop = FALSE]
  
  for (col in names(df)) {
    x <- df[[col]]
    
    # convert factors to characters
    if (is.factor(x)) x <- as.character(x)
    
    # handle character dates
    if (is.character(x)) {
      pattern <- "\\d{4}-\\d{2}-\\d{2}(\\s+\\d{1,2}:\\d{2})?|\\d{1,2}[-/]\\d{1,2}[-/]\\d{2,4}(\\s+\\d{1,2}:\\d{2})?"
      
      if (any(grepl(pattern, x))) {
        formats <- c("%Y-%m-%d %H:%M", "%Y-%m-%d", "%m/%d/%Y %H:%M", "%m/%d/%Y")
        for (fmt in formats) {
          parsed <- as.POSIXct(x, format = fmt)
          if (all(!is.na(parsed[!is.na(x)]))) {
            df[[col]] <- parsed
            break
          }
        }
      }
    }
    
    # handle numeric dates
    else if (is.numeric(x) || is.integer(x)) {
      parsed <- as.POSIXct(as.character(x), format = "%Y%m%d")
      if (all(!is.na(parsed[!is.na(x)]))) df[[col]] <- parsed
    }
  }
  
  return(df)
}


#' Flag Special Characters
#'
#' @param df 
#'
#' @returns dataframe with vars containing special characters
flag_special_chars <- function(df) {
  
  pattern <- "[^a-zA-Z0-9]"
  
  specials <- lapply(df, function(col) {
    # remove NAs and collapse to single string
    combined <- paste(na.omit(col), collapse = "")
    # extract unique special characters
    chars <- unique(unlist(strsplit(combined, "")))
    found <- chars[grepl(pattern, chars)]
    if (length(found) == 0) "" else paste(found, collapse = " ")
  })
  
  return(data.frame(special_characters = unlist(specials)))
}


# Reconciling EDC & LIMS Data ---------------------------------------------

# Functions used to cross-validate clinical data across multiple systems.

#' Validate Visit Dates in LIMS
#'
#' @param edc EDC dataframe
#' @param lims LIMS dataframe
#'
#' @returns dataframe with visit date discrepancies in LIMS 
check_lims_visit_dates <- function(edc, lims) {
  
  joined <- left_join(edc, lims, by = "pid", suffix = c(".edc", ".lims"))
  
  discrepancies <- joined %>%
    mutate(
      visit_status = case_when(
        is.na(visit_date.lims) ~ "No LIMS Entry",
        visit_date.edc != visit_date.lims ~ "Visit Date Mismatch", 
        TRUE ~ "Match"                                            
      )
    )
  
  return(discrepancies %>% filter(!visit_status == "Match"))
}


#' Validate Screening Dates in LIMS
#'
#' @param edc EDC dataframe
#' @param lims LIMS dataframe
#'
#' @returns dataframe with screening date discrepancies in LIMS 
check_lims_screening_dates <- function(edc, lims) {
  
  joined <- left_join(edc, lims, by = "pid", suffix = c(".edc", ".lims"))
  
  discrepancies <- joined %>%
    mutate(
      screening_status = case_when(
        is.na(screening_date.lims) ~ "No LIMS Entry",
        screening_date.edc != screening_date.lims ~ "Screening Date Mismatch", 
        TRUE ~ "Match"                                            
      )
    )
  
  return(discrepancies %>% filter(!screening_status == "Match"))
}


#' Validate Biospecimien Banking Details in LIMS
#'
#' @param edc EDC dataframe
#' @param lims_pivot pivoted LIMS dataframe to wide format
#'
#' @returns dataframe with biospecimen discrepancies in LIMS 
check_lims_biobanking <- function(edc, lims_pivot) {
  
  discrepancies <- edc %>%
    left_join(lims_pivot, by = c("pid")) %>%
    mutate(
      wb_status = case_when(
        biobank_tubes_collected == 1 & WB == FALSE ~ "Missing LIMS Data Entry",
        biobank_tubes_collected == 0 & WB == TRUE ~ "Unexpected WB",
        biobank_tubes_collected == 1 & WB == TRUE ~ "Match",
        TRUE ~ "WB Not Collected"
      ),
      sb_status = case_when(
        skinbiopsy_collected == 1 & SB == FALSE ~ "Missing LIMS Data Entry",
        skinbiopsy_collected == 0 & SB == TRUE ~ "Unexpected SB",
        skinbiopsy_collected == 1 & SB == TRUE ~ "Match",
        TRUE ~ "SB Not Collected"
      )
    )
  return(discrepancies %>% filter(!wb_status == "Match" | !sb_status == "Match"))
}


# Custom QC Checks --------------------------------------------------------


#' Flag Conflicting Consent Participants
#'
#' @param edc EDC dataframe
#'
#' @returns dataframe with flagged participants
flag_consents <- function(edc) {
  
  flagged_participants <- edc %>%
    group_by(pid) %>%
    # pull consented participants from screening visit
    mutate(
      consented_procedures = case_when(
        any(procedure_consent == 1) ~ 1
      )
    ) %>%
    ungroup() %>%
    # check post-consent procedure decline reason
    # customize based on variable names
    mutate(
      Labs_DeclineReason = case_when(
        consented_procedures == 1 & local_labs_collected == 0
        & nolabs_reason == 1 ~ "Medical",
        consented_procedures == 1 & local_labs_collected == 0
        & nolabs_reason == 2 ~ "Refused",
        consented_procedures == 1 & local_labs_collected == 0
        & nolabs_reason == 3 ~ "Trypanophobia"
      ),
      Ultrasound_DeclineReason = case_when(
        consented_procedures == 1 & ultrasound_completed == 0
        & ultrasound_decline_reason == 1 ~ "Medical",
        consented_procedures == 1 & ultrasound_completed == 0
        & ultrasound_decline_reason == 2 ~ "Refused"
      ),
      SkinBiopsy_DeclineReason = case_when(
        consented_procedures == 1 & skinbiopsy_collected == 0
        & skinbiopsy_decline_reason == 1 ~ "Medical",
        consented_procedures == 1 & skinbiopsy_collected == 0
        & skinbiopsy_decline_reason == 2 ~ "Refused",
        consented_procedures == 1 & skinbiopsy_collected == 0
        & skinbiopsy_decline_reason == 3 ~ "Tomophobia"
      )
    )
  
  return(
    flagged_participants %>%
      filter(
        !is.na(Ultrasound_DeclineReason) |
          !is.na(SkinBiopsy_DeclineReason) |
          !is.na(Labs_DeclineReason)
      )
  )
}


#' Extrapolate String Laboratory Reference Ranges
#'
#' @param edc EDC dataframe
#' @param ref_cols lab reference range column names
#'
#' @returns dataframe with low and high range columns
extract_ref_ranges <- function(edc, ref_cols) {
  
  # loop through specified columns
  for(col in ref_cols) {
    
    # extract numeric range
    nums <- str_match(
      edc[[col]],
      "(\\d+\\.?\\d*)\\s*[-–—]\\s*(\\d+\\.?\\d*)"
    )
    
    # create lowref highref columns
    edc[[paste0(col, "_lowref")]]  <- as.numeric(nums[, 2])
    edc[[paste0(col, "_highref")]] <- as.numeric(nums[, 3])
    
    # handle irregular < ref ranges return logical 
    idx.lt <- grepl("^<=", edc[[col]]) | grepl("^<", edc[[col]])
    # subset match where TRUE
    edc[[paste0(col, "_highref")]][idx.lt] <- as.numeric(sub("^<=?\\s*(\\d+\\.?\\d*).*", "\\1", edc[[col]][idx.lt]))
    edc[[paste0(col, "_lowref")]][idx.lt] <- NA
    
    # handle irregular > ref ranges return logical
    idx.gt <- grepl("^>=", edc[[col]]) | grepl("^>", edc[[col]])
    # subset match where TRUE
    edc[[paste0(col, "_lowref")]][idx.gt] <- as.numeric(sub("^>=?\\s*(\\d+\\.?\\d*).*", "\\1", edc[[col]][idx.gt]))
    edc[[paste0(col, "_highref")]][idx.gt] <- NA
    
    # high must be > low
    bad.idx <- !is.na(edc[[paste0(col, "_lowref")]]) & 
      !is.na(edc[[paste0(col, "_highref")]]) &
      edc[[paste0(col, "_highref")]] <= edc[[paste0(col, "_lowref")]]
    
    edc[[paste0(col, "_lowref")]][bad.idx] <- NA
    edc[[paste0(col, "_highref")]][bad.idx] <- NA
  }
  return(edc)
}


#' Flag Out of Range Lab Results
#'
#' @param edc EDC dataframe
#' @param map vector var mapping result vars with reference range vars
#'
#' @returns dataframe with lab results flagged out of range

flag_outrange <- function(edc, map) {
  
  for (res.col in names(map)) {
    ref.col  <- map[[res.col]]
    low.col  <- paste0(ref.col, "_lowref")
    high.col <- paste0(ref.col, "_highref")
    out.col  <- paste0(gsub("_results.*$", "", res.col), "_flag")
    
    edc[[out.col]] <- case_when(
      is.na(edc[[res.col]]) ~ "Missing Result",
      is.na(edc[[low.col]]) & is.na(edc[[high.col]]) ~ "Invalid Range",
      (!is.na(edc[[low.col]]) & edc[[res.col]] < edc[[low.col]]) ~ "Out of Range (Low)",
      (!is.na(edc[[high.col]]) & edc[[res.col]] > edc[[high.col]]) ~ "Out of Range (High)",
      TRUE ~ "In Range"
    )
  }
  return(edc)
}


#' Get Names of Out of Range Lab Tests
#'
#' @param edc EDC dataframe
#' @param flag_suffix suffix marking columns with flagged results
#'
#' @returns dataframe with lab result test names
get_flagged_test_names <- function(edc, flag_suffix = "_flag") {
  
  # auto-detect all flag columns
  flag.cols <- grep(paste0(flag_suffix, "$"), names(edc), value = TRUE)
  
  # extract test names
  test.names <- gsub(paste0(flag_suffix, "$"), "", flag.cols)
  
  # initialize new columns
  edc$OutOfRangeLow  <- NA
  edc$OutOfRangeHigh <- NA
  edc$InRange        <- NA
  edc$Missing        <- NA
  edc$Invalid        <- NA
  
  # loop rows
  for (x in seq_len(nrow(edc))) {
    
    out.low  <- c()
    out.high <- c()
    in.range <- c()
    missing  <- c()
    invalid  <- c()
    
    for (i in seq_along(flag.cols)) {
      flag.val  <- edc[[flag.cols[i]]][x]
      test.name <- test.names[i]
      
      if (flag.val == "Out of Range (Low)") {
        out.low <- c(out.low, test.name)
      } else if (flag.val == "Out of Range (High)") {
        out.high <- c(out.high, test.name)
      } else if (flag.val == "In Range") {
        in.range <- c(in.range, test.name)
      } else if (flag.val == "Missing Result") {
        missing <- c(missing, test.name)
      } else if (flag.val == "Invalid Range") {
        invalid <- c(invalid, test.name)
      }
    }
    
    edc$OutOfRangeLow[x] <- if(length(out.low) > 0) paste(out.low, collapse = ", ") else NA
    edc$OutOfRangeHigh[x] <- if(length(out.high) > 0) paste(out.high, collapse = ", ") else NA
    edc$InRange[x] <- if(length(in.range) > 0) paste(in.range, collapse = ", ") else NA
    edc$Missing[x] <- if(length(missing) > 0) paste(missing, collapse = ", ") else NA
    edc$Invalid[x] <- if(length(invalid) > 0) paste(invalid, collapse = ", ") else NA
  }
  
  return(edc)
}


#' Flag Clinically Actionable Blood Pressure Reading
#'
#' @param edc EDC dataframe 
#'
#' @returns dataframe with marked clinically actionable blood pressure results
flag_bp <- function(edc) {
  
  flagged_bp <- edc %>%
    mutate(
      AvgSysBP = (systolic2 + systolic3) / 2,
      AvgDysBP = (diastolic2 + diastolic3) / 2,
      ClinicallyActionable = case_when(
        AvgSysBP >= 140 & AvgDysBP >= 90 ~ paste0(round(AvgSysBP), "/", round(AvgDysBP)),
        AvgSysBP <= 90  & AvgDysBP <= 60 ~ paste0(round(AvgSysBP), "/", round(AvgDysBP)),
        TRUE ~ NA_character_
      )
    )
  
  return(flagged_bp %>% filter(!is.na(ClinicallyActionable)))
}



# Missing Data ------------------------------------------------------------


#' Flag Missing CRF Fields
#'
#' @param edc
#' @param cols 
#'
#' @returns dataframe with missing fields
get_missing_fields <- function(edc, cols) {
  missing <- edc %>%
    select(all_of(cols)) %>%
    mutate(
      missing_fields = apply(
        ., 1, function(row) {
          missing <- names(row)[is.na(row) | (is.character(row) & trimws(row) == "")]
          if (length(missing) == 0) NA_character_ else paste(missing, collapse = ", ")
        }
      )
    ) 
  
  return(missing %>% filter(!is.na(missing_fields)))
}

