#!/bin/bash

set -e

echo "Detecting changes..."

git fetch origin main

CHANGED_FILES=$(git diff --name-only origin/main...HEAD)

echo "$CHANGED_FILES"

MAPPING_FILE="job_mapping.json"
JOBS_TO_RUN=()

while IFS= read -r job; do
  files=$(jq -r --arg job "$job" '.[$job][]' $MAPPING_FILE)

  for changed in $CHANGED_FILES; do
    for f in $files; do
      if [[ "$changed" == "$f" ]]; then
        JOBS_TO_RUN+=("$job")
      fi
    done
  done

done < <(jq -r 'keys[]' $MAPPING_FILE)

JOBS_TO_RUN=($(printf "%s\n" "${JOBS_TO_RUN[@]}" | sort -u))

if [ ${#JOBS_TO_RUN[@]} -eq 0 ]; then
  echo "No changes detected"
  exit 0
fi

echo "Jobs to run:"
printf '%s\n' "${JOBS_TO_RUN[@]}"

databricks bundle deploy

for job in "${JOBS_TO_RUN[@]}"; do
  databricks bundle run "$job"
done