# =============================================================================
# SUPREME COURT POLARIZATION ANALYSIS
# =============================================================================
# Implements the analysis plan for investigating polarization trends
# on the United States Supreme Court (1946-2023)
#
# Author: Data Science Agent
# Date: January 2026
# =============================================================================

# -----------------------------------------------------------------------------
# 1. SETUP & LIBRARIES
# -----------------------------------------------------------------------------

library(tidyverse)
library(ggiraph)
library(patchwork)
library(ggrepel)
library(htmlwidgets)
library(igraph)
library(ggraph)
library(showtext)
library(pheatmap)

# Setup fonts
showtext_auto()
font_add_google("Lato", "lato")
font_add_google("Inknut Antiqua", "inknut")

# Create output directories
dir.create("clean_data", showWarnings = FALSE)
dir.create("charts", showWarnings = FALSE)
dir.create("reports", showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 2. THEME & PALETTES
# -----------------------------------------------------------------------------

theme_court <- function() {

theme(
    text = element_text(family = "lato"),
    plot.title = element_text(family = "inknut", face = "bold", size = 16),
    plot.subtitle = element_text(size = 12, color = "gray40"),
    plot.caption = element_text(size = 9, color = "gray50"),
    axis.text = element_text(size = 10),
    axis.title = element_text(size = 11, face = "bold"),
    panel.grid = element_blank(),
    panel.grid.major.y = element_line(size = 0.2, color = "#E0E0E0"),
    panel.background = element_blank(),
    plot.background = element_rect(fill = "#ffffff", color = NA),
    legend.background = element_blank(),
    legend.position = "top",
    legend.title = element_text(size = 10, face = "bold")
  )
}

# Ideological color scale
scale_color_ideology <- function() {
  scale_color_gradient2(
    low = "#E41A1C",
    mid = "gray70",
    high = "#377EB8",
    midpoint = 1.5,
    limits = c(1, 2),
    name = "Direction\n(1=Cons, 2=Lib)"
  )
}

scale_fill_ideology <- function() {
  scale_fill_gradient2(
    low = "#E41A1C",
    mid = "gray70", 
    high = "#377EB8",
    midpoint = 1.5,
    limits = c(1, 2),
    name = "Direction"
  )
}

# -----------------------------------------------------------------------------
# 3. DATA LOADING & PREPARATION
# -----------------------------------------------------------------------------

cat("Loading SCDB data...\n")

# Download if not present
if (!file.exists("SCDB_2024_01_justiceCentered_Citation.Rdata")) {
  zip_url <- "http://scdb.wustl.edu/_brickFiles/2024_01/SCDB_2024_01_justiceCentered_Citation.Rdata.zip"
  download.file(zip_url, "SCDB.zip", mode = "wb")
  unzip("SCDB.zip", exdir = ".")
}

load("SCDB_2024_01_justiceCentered_Citation.Rdata")

# Prepare case data
cases_selected <- SCDB_2024_01_justiceCentered_Citation |>
  select(
    caseId, dateDecision, term, majVotes, minVotes,
    justice, justiceName, vote, direction, majority,
    issueArea, decisionDirection
  ) |>
  mutate(
    year = term,
    decade = floor(term / 10) * 10,
    agreement_percentage = if_else(
      minVotes == 0, 100,
      (majVotes / (majVotes + minVotes)) * 100
    ),
    is_5_4 = (majVotes == 5 & minVotes == 4),
    is_unanimous = (minVotes == 0)
  )

cat("Data loaded:", nrow(cases_selected), "observations\n")

# -----------------------------------------------------------------------------
# 4. PAIRWISE AGREEMENT CALCULATION
# -----------------------------------------------------------------------------

cat("Calculating pairwise agreement rates...\n")

# Create wide format for pairwise calculations
votes_wide <- cases_selected |>
  pivot_wider(
    id_cols = c(caseId, year),
    names_from = justiceName,
    values_from = vote
  )

# Function to calculate pairwise agreement for a given year range
calculate_pairwise_for_period <- function(data, start_year, end_year) {
  period_data <- data |> filter(year >= start_year & year <= end_year)
  
  period_data |>
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
            valid <- !is.na(votes1) & !is.na(votes2)
            if (sum(valid) > 0) mean(votes1[valid] == votes2[valid]) else NA
          }
        ) |>
        ungroup()
    })) |>
    unnest(pairwise) |>
    group_by(Justice1, Justice2) |>
    summarize(
      agreement_rate = mean(Agreement, na.rm = TRUE),
      cases_together = sum(!is.na(Agreement)),
      .groups = "drop"
    )
}

