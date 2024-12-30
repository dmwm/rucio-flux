#!/bin/sh

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ] && [ "$#" -ne 2 ]; then
  echo "Usage: $0 <number_of_ingress_nodes> [--dry-run]"
  echo "  <number_of_ingress_nodes>: Number of ingress nodes to configure."
  echo "  [--dry-run]: Optional flag to perform a dry run."
  exit 1
fi

# Assign the inputs to variables
NUMBER_INGRESS_NODES="$1"
DRY_RUN=false

# Check for dry-run flag
if [ "$#" -eq 2 ] && [ "$2" = "--dry-run" ]; then
  DRY_RUN=true
fi

# Validate that the number of ingress nodes is a non-negative integer
if ! echo "$NUMBER_INGRESS_NODES" | grep -qE '^[0-9]+$'; then
  echo "Error: Number of ingress nodes must be a non-negative integer."
  exit 1
fi

# Set up ingress by labeling ingress nodes
echo "Labeling nodes as ingress..."

n=0
kubectl get node -o name | grep node | grep -v master | while read -r node; do
  if [ "$n" -ge "$NUMBER_INGRESS_NODES" ]; then
    break
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "Would label node ${node##node/} as ingress."
  else
    if kubectl label --overwrite node "${node##node/}" role=ingress; then
      echo "Labeled node ${node##node/} as ingress."
    else
      echo "Failed to label node ${node##node/} as ingress."
    fi
  fi

  n=$((n+1))
done

echo "Ingress Labels Added."
