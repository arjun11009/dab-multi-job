#!/bin/bash

set -e

echo "🔍 Detecting changes..."

# Fetch latest main
git fetch origin main

# Get changed files (sanitize CRLF)
CHANGED_FILES=$(git diff --name-only origin/main...HEAD | tr -d '\r')

echo "📂 Changed files:"
echo "$CHANGED_FILES"

# Resolve mapping file path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAPPING_FILE="$SCRIPT_DIR/../job_mapping.json"

echo "📄 Using mapping file: $MAPPING_FILE"

# Validate JSON
jq . "$MAPPING_FILE" > /dev/null

JOBS_TO_RUN=()

# Loop through jobs (sanitize CRLF)
while IFS= read -r job; do
  job_clean=$(echo "$job" | tr -d '\r' | xargs)
  echo "🔎 Checking job: $job_clean"

  # Get mapped files (sanitize CRLF)
  files=$(jq -r --arg job "$job_clean" '.[$job] // [] | .[]' "$MAPPING_FILE" | tr -d '\r')

  # Loop changed files safely
  while IFS= read -r changed; do
    changed_clean=$(echo "$changed" | tr -d '\r' | xargs)

    # Loop mapped files
    while IFS= read -r f; do
      f_clean=$(echo "$f" | tr -d '\r' | xargs)

      echo "Comparing [$changed_clean] vs [$f_clean]"

      if [[ "$changed_clean" == "$f_clean" ]]; then
        echo "✅ Match found: $changed_clean → $job_clean"
        JOBS_TO_RUN+=("$job_clean")
      fi

    done <<< "$files"

  done <<< "$CHANGED_FILES"

done < <(jq -r 'keys[]' "$MAPPING_FILE" | tr -d '\r')

# Remove duplicates
JOBS_TO_RUN=($(printf "%s\n" "${JOBS_TO_RUN[@]}" | sort -u))

# If no jobs impacted
if [ ${#JOBS_TO_RUN[@]} -eq 0 ]; then
  echo "❌ No impacted jobs"
  exit 0
fi

echo "🚀 Jobs to run:"
printf '%s\n' "${JOBS_TO_RUN[@]}"

# Deploy bundle
echo "📦 Deploying bundle..."
databricks bundle deploy

# Run impacted jobs
echo "🏃 Running jobs..."
for job in "${JOBS_TO_RUN[@]}"; do
  echo "▶ Running $job"
  databricks bundle run "$job"
done

echo "✅ Done"