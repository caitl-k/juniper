# **juniper**

juniper is a quality control (QC) workflow for clinical studies. It features isolated data validation and reconciliation in addition to cross-platform validation for clinical data hosted on Electronic Data Capture (EDC) systems and Laboratory Inventory Management Systems (LIMS).

## **Description**

### Background

Clinical research studies generate enormous amounts of longitudinal data. Data is often recorded across multiple systems, such as Electronic Data Capture (EDC) platforms for clinical data and Laboratory Information or Inventory Management Systems (LIMS) for sample metadata and biobanking. While these systems do perform some internal data validation, the volume of case report forms (CRFs) that can exist within a given study combined with multi-site visits, different teams entering data at different times, and manual data entry cause many mistakes to slip through the cracks. These inconsistencies arise both between data capture systems and within isolated CRFs.

juniper was developed as a reproducible QC workflow that reflects common real-world data management tasks in clinical research.

Currently, juniper supports:

- Internal EDC data checks (missing fields, invalid/impossible values, and incomplete instruments)
- Cross-platform reconciliation between EDC and LIMS (visit mismatches, missing specimens, and inconsistent dates)
- Identification of clinically implausible or out-of-range laboratory values
- Detection of consent-related discrepancies that impact downstream data use

### Use Cases

juniper is intended to provide a baseline workflow to get started performing clinical data quality control checks. While the program can be used as-is with the provided synthetic datasets, users should absolutely customize the scripts to fit a particular study's structure.

The current implementation is modelled off of REDCap and OpenSpecimen with plans to expand to other platforms such as iMedidata in the near future. 

### Synthetic Datasets

Two synthetic datasets are provided with juniper's initial release and are modeled for a hypothetical clinical study of systemic lupus erythematosus (SLE). SLE is a chronic autoimmune disease characterized by heterogeneous clinical presentations, fluctuating disease activity, and frequent laboratory monitoring. SLE was selected for demonstrating data quality workflows and its structure can be broadly applicable to other chronic diseases.

**All datasets included in this repository are synthetic. The data contained within them do not represent real participants or clinical results.** They are designed to mimic the structure, naming conventions, and common failure modes of exports from REDCap (EDC) and OpenSpecimen (LIMS). Both datasets thus intentionally include missing, incorrect, and/or inconsistent information.

## **Execution**

### juniper Contents

``` bash
juniper/
├── data/                   
│   ├── edc.csv
│   └── lims.csv
├── scripts/                 
│   ├── functions.R       
│   ├── main_ConsentFlagging.R
│   ├── main_LabResults.R
│   ├── main_CrossPlatformValidation.R
│   └── main_MissingFields.R
├── reports/              
│   ├── ConsentDiscrepancyReport.Rmd
│   ├── CrossPlatformDiscrepancyReport.Rmd
│   ├── LabResultsReport.Rmd
│   └── MissingFieldsReport.Rmd
├── outputs/                
│   ├── ConsentDiscrepancyReport.html
│   ├── CrossPlatformDiscrepancyReport.html
│   ├── LabResultsReport.html
│   └── MissingFieldsReport.html
├── DataDictionary.Rmd
├── README.md
```

### Dependencies

juniper is written in R (≥ 4.2.0 recommended) and is intended to be run in a local R environment or RStudio session. Required R package dependencies are installed (if missing) and loaded within the scripts.

### Supported Operating Systems

- Windows 10 / 11
- macOS
- Linux
### Installation

1. Clone or Download Repository:
    - Download as a `.zip` from GitHub and extract locally
    - Clone the repository with Git
2. Open Project in RStudio:
    - Open the `.Rproj` file or set the working directory to the project root `juniper/`

No additional configuration files are required as file paths are defined relative to the project root.
### Running Individual Scripts

At this time, juniper is not designed to be executed with command-line arguments. Users working in clinical environments often do not have permission to execute scripts at the terminal level.

juniper is structured to run from within an R session using predefined input locations. 

To run a specific quality control workflow, open the script, review configurable parameters (such as visit filters), and run. Each script executes independently.

### Configuring Functions

All functions used in juniper are found in `functions.R`. Some functions require replacing variable names specific to particular procedures. These are for very specific quality control checks that are based off a real-world clinical workflow and require tweaking for the study it is being used for. 

Additionally, users can configure function outputs. For example, `get_missing_fields()` outputs rows flagged with missing fields only, but a user can change this to include all rows to compare with populated fields.

### Outputs

All generated report outputs are written to the `outputs/` directory.

Rendered reports are designed for clinical operation reviews, internal reporting, or auditing. Users should customize according to the needs of a study or for general internal tracking.

Output files are overwritten on re-execution.


## **Additional Information**

### Author 

Caitl-K

### Version History

* v1
    * Initial Release

### License

This project is licensed under the MIT License. See LICENSE.md for details.