# Calculate overall pairwise agreement
voting_summary <- cases_selected |>
  group_by(caseId) |>
  nest(.key = "case_votes") |>
  mutate(pairs = map(case_votes, ~
    tidyr::crossing(
      rename_with(.x, ~ paste0(.x, "_1")),
      rename_with(.x, ~ paste0(.x, "_2"))
    ) |>
    filter(justiceName_1 < justiceName_2)
  )) |>
  select(-case_votes) |>
  unnest(pairs) |>
  mutate(voted_together = vote_1 == vote_2) |>
  group_by(justiceName_1, justiceName_2) |>
  summarize(
    times_voted_together = sum(voted_together, na.rm = TRUE),
    total_cases = n(),
    agreement_rate = times_voted_together / total_cases,
    .groups = "drop"
  )

write_csv(voting_summary, "clean_data/voting_summary.csv")
cat("Saved: clean_data/voting_summary.csv\n")

# -----------------------------------------------------------------------------
# 5. POLARIZATION METRICS BY YEAR
# -----------------------------------------------------------------------------

cat("Computing polarization metrics...\n")

# Calculate yearly pairwise agreement and variance
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
          valid <- !is.na(votes1) & !is.na(votes2)
          if (sum(valid) > 0) mean(votes1[valid] == votes2[valid]) else NA
        }
      ) |>
      ungroup()
  })) |>
  unnest(pairwise) |>
  group_by(caseId, year, Justice1, Justice2) |>
  summarize(Agreement = mean(Agreement, na.rm = TRUE), .groups = "drop")

# Agreement Variance Index (AVI) by year
polarization_by_year <- yearly_pairwise |>
  group_by(year) |>
  summarize(
    agreement_variance = var(Agreement, na.rm = TRUE),
    mean_agreement = mean(Agreement, na.rm = TRUE),
    median_agreement = median(Agreement, na.rm = TRUE),
    min_agreement = min(Agreement, na.rm = TRUE),
    max_agreement = max(Agreement, na.rm = TRUE),
    agreement_range = max_agreement - min_agreement,
    n_pairs = n(),
    .groups = "drop"
  )

# Add case-level metrics
case_metrics <- cases_selected |>
  group_by(year) |>
  summarize(
    n_cases = n_distinct(caseId),
    avg_direction = mean(direction, na.rm = TRUE),
    pct_5_4 = mean(is_5_4, na.rm = TRUE) * 100,
    pct_unanimous = mean(is_unanimous, na.rm = TRUE) * 100,
    dissent_rate = mean(vote == 2, na.rm = TRUE) * 100,
    .groups = "drop"
  )

polarization_metrics <- polarization_by_year |>
  left_join(case_metrics, by = "year")

write_csv(polarization_metrics, "clean_data/polarization_metrics.csv")
cat("Saved: clean_data/polarization_metrics.csv\n")

# -----------------------------------------------------------------------------
# 6. JUSTICE-LEVEL STATISTICS
# -----------------------------------------------------------------------------

cat("Computing justice-level statistics...\n")

justice_stats <- cases_selected |>
  group_by(justiceName, justice) |>
  summarize(
    first_term = min(term),
    last_term = max(term),
    tenure_years = last_term - first_term + 1,
    total_votes = n(),
    avg_direction = mean(direction, na.rm = TRUE),
    direction_sd = sd(direction, na.rm = TRUE),
    majority_rate = mean(majority == 2, na.rm = TRUE) * 100,
    dissent_rate = mean(vote == 2, na.rm = TRUE) * 100,
    concurrence_rate = mean(vote %in% c(3, 4), na.rm = TRUE) * 100,
    .groups = "drop"
  ) |>
  # Swing Justice Index: how close to center (1.5)
  mutate(
    swing_index = 1 - abs(avg_direction - 1.5) / 0.5,
    ideology_label = case_when(
      avg_direction < 1.4 ~ "Strong Conservative",
      avg_direction < 1.48 ~ "Conservative",
      avg_direction < 1.52 ~ "Moderate/Swing",
      avg_direction < 1.6 ~ "Liberal",
      TRUE ~ "Strong Liberal"
    )
  ) |>
  arrange(first_term)

write_csv(justice_stats, "clean_data/justice_ideology_scores.csv")
cat("Saved: clean_data/justice_ideology_scores.csv\n")

