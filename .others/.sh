#!/bin/bash

# Input files
jira_file="jira_numbers.txt"
pack_file="pack_list.txt"

# Temporary file to store results
temp_file=$(mktemp)

# Loop through each JIRA number
while read -r jira; do
  # Count the number of packs associated with the current JIRA number
  pack_count=$(grep -c "$jira" "$pack_file")
  
  # If JIRA number exists in pack file, print JIRA and the count of packs
  if [[ $pack_count -gt 0 ]]; then
    echo "$jira: $pack_count packs" >> "$temp_file"
  else
    echo "$jira: No packs found" >> "$temp_file"
  fi
done < "$jira_file"

# Display the results
cat "$temp_file"

# Clean up the temporary file
rm "$temp_file"