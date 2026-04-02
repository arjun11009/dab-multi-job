#!/bin/bash

set -e

echo "Detecting changes..."

# Check git 
if ! command -v git &> /dev/null; then
  echo "ERROR: git is not installed"
  exit 1
fi

# Fetch latest main
git fetch origin main

# Detect changes AFTER merge
CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD | tr -d '\r')

echo "Changed files:"
echo "$CHANGED_FILES"

# Exit if no changes
if [ -z "$CHANGED_FILES" ]; then
  echo "No changes detected"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_DIR="$SCRIPT_DIR/../resources"

JOBS_TO_RUN=()

echo "Scanning meta files..."

# Loop through meta files
for meta_file in "$RESOURCE_DIR"/*.meta.json; do

  # Extract job name
  job_name=$(grep -oP '"job_name"\s*:\s*"\K[^"]+' "$meta_file")

  if [ -z "$job_name" ]; then
    echo "WARNING: Could not extract job_name from $meta_file"
    continue
  fi

  echo "Checking job: $job_name"

  # path extraction
  paths=$(grep -oP '"paths"\s*:\s*\[[^]]*\]' "$meta_file" \
        | sed 's/.*\[//' \
        | sed 's/\]//' \
        | tr ',' '\n' \
        | sed 's/"//g' \
        | sed 's/^ *//;s/ *$//')

  job_matched=false

  # Loop through changed files
  while IFS= read -r changed; do
    changed_clean=$(echo "$changed" | xargs)

    # Loop through paths
    while IFS= read -r path; do
      path_clean=$(echo "$path" | xargs)

      # Safe prefix match
      if [[ -n "$path_clean" && "$changed_clean" == "$path_clean"* ]]; then
        echo " Match found: $changed_clean → $job_name"
        JOBS_TO_RUN+=("$job_name")
        job_matched=true
        break
      fi

    done <<< "$paths"

    #Break outer loop once job matched
    if [ "$job_matched" = true ]; then
      break
    fi

  done <<< "$CHANGED_FILES"

done

# Remove duplicates
JOBS_TO_RUN=($(printf "%s\n" "${JOBS_TO_RUN[@]}" | sort -u))

# If no jobs impacted
if [ ${#JOBS_TO_RUN[@]} -eq 0 ]; then
  echo "No impacted jobs"
  exit 0
fi

echo ""
echo "Jobs to run:"
printf '%s\n' "${JOBS_TO_RUN[@]}"

echo ""
echo "Deploying bundle..."
databricks bundle deploy

echo ""
echo "Running jobs..."

# Run jobs 
for job in "${JOBS_TO_RUN[@]}"; do
  echo "Running $job"
  databricks bundle run "$job" || echo "WARNING: Job $job failed"
done

echo ""
echo "Done"