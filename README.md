## Supreme Court Polarization Graphic
This project explores whether collaboration within the Supreme Court is decreasing due to partisanship. By analyzing voting patterns and ideological shifts over time, the project seeks to uncover trends in agreement rates, ideological consistency, and the impact of partisanship on judicial decisions.

---
## Data Source
Data from The Supreme Court Database at Washington University Law
Using the Justice Centered Data, Cases organized by Supreme Court Citation
RDATA via <http://scdb.wustl.edu/data.php>

Harold J. Spaeth, Lee Epstein, Andrew D. Martin, Jeffrey A. Segal, Theodore J. Ruger, and Sara C. Benesh. 2024 Supreme Court Database, Version 2024 Release 01. URL: <http://supremecourtdatabase.org>y


### Key Features
- **Agreement Heatmaps**: Identify trends in justice pair agreement over the years.
- **Interactive Graphs**: Explore ideological swings of individual justices.
- **Network Analysis**: Visualize connections between justices based on voting agreement.

---

## Analysis Questions

1. **Tracking Agreement**: How do justices vote together, and how does their agreement rate change over time?
2. **Mean Agreement Trends**: Is the mean concurring vote total changing across years?
3. **Ideological Swing**: Does the `direction` variable reflect changes in court dynamics?

---

## Key Visualizations

1. **Agreement Heatmaps**:
   - Heatmaps showcasing agreement rates between pairs of justices.

2. **Network Graph**:
   - A network visualization where edge thickness represents agreement frequency.

3. **Ideological Swing Line Graph**:
   - Tracks the ideological direction of justices over their tenure.

4. **Interactive Graphics**:
   - A hover-enabled graphic showing ideological shifts.

---

## Technologies Used

- **R**: Primary analysis and visualization tool.
  - Libraries: `tidyverse`, `ggiraph`, `igraph`, `patchwork`, `pheatmap`, `ggraph`
- **Data Visualization**: `ggplot2`, `superheat`, `pheatmap`
- **Interactive Graphics**: `ggiraph`, `htmlwidgets`
- **Data Processing**: `dplyr`, `tidyr`, `purrr`

---