# Justice yearly patterns
justice_yearly <- cases_selected |>
  group_by(year, justiceName) |>
  summarize(
    avg_direction = mean(direction, na.rm = TRUE),
    n_votes = n(),
    dissent_rate = mean(vote == 2, na.rm = TRUE) * 100,
    .groups = "drop"
  ) |>
  # Handle intro year artifacts
  group_by(justiceName) |>
  mutate(
    overall_avg = mean(avg_direction[avg_direction != 1], na.rm = TRUE),
    avg_direction = if_else(avg_direction == 1 & n_votes < 50, overall_avg, avg_direction)
  ) |>
  select(-overall_avg) |>
  ungroup()

write_csv(justice_yearly, "clean_data/justice_yearly_patterns.csv")
cat("Saved: clean_data/justice_yearly_patterns.csv\n")

# -----------------------------------------------------------------------------
# 7. VISUALIZATIONS
# -----------------------------------------------------------------------------

cat("Generating visualizations...\n")

# --- 7.1 Polarization Trend (Agreement Variance) ---

p_polarization <- ggplot(polarization_metrics, aes(x = year, y = agreement_variance)) +
  geom_line(color = "#E41A1C", alpha = 0.5) +
  geom_point(color = "#E41A1C", alpha = 0.7, size = 1.5) +
  geom_smooth(method = "loess", span = 0.3, color = "#377EB8", fill = "#377EB8", alpha = 0.2) +
  labs(
    title = "Polarization on the Supreme Court (1946-2023)",
    subtitle = "Agreement Variance Index: Higher values indicate greater polarization",
    x = NULL,
    y = "Variance in Pairwise Agreement",
    caption = "Source: Supreme Court Database | Higher variance = justices voting in distinct blocs"
  ) +
  theme_minimal() +
  theme_court()

ggsave("charts/polarization_trend.png", p_polarization, width = 10, height = 6, dpi = 300, bg = "white")
cat("Saved: charts/polarization_trend.png\n")

# --- 7.2 Ideological Swing ---

