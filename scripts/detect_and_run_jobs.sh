#!/bin/bash

set -e

echo "Detecting changes..."

git fetch origin main

# Use commit-level diff (IMPORTANT)
CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD | tr -d '\r')

echo "Changed files:"
echo "$CHANGED_FILES"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_DIR="$SCRIPT_DIR/../resources"

JOBS_TO_RUN=()

# Loop through all meta files
for meta_file in "$RESOURCE_DIR"/*.meta.json; do

  job_name=$(jq -r '.job_name' "$meta_file" | tr -d '\r')

  echo "Checking job: $job_name"

  paths=$(jq -r '.paths[]' "$meta_file" | tr -d '\r')

  while IFS= read -r changed; do
    changed_clean=$(echo "$changed" | xargs)

    while IFS= read -r path; do
      path_clean=$(echo "$path" | xargs)

      # Match directory prefix
      if [[ "$changed_clean" == "$path_clean"* ]]; then
        echo " Match found: $changed_clean → $job_name"
        JOBS_TO_RUN+=("$job_name")
      fi

    done <<< "$paths"

  done <<< "$CHANGED_FILES"

done

# Remove duplicates
JOBS_TO_RUN=($(printf "%s\n" "${JOBS_TO_RUN[@]}" | sort -u))

if [ ${#JOBS_TO_RUN[@]} -eq 0 ]; then
  echo "No impacted jobs"
  exit 0
fi

echo "Jobs to run:"
printf '%s\n' "${JOBS_TO_RUN[@]}"

echo "Deploying bundle..."
databricks bundle deploy

echo "Running jobs..."

for job in "${JOBS_TO_RUN[@]}"; do
  echo "Running $job"
  databricks bundle run "$job"
done

echo "Done"