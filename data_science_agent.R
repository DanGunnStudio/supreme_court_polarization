# =============================================================================
# DATA SCIENCE AGENT
# Supreme Court Polarization Analysis
# =============================================================================
# This script provides modular functions for analyzing Supreme Court voting
# patterns, polarization metrics, and justice collaboration.
# =============================================================================

library(tidyverse)
library(igraph)

# =============================================================================
# DATA LOADING & PREPARATION
# =============================================================================

#' Download and load Supreme Court Database
#' @param year Release year (default: 2024)
#' @param version Release version (default: "01")
#' @return Data frame with justice-centered case data
load_scdb_data <- function(year = 2024, version = "01") {
  zip_url <- sprintf(
    "http://scdb.wustl.edu/_brickFiles/%s_%s/SCDB_%s_%s_justiceCentered_Citation.Rdata.zip",
    year, version, year, version
  )
  
  zip_destfile <- sprintf("SCDB_%s_%s_justiceCentered_Citation.Rdata.zip", year, version)
  rdata_file <- sprintf("SCDB_%s_%s_justiceCentered_Citation.Rdata", year, version)
  
  if (!file.exists(rdata_file)) {
    message("Downloading Supreme Court Database...")
    download.file(zip_url, zip_destfile, mode = "wb")
    unzip(zip_destfile, exdir = ".")
    message("Download complete.")
  }
  
  # Load into environment and return
  env <- new.env()
  load(rdata_file, envir = env)
  return(env[[ls(env)[1]]])
}

#' Prepare case data with selected columns and computed fields
#' @param raw_data Raw SCDB data frame
#' @return Cleaned data frame with selected variables
prepare_case_data <- function(raw_data) {
  raw_data |>
    select(
      caseId,
      dateDecision,
      majVotes,
      minVotes,
      justice,
      justiceName,
      vote,
      direction,
      majority
    ) |>
    mutate(
      year = year(dateDecision),
      agreement_percentage = if_else(
        minVotes == 0,
        100,  # Set to 100% if unanimous
        (majVotes / (majVotes + minVotes)) * 100
      )
    )
}

# =============================================================================
# PAIRWISE AGREEMENT ANALYSIS
# =============================================================================

#' Calculate pairwise voting agreement between all justice pairs
#' @param cases_data Prepared case data from prepare_case_data()
#' @return Data frame with pairwise agreement rates
calculate_pairwise_agreement <- function(cases_data) {
  # Create all unique pairs of justices within each case
  justice_pairs <- cases_data |>
    group_by(caseId) |>
    nest(.key = "case_votes") |>
    mutate(pairs = map(case_votes, ~ 
                         tidyr::crossing(
                           rename_with(.x, ~ paste0(.x, "_1")), 
                           rename_with(.x, ~ paste0(.x, "_2"))
                         ) %>%
                         filter(justiceName_1 < justiceName_2))) |>
    select(-case_votes) |>
    unnest(pairs)
  
  # Compare votes for each justice pair within each case
  justice_pairs <- justice_pairs |>
    mutate(voted_together = vote_1 == vote_2)
  
  # Summarize how often each pair voted together across all cases
  voting_summary <- justice_pairs |>
    group_by(justiceName_1, justiceName_2) |>
    summarize(
      times_voted_together = sum(voted_together, na.rm = TRUE),
      total_cases = n(),
      agreement_rate = times_voted_together / total_cases,
      .groups = "drop"
    )
  
  return(voting_summary)
}

