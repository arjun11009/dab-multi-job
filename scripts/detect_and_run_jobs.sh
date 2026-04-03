#!/bin/bash

set -e

echo "=============================="
echo " Detecting changes..."
echo "=============================="

# Validate git
if ! command -v git &> /dev/null; then
  echo "ERROR: git is not installed"
  exit 1
fi

# Validate jq (enterprise requirement)
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is not installed (required for JSON parsing)"
  exit 1
fi

# Fetch latest main
echo "Fetching latest main..."
git fetch origin main

# Detect all changes from main (MR-safe)
CHANGED_FILES=$(git diff --name-only origin/main...HEAD | tr -d '\r')

echo ""
echo "Changed files:"
echo "------------------------------"
echo "$CHANGED_FILES"

# Exit if no changes
if [ -z "$CHANGED_FILES" ]; then
  echo "No changes detected"
  exit 0
fi

# Resolve directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_DIR="$SCRIPT_DIR/../resources"

if [ ! -d "$RESOURCE_DIR" ]; then
  echo "ERROR: resources directory not found at $RESOURCE_DIR"
  exit 1
fi

JOBS_TO_RUN=()

echo ""
echo "=============================="
echo " Scanning meta files..."
echo "=============================="

# Loop through meta files
for meta_file in "$RESOURCE_DIR"/*.meta.json; do

  echo ""
  echo "Processing meta file: $meta_file"

  # Extract job name
  job_name=$(jq -r '.job_name' "$meta_file")

  if [ -z "$job_name" ] || [ "$job_name" == "null" ]; then
    echo "WARNING: Invalid job_name in $meta_file"
    continue
  fi

  echo "Checking job: $job_name"

  # Extract paths
  paths=$(jq -r '.paths[]' "$meta_file")

  job_matched=false

  # Loop through changed files
  while IFS= read -r changed; do
    changed_clean=$(echo "$changed" | sed 's|^\./||' | xargs)

    # Loop through paths
    while IFS= read -r path; do
      path_clean=$(echo "$path" | sed 's|^\./||' | xargs)

      # Skip empty
      if [[ -z "$path_clean" ]]; then
        continue
      fi

      # DEBUG (can comment later)
      echo "Comparing:"
      echo "  Changed: [$changed_clean]"
      echo "  Path:    [$path_clean]"

      # Directory match
      if [[ "$path_clean" == */ ]]; then
        if [[ "$changed_clean" == "$path_clean"* ]]; then
          echo " Match found: $changed_clean → $job_name"
          JOBS_TO_RUN+=("$job_name")
          job_matched=true
          break
        fi
      else
        # File OR prefix match
        if [[ "$changed_clean" == "$path_clean" ]] || [[ "$changed_clean" == "$path_clean"* ]]; then
          echo " Match found: $changed_clean → $job_name"
          JOBS_TO_RUN+=("$job_name")
          job_matched=true
          break
        fi
      fi

    done <<< "$paths"

    # Break outer loop if matched
    if [ "$job_matched" = true ]; then
      break
    fi

  done <<< "$CHANGED_FILES"

done

# Remove duplicates
JOBS_TO_RUN=($(printf "%s\n" "${JOBS_TO_RUN[@]}" | sort -u))

echo ""
echo "=============================="
echo " Job Selection Summary"
echo "=============================="

# Fallback (enterprise safety)
if [ ${#JOBS_TO_RUN[@]} -eq 0 ]; then
  echo "No impacted jobs detected"

  # Optional fallback (recommended in enterprise)
  echo "Fallback: Running ALL jobs"

  JOBS_TO_RUN=()

  for meta_file in "$RESOURCE_DIR"/*.meta.json; do
    job_name=$(jq -r '.job_name' "$meta_file")
    JOBS_TO_RUN+=("$job_name")
  done

  # Remove duplicates again
  JOBS_TO_RUN=($(printf "%s\n" "${JOBS_TO_RUN[@]}" | sort -u))
fi

echo ""
echo "Jobs to run:"
echo "------------------------------"
printf '%s\n' "${JOBS_TO_RUN[@]}"

echo ""
echo "=============================="
echo " Deploying bundle..."
echo "=============================="

databricks bundle deploy

echo ""
echo "=============================="
echo " Running jobs..."
echo "=============================="

# Execute jobs
for job in "${JOBS_TO_RUN[@]}"; do
  echo ""
  echo " Running job: $job"
  databricks bundle run "$job" || echo " WARNING: Job $job failed"
done

echo ""
echo "=============================="
echo " Done"
echo "=============================="