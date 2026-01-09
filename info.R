# Load required libraries
library(rvest)
library(tidyverse)

# URL of the Wikipedia page
url <- "https://en.wikipedia.org/wiki/List_of_justices_of_the_Supreme_Court_of_the_United_States"

# Read the HTML content of the page
page <- read_html(url)

# Extract the first table from the page (modify the index if the table you want is not the first)
tables <- page %>% html_table(fill = TRUE)

# Check the structure of the extracted tables
length(tables) # See how many tables were extracted
# Assuming the first table is the one you want
justices_table <- tables[[2]]

# Ensure unique column names by repairing them during extraction
justices_table <- justices_table %>%
  as_tibble(.name_repair = "unique") # Automatically repairs column names to make them unique

# Check the column names
colnames(justices_table)

# Display the first few rows of the cleaned table
head(justices_table)

# Save as CSV if needed
write.csv(justices_table, "justices_table.csv", row.names = FALSE)