#' Calculate pairwise agreement for a specific year
#' @param cases_data Prepared case data
#' @param target_year Year to analyze
#' @return Data frame with pairwise agreement for that year
calculate_yearly_agreement <- function(cases_data, target_year) {
  year_data <- cases_data |>
    filter(year == target_year) |>
    pivot_wider(
      id_cols = c(caseId, year),
      names_from = justiceName,
      values_from = vote
    )
  
  year_data |>
    rowwise() |>
    mutate(pairwise = list({
      justice_votes <- pick(-caseId, -year) |>
        select(where(~ !all(is.na(.))))
      
      if (ncol(justice_votes) < 2) return(tibble())
      
      combn(names(justice_votes), 2, simplify = FALSE) |>
        purrr::map_df(~ {
          justice1 <- .x[1]
          justice2 <- .x[2]
          votes1 <- justice_votes[[justice1]]
          votes2 <- justice_votes[[justice2]]
          
          valid_indices <- !is.na(votes1) & !is.na(votes2)
          agreement_rate <- if (sum(valid_indices) > 0) {
            mean(votes1[valid_indices] == votes2[valid_indices], na.rm = TRUE)
          } else {
            NA
          }
          
          tibble(
            Justice1 = justice1,
            Justice2 = justice2,
            Agreement = agreement_rate
          )
        })
    })) |>
    unnest(pairwise) |>
    select(caseId, Justice1, Justice2, Agreement) |>
    group_by(Justice1, Justice2) |>
    summarise(
      MeanAgreement = mean(Agreement, na.rm = TRUE),
      CasesCompared = sum(!is.na(Agreement)),
      .groups = "drop"
    )
}

# =============================================================================
# POLARIZATION METRICS
# =============================================================================

#' Calculate polarization metrics by year
#' @param cases_data Prepared case data
#' @return Data frame with yearly polarization metrics
calculate_polarization_by_year <- function(cases_data) {
  # First create wide format
  votes_wide <- cases_data |>
    group_by(year) |>
    pivot_wider(
      id_cols = c(caseId, year),
      names_from = justiceName,
      values_from = vote
    ) |>
    ungroup()
  
  # Calculate yearly pairwise agreement
  yearly_pairwise <- votes_wide |>
    rowwise() |>
    mutate(pairwise = list({
      justice_votes <- pick(-year, -caseId) |> 
        select(where(~ !all(is.na(.))))
      
      if (ncol(justice_votes) < 2) return(tibble())
      
      expand.grid(
        Justice1 = names(justice_votes), 
        Justice2 = names(justice_votes), 
        stringsAsFactors = FALSE
      ) |>
        filter(Justice1 < Justice2) |>
        rowwise() |>
        mutate(
          Agreement = {
            votes1 <- justice_votes[[Justice1]]
            votes2 <- justice_votes[[Justice2]]
            valid_indices <- !is.na(votes1) & !is.na(votes2)
            if (sum(valid_indices) > 0) {
              mean(votes1[valid_indices] == votes2[valid_indices], na.rm = TRUE)
            } else {
              NA
            }
          }
        ) |>
        ungroup()
    })) |>
    unnest(pairwise) |>
    group_by(caseId, year, Justice1, Justice2) |>
    summarise(Agreement = mean(Agreement, na.rm = TRUE), .groups = "drop")
  
  # Compute variance of agreement rates by year
  polarization <- yearly_pairwise |>
    group_by(year) |>
    summarise(
      AgreementVariance = var(Agreement, na.rm = TRUE),
      MeanAgreement = mean(Agreement, na.rm = TRUE),
      MedianAgreement = median(Agreement, na.rm = TRUE),
      MinAgreement = min(Agreement, na.rm = TRUE),
      MaxAgreement = max(Agreement, na.rm = TRUE),
      PairwiseCount = n(),
      .groups = "drop"
    )
  
  return(polarization)
}

#' Calculate average ideological direction by year
#' @param cases_data Prepared case data
#' @return Data frame with yearly ideological direction
calculate_ideological_direction <- function(cases_data) {
  cases_data |>
    group_by(year) |>
    summarize(
      avg_direction = mean(direction, na.rm = TRUE),
      sd_direction = sd(direction, na.rm = TRUE),
      n_cases = n_distinct(caseId),
      .groups = "drop"
    )
}