p_ideology <- ggplot(polarization_metrics, aes(x = year, y = avg_direction, color = avg_direction)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  geom_hline(yintercept = 1.5, linetype = "dashed", color = "gray50") +
  geom_smooth(method = "loess", span = 0.3, color = "black", linetype = "dashed", se = FALSE, size = 0.8) +
  scale_color_ideology() +
  annotate("text", x = 1948, y = 1.52, label = "Neutral", hjust = 0, size = 3, color = "gray50") +
  labs(
    title = "Ideological Direction of Supreme Court Decisions",
    subtitle = "1 = Conservative, 2 = Liberal | Dashed line shows trend",
    x = NULL,
    y = "Average Ideological Direction",
    caption = "Source: Supreme Court Database"
  ) +
  theme_minimal() +
  theme_court()

ggsave("charts/ideological_swing.png", p_ideology, width = 10, height = 6, dpi = 300, bg = "white")
cat("Saved: charts/ideological_swing.png\n")

# --- 7.3 5-4 Decisions Trend ---

p_5_4 <- ggplot(polarization_metrics, aes(x = year, y = pct_5_4)) +
  geom_col(fill = "#E41A1C", alpha = 0.7, width = 0.8) +
  geom_smooth(method = "loess", span = 0.3, color = "#377EB8", se = FALSE, size = 1.2) +
  labs(
    title = "5-4 Decisions: A Proxy for Polarization",
    subtitle = "Percentage of cases decided by minimum majority",
    x = NULL,
    y = "% of Cases (5-4)",
    caption = "Source: Supreme Court Database"
  ) +
  theme_minimal() +
  theme_court()

ggsave("charts/five_four_trend.png", p_5_4, width = 10, height = 6, dpi = 300, bg = "white")
cat("Saved: charts/five_four_trend.png\n")

# --- 7.4 Unanimous Decisions Trend ---

p_unanimous <- ggplot(polarization_metrics, aes(x = year, y = pct_unanimous)) +
  geom_col(fill = "#4DAF4A", alpha = 0.7, width = 0.8) +
  geom_smooth(method = "loess", span = 0.3, color = "#377EB8", se = FALSE, size = 1.2) +
  labs(
    title = "Unanimous Decisions Over Time",
    subtitle = "Percentage of 9-0 decisions by term",
    x = NULL,
    y = "% Unanimous (9-0)",
    caption = "Source: Supreme Court Database"
  ) +
  theme_minimal() +
  theme_court()

ggsave("charts/unanimous_trend.png", p_unanimous, width = 10, height = 6, dpi = 300, bg = "white")
cat("Saved: charts/unanimous_trend.png\n")

# --- 7.5 Justice Timeline with Ideology ---

justice_endpoints <- justice_stats |>
  select(justiceName, first_term, last_term, avg_direction) |>
  pivot_longer(cols = c(first_term, last_term), names_to = "endpoint", values_to = "year")

p_timeline <- justice_stats |>
  ggplot(aes(y = reorder(justiceName, first_term))) +
  geom_segment(
    aes(x = first_term, xend = last_term, yend = reorder(justiceName, first_term), color = avg_direction),
    size = 4, lineend = "round"
  ) +
  scale_color_ideology() +
  labs(
    title = "Supreme Court Justice Tenures (1946-2023)",
    subtitle = "Color indicates ideological direction: Red = Conservative, Blue = Liberal",
    x = "Term",
    y = NULL,
    caption = "Source: Supreme Court Database"
  ) +
  theme_minimal() +
  theme_court() +
  theme(
    axis.text.y = element_text(size = 8),
    legend.position = "bottom"
  )

ggsave("charts/justice_timeline.png", p_timeline, width = 10, height = 12, dpi = 300, bg = "white")
cat("Saved: charts/justice_timeline.png\n")

# --- 7.6 Justice Ideology Scatter ---

p_scatter <- justice_stats |>
  ggplot(aes(x = avg_direction, y = dissent_rate, color = avg_direction)) +
  geom_point(aes(size = tenure_years), alpha = 0.7) +
  geom_text_repel(aes(label = justiceName), size = 3, max.overlaps = 15) +
  geom_vline(xintercept = 1.5, linetype = "dashed", color = "gray50") +
  scale_color_ideology() +
  scale_size_continuous(range = c(2, 8), name = "Tenure (years)") +
  labs(
    title = "Justice Ideology vs. Dissent Behavior",
    subtitle = "Position shows ideology; size shows tenure length",
    x = "Average Ideological Direction (1=Conservative, 2=Liberal)",
    y = "Dissent Rate (%)",
    caption = "Source: Supreme Court Database"
  ) +
  theme_minimal() +
  theme_court()

ggsave("charts/justice_ideology_scatter.png", p_scatter, width = 12, height = 8, dpi = 300, bg = "white")
cat("Saved: charts/justice_ideology_scatter.png\n")

# --- 7.7 Swing Justice Rankings ---

p_swing <- justice_stats |>
  filter(tenure_years >= 5) |>  # Only justices with meaningful tenure
  arrange(desc(swing_index)) |>
  head(20) |>
  ggplot(aes(x = reorder(justiceName, swing_index), y = swing_index, fill = avg_direction)) +
  geom_col(width = 0.7) +
  coord_flip() +
  scale_fill_ideology() +
  labs(
    title = "Swing Justice Index: Who Votes Closest to Center?",
    subtitle = "Higher index = more centrist voting pattern (justices with 5+ year tenure)",
    x = NULL,
    y = "Swing Index (1 = perfect centrist)",
    caption = "Source: Supreme Court Database | Index = 1 - |avg_direction - 1.5| / 0.5"
  ) +
  theme_minimal() +
  theme_court()

ggsave("charts/swing_justice_index.png", p_swing, width = 10, height = 8, dpi = 300, bg = "white")
cat("Saved: charts/swing_justice_index.png\n")

# --- 7.8 Interactive Justice Patterns ---

p_interactive <- justice_yearly |>
  ggplot(aes(x = year, y = avg_direction, group = justiceName, color = avg_direction, data_id = justiceName)) +
  geom_line_interactive(aes(tooltip = justiceName), size = 1) +
  geom_point_interactive(aes(tooltip = paste(justiceName, year, sep = "\n")), size = 1.5) +
  scale_color_ideology() +
  labs(
    title = "Interactive: Individual Justice Voting Patterns",
    subtitle = "Hover over lines to highlight individual justices",
    x = NULL,
    y = "Average Direction (1=Conservative, 2=Liberal)"
  ) +
  theme_minimal() +
  theme_court()

interactive_chart <- girafe(
  ggobj = p_interactive,
  options = list(
    opts_hover(css = "stroke-width:3;"),
    opts_hover_inv(css = "opacity:0.1;"),
    opts_sizing(rescale = FALSE)
  ),
  height_svg = 6,
  width_svg = 10
)

saveWidget(interactive_chart, file = "charts/justice_patterns_interactive.html", selfcontained = TRUE)
cat("Saved: charts/justice_patterns_interactive.html\n")

# --- 7.9 Agreement Heatmap (Current Court) ---

# Get current justices
current_justices <- justice_stats |>
  filter(last_term == 2023) |>
  pull(justiceName)

current_agreement <- voting_summary |>
  filter(justiceName_1 %in% current_justices & justiceName_2 %in% current_justices)

# Build matrix
current_matrix <- matrix(NA, nrow = length(current_justices), ncol = length(current_justices))
rownames(current_matrix) <- current_justices
colnames(current_matrix) <- current_justices

for (i in seq_len(nrow(current_agreement))) {
  j1 <- current_agreement$justiceName_1[i]
  j2 <- current_agreement$justiceName_2[i]
  val <- current_agreement$agreement_rate[i]
  current_matrix[j1, j2] <- val
  current_matrix[j2, j1] <- val
}
diag(current_matrix) <- 1

# Order by ideology
ideology_order <- justice_stats |>
  filter(justiceName %in% current_justices) |>
  arrange(avg_direction) |>
  pull(justiceName)

current_matrix <- current_matrix[ideology_order, ideology_order]

png("charts/current_court_heatmap.png", width = 1000, height = 900, res = 150)
pheatmap(
  current_matrix,
  color = colorRampPalette(c("#E41A1C", "white", "#377EB8"))(100),
  main = "Current Court: Pairwise Agreement Rates",
  fontsize = 10,
  display_numbers = TRUE,
  number_format = "%.0f%%",
  number_color = "black",
  cluster_rows = FALSE,
  cluster_cols = FALSE
)
dev.off()
cat("Saved: charts/current_court_heatmap.png\n")

# --- 7.10 Decade Comparison Heatmaps ---

create_decade_heatmap <- function(decade_start) {
  decade_data <- cases_selected |>
    filter(decade == decade_start)
  
  decade_justices <- unique(decade_data$justiceName)
  
  decade_agreement <- voting_summary |>
    filter(justiceName_1 %in% decade_justices & justiceName_2 %in% decade_justices)
  
  if (nrow(decade_agreement) < 3) return(NULL)
  
  decade_matrix <- matrix(NA, nrow = length(decade_justices), ncol = length(decade_justices))
  rownames(decade_matrix) <- decade_justices
  colnames(decade_matrix) <- decade_justices
  
  for (i in seq_len(nrow(decade_agreement))) {
    j1 <- decade_agreement$justiceName_1[i]
    j2 <- decade_agreement$justiceName_2[i]
    if (j1 %in% decade_justices & j2 %in% decade_justices) {
      val <- decade_agreement$agreement_rate[i]
      decade_matrix[j1, j2] <- val
      decade_matrix[j2, j1] <- val
    }
  }
  diag(decade_matrix) <- 1
  
  decade_matrix
}

# --- 7.11 Voting Network Graph ---

# Create network from agreement data
network_data <- voting_summary |>
  filter(agreement_rate >= 0.5, total_cases >= 100)

g <- graph_from_data_frame(
  d = network_data |> select(justiceName_1, justiceName_2, agreement_rate),
  directed = FALSE
)

# Add justice attributes
V(g)$ideology <- justice_stats$avg_direction[match(V(g)$name, justice_stats$justiceName)]

p_network <- ggraph(g, layout = "fr") +
  geom_edge_link(aes(alpha = agreement_rate, width = agreement_rate), color = "gray60") +
  scale_edge_width(range = c(0.3, 2), name = "Agreement") +
  scale_edge_alpha(range = c(0.2, 0.6), guide = "none") +
  geom_node_point(aes(color = ideology), size = 6) +
  geom_node_text(aes(label = name), repel = TRUE, size = 3) +
  scale_color_gradient2(
    low = "#E41A1C", mid = "gray70", high = "#377EB8",
    midpoint = 1.5, name = "Ideology"
  ) +
  labs(
    title = "Supreme Court Voting Network",
    subtitle = "Edges show agreement rate ≥50% with 100+ shared cases",
    caption = "Source: Supreme Court Database"
  ) +
  theme_void() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray40"),
    legend.position = "right"
  )

ggsave("charts/voting_network.png", p_network, width = 12, height = 10, dpi = 300, bg = "white")
cat("Saved: charts/voting_network.png\n")

# --- 7.12 Polarization Dashboard ---

p_dashboard <- (
  (p_polarization + labs(title = "Polarization Index")) +
  (p_ideology + labs(title = "Ideological Direction"))
) / (
  (p_5_4 + labs(title = "5-4 Decisions")) +
  (p_unanimous + labs(title = "Unanimous Decisions"))
) +
  plot_annotation(
    title = "Supreme Court Polarization Dashboard (1946-2023)",
    subtitle = "Key metrics tracking division on the Court",
    caption = "Source: Supreme Court Database | Analysis by Data Science Agent",
    theme = theme(
      plot.title = element_text(face = "bold", size = 18),
      plot.subtitle = element_text(size = 12, color = "gray40")
    )
  )

ggsave("charts/polarization_dashboard.png", p_dashboard, width = 14, height = 12, dpi = 300, bg = "white")
cat("Saved: charts/polarization_dashboard.png\n")

# -----------------------------------------------------------------------------
# 8. SUMMARY STATISTICS REPORT
# -----------------------------------------------------------------------------

cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("                    ANALYSIS SUMMARY REPORT                        \n")
cat("═══════════════════════════════════════════════════════════════════\n\n")

cat("DATASET:\n")
cat("  Total votes:", format(nrow(cases_selected), big.mark = ","), "\n")
cat("  Unique cases:", format(length(unique(cases_selected$caseId)), big.mark = ","), "\n")
cat("  Unique justices:", length(unique(cases_selected$justiceName)), "\n")
cat("  Time period:", min(cases_selected$term), "-", max(cases_selected$term), "\n\n")

cat("POLARIZATION TRENDS:\n")
early_avi <- mean(polarization_metrics$agreement_variance[polarization_metrics$year < 1980], na.rm = TRUE)
late_avi <- mean(polarization_metrics$agreement_variance[polarization_metrics$year >= 2000], na.rm = TRUE)
cat("  Avg Agreement Variance (pre-1980):", round(early_avi, 4), "\n")
cat("  Avg Agreement Variance (2000+):", round(late_avi, 4), "\n")
cat("  Change:", round((late_avi - early_avi) / early_avi * 100, 1), "%\n\n")

cat("5-4 DECISIONS:\n")
early_54 <- mean(polarization_metrics$pct_5_4[polarization_metrics$year < 1980], na.rm = TRUE)
late_54 <- mean(polarization_metrics$pct_5_4[polarization_metrics$year >= 2000], na.rm = TRUE)
cat("  Avg % 5-4 (pre-1980):", round(early_54, 1), "%\n")
cat("  Avg % 5-4 (2000+):", round(late_54, 1), "%\n\n")

cat("IDEOLOGICAL SHIFT:\n")
early_dir <- mean(polarization_metrics$avg_direction[polarization_metrics$year < 1980], na.rm = TRUE)
late_dir <- mean(polarization_metrics$avg_direction[polarization_metrics$year >= 2000], na.rm = TRUE)
cat("  Avg Direction (pre-1980):", round(early_dir, 3), "\n")
cat("  Avg Direction (2000+):", round(late_dir, 3), "\n")
cat("  Shift:", ifelse(late_dir < early_dir, "More Conservative", "More Liberal"), "\n\n")

cat("TOP SWING JUSTICES (highest swing index):\n")
top_swing <- justice_stats |>
  filter(tenure_years >= 5) |>
  arrange(desc(swing_index)) |>
  head(5)
for (i in 1:nrow(top_swing)) {
  cat("  ", i, ". ", top_swing$justiceName[i], " (", round(top_swing$swing_index[i], 3), ")\n", sep = "")
}

cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("                    OUTPUT FILES GENERATED                         \n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("\nData files:\n")
cat("  - clean_data/voting_summary.csv\n")
cat("  - clean_data/polarization_metrics.csv\n")
cat("  - clean_data/justice_ideology_scores.csv\n")
cat("  - clean_data/justice_yearly_patterns.csv\n")
cat("\nVisualizations:\n")
cat("  - charts/polarization_trend.png\n")
cat("  - charts/ideological_swing.png\n")
cat("  - charts/five_four_trend.png\n")
cat("  - charts/unanimous_trend.png\n")
cat("  - charts/justice_timeline.png\n")
cat("  - charts/justice_ideology_scatter.png\n")
cat("  - charts/swing_justice_index.png\n")
cat("  - charts/justice_patterns_interactive.html\n")
cat("  - charts/current_court_heatmap.png\n")
cat("  - charts/voting_network.png\n")
cat("  - charts/polarization_dashboard.png\n")
cat("\n═══════════════════════════════════════════════════════════════════\n")
cat("Analysis complete!\n")
