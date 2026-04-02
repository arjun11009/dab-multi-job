#!/bin/bash

set -e

echo "Detecting changes..."

# Ensure git is available
if ! command -v git &> /dev/null; then
  echo "ERROR: git is not installed"
  exit 1
fi

# Fetch latest main
git fetch origin main

# ✅ Correct diff (branch vs main)
CHANGED_FILES=$(git diff --name-only origin/main...HEAD | tr -d '\r')

echo "Changed files:"
echo "$CHANGED_FILES"

# If no changes, exit early
if [ -z "$CHANGED_FILES" ]; then
  echo "No changes detected"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_DIR="$SCRIPT_DIR/../resources"

JOBS_TO_RUN=()

echo "Scanning meta files..."

# Loop through all meta files
for meta_file in "$RESOURCE_DIR"/*.meta.json; do

  # ✅ Extract job_name (no jq)
  job_name=$(grep -oP '"job_name"\s*:\s*"\K[^"]+' "$meta_file")

  if [ -z "$job_name" ]; then
    echo "WARNING: Could not extract job_name from $meta_file"
    continue
  fi

  echo "Checking job: $job_name"

  # ✅ Extract paths (no jq)
  paths=$(grep -oP '"paths"\s*:\s*\[[^]]*\]' "$meta_file" \
          | grep -oP '"\K[^"]+')

  # Loop through changed files
  while IFS= read -r changed; do
    changed_clean=$(echo "$changed" | xargs)

    # Loop through paths
    while IFS= read -r path; do
      path_clean=$(echo "$path" | xargs)

      # Match directory prefix
      if [[ "$changed_clean" == "$path_clean"* ]]; then
        echo " Match found: $changed_clean → $job_name"
        JOBS_TO_RUN+=("$job_name")
        break
      fi

    done <<< "$paths"

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

# Run jobs (safe execution)
for job in "${JOBS_TO_RUN[@]}"; do
  echo "Running $job"
  databricks bundle run "$job" || echo "WARNING: Job $job failed"
done

echo ""
echo "Done"