#' Calculate average agreement percentage by year
#' @param cases_data Prepared case data
#' @return Data frame with yearly agreement percentages
calculate_agreement_trend <- function(cases_data) {
  cases_data |>
    group_by(year) |>
    summarize(
      avg_agree_perc = mean(agreement_percentage, na.rm = TRUE),
      sd_agree_perc = sd(agreement_percentage, na.rm = TRUE),
      n_cases = n_distinct(caseId),
      .groups = "drop"
    )
}

# =============================================================================
# CLUSTER ANALYSIS
# =============================================================================

#' Create agreement matrix from pairwise data
#' @param pairwise_data Pairwise agreement data (from calculate_yearly_agreement)
#' @return Symmetric agreement matrix
create_agreement_matrix <- function(pairwise_data) {
  all_justices <- unique(c(pairwise_data$Justice1, pairwise_data$Justice2))
  
  agreement_matrix <- matrix(
    NA, 
    nrow = length(all_justices), 
    ncol = length(all_justices)
  )
  rownames(agreement_matrix) <- all_justices
  colnames(agreement_matrix) <- all_justices
  
  for (i in seq_len(nrow(pairwise_data))) {
    row <- pairwise_data$Justice1[i]
    col <- pairwise_data$Justice2[i]
    value <- pairwise_data$MeanAgreement[i]
    
    agreement_matrix[row, col] <- value
    agreement_matrix[col, row] <- value
  }
  
  # Set diagonal to 1 (perfect agreement with self)
  diag(agreement_matrix) <- 1
  
  return(agreement_matrix)
}

#' Perform hierarchical clustering on justices
#' @param agreement_matrix Symmetric agreement matrix
#' @param method Clustering method (default: "complete")
#' @return hclust object
cluster_justices <- function(agreement_matrix, method = "complete") {
  # Ensure matrix is symmetric and has no NA
  agreement_matrix[is.na(agreement_matrix)] <- 0
  agreement_matrix <- (agreement_matrix + t(agreement_matrix)) / 2
  
  # Calculate dissimilarity matrix
  distance_matrix <- as.dist(1 - agreement_matrix)
  
  # Perform hierarchical clustering
  hclust(distance_matrix, method = method)
}

#' Cut cluster tree into k groups
#' @param clusters hclust object
#' @param k Number of clusters
#' @return Named vector of cluster assignments
get_cluster_groups <- function(clusters, k = 2) {
  cutree(clusters, k = k)
}

# =============================================================================
# NETWORK ANALYSIS
# =============================================================================
#' Create network graph from voting summary
#' @param voting_summary Pairwise voting agreement data
#' @param threshold Minimum agreement rate to include edge (default: 0.5)
#' @return igraph object
create_voting_network <- function(voting_summary, threshold = 0.5) {
  edge_list <- voting_summary |>
    filter(agreement_rate >= threshold) |>
    select(justiceName_1, justiceName_2, agreement_rate)
  
  graph_from_data_frame(d = edge_list, directed = FALSE)
}

#' Calculate network metrics for justices
#' @param network igraph object
#' @return Data frame with network centrality metrics
calculate_network_metrics <- function(network) {
  tibble(
    justice = V(network)$name,
    degree = degree(network),
    betweenness = betweenness(network),
    closeness = closeness(network),
    eigenvector = eigen_centrality(network)$vector
  ) |>
    arrange(desc(eigenvector))
}

#' Detect communities in voting network
#' @param network igraph object
#' @return communities object
detect_voting_communities <- function(network) {
  cluster_louvain(network)
}

# =============================================================================
# JUSTICE-LEVEL ANALYSIS
# =============================================================================

#' Calculate justice-level statistics
#' @param cases_data Prepared case data
#' @return Data frame with per-justice statistics
calculate_justice_stats <- function(cases_data) {
  cases_data |>
    group_by(justiceName, justice) |>
    summarize(
      first_year = min(year),
      last_year = max(year),
      tenure_years = last_year - first_year + 1,
      total_votes = n(),
      avg_direction = mean(direction, na.rm = TRUE),
      majority_rate = mean(majority == 2, na.rm = TRUE),  # 2 = majority
      .groups = "drop"
    ) |>
    arrange(first_year)
}

#' Calculate justice voting patterns by year
#' @param cases_data Prepared case data
#' @return Data frame with yearly justice-level data
calculate_justice_yearly_patterns <- function(cases_data) {
  cases_data |>
    group_by(year, justiceName) |>
    summarize(
      avg_direction = mean(direction, na.rm = TRUE),
      n_votes = n(),
      majority_rate = mean(majority == 2, na.rm = TRUE),
      .groups = "drop"
    ) |>
    # Handle edge cases where direction == 1 for intro years
    group_by(justiceName) |>
    mutate(
      avg_direction_mean = mean(avg_direction[avg_direction != 1], na.rm = TRUE),
      avg_direction = if_else(avg_direction == 1, avg_direction_mean, avg_direction)
    ) |>
    select(-avg_direction_mean) |>
    ungroup()
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

#' Save analysis results to CSV
#' @param data Data frame to save
#' @param filename Output filename
#' @param dir Directory for output (default: "clean_data")
save_analysis <- function(data, filename, dir = "clean_data") {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  filepath <- file.path(dir, filename)
  write_csv(data, filepath)
  message(sprintf("Saved: %s", filepath))
}

#' Print summary of polarization analysis
#' @param polarization_data Polarization data from calculate_polarization_by_year()
summarize_polarization <- function(polarization_data) {
  cat("=== Supreme Court Polarization Summary ===\n\n")
  
  # Overall stats
  cat("Overall Statistics:\n")
  cat(sprintf("  Years covered: %d - %d\n", 
              min(polarization_data$year), 
              max(polarization_data$year)))
  cat(sprintf("  Mean Agreement: %.1f%%\n", 
              mean(polarization_data$MeanAgreement) * 100))
  cat(sprintf("  Mean Variance: %.4f\n", 
              mean(polarization_data$AgreementVariance)))
  
  # Trend
  recent <- polarization_data |> filter(year >= 2000)
  historical <- polarization_data |> filter(year < 2000)
  
  cat("\nHistorical vs Recent Comparison:\n")
  cat(sprintf("  Pre-2000 Mean Variance: %.4f\n", 
              mean(historical$AgreementVariance)))
  cat(sprintf("  Post-2000 Mean Variance: %.4f\n", 
              mean(recent$AgreementVariance)))
  
  # Most/least polarized years
  most_polarized <- polarization_data |> 
    slice_max(AgreementVariance, n = 5)
  least_polarized <- polarization_data |> 
    slice_min(AgreementVariance, n = 5)
  
  cat("\nMost Polarized Years:\n")
  for (i in 1:nrow(most_polarized)) {
    cat(sprintf("  %d: Variance = %.4f\n", 
                most_polarized$year[i], 
                most_polarized$AgreementVariance[i]))
  }
  
  cat("\nLeast Polarized Years:\n")
  for (i in 1:nrow(least_polarized)) {
    cat(sprintf("  %d: Variance = %.4f\n", 
                least_polarized$year[i], 
                least_polarized$AgreementVariance[i]))
  }
}

# =============================================================================
# EXAMPLE USAGE
# =============================================================================
# 
# # Load and prepare data
# raw_data <- load_scdb_data()
# cases_data <- prepare_case_data(raw_data)
# 
# # Calculate pairwise agreement
# voting_summary <- calculate_pairwise_agreement(cases_data)
# save_analysis(voting_summary, "voting_summary.csv")
# 
# # Calculate polarization metrics
# polarization <- calculate_polarization_by_year(cases_data)
# summarize_polarization(polarization)
# 
# # Cluster analysis for a specific year
# agreement_1946 <- calculate_yearly_agreement(cases_data, 1946)
# matrix_1946 <- create_agreement_matrix(agreement_1946)
# clusters <- cluster_justices(matrix_1946)
# 
# # Network analysis
# network <- create_voting_network(voting_summary, threshold = 0.6)
# metrics <- calculate_network_metrics(network)
# =============================================================================
