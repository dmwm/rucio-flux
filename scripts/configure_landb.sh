#!/bin/sh

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
  echo "Usage: $0 <cluster_type> <start_number> [--dry-run]"
  echo "  <cluster_type>: Type of cluster ('int' or 'prod')."
  echo "  <start_number>: Starting number for the --load-${n}- suffix."
  echo "  [--dry-run]: Optional flag to perform a dry run."
  exit 1
fi

# Assign the inputs to variables
CLUSTER_TYPE="$1"
START_NUMBER="$2"
DRY_RUN=false

# Check for dry-run flag
if [ "$#" -eq 3 ] && [ "$3" = "--dry-run" ]; then
  DRY_RUN=true
fi

# Validate the cluster type input
if [ "$CLUSTER_TYPE" != "int" ] && [ "$CLUSTER_TYPE" != "prod" ]; then
  echo "Error: Cluster type must be 'int' or 'prod'."
  exit 1
fi

# Validate that the start number is a non-negative integer
if ! echo "$START_NUMBER" | grep -qE '^[0-9]+$'; then
  echo "Error: Start number must be a non-negative integer."
  exit 1
fi

# Process labeled nodes for OpenStack landb load balancing
echo "Configuring landb aliases for ingress nodes..."

n="$START_NUMBER"
kubectl get node -l role=ingress -o name | grep -v master | while read -r node; do
  if [ "$DRY_RUN" = true ]; then
    echo "Would unset landb-alias for node ${node##node/}."
  else
    # Unset existing landb aliases
    if openstack server unset --property landb-alias "${node##node/}"; then
      echo "Unset landb-alias for node ${node##node/}."
    else
      echo "Failed to unset landb-alias for node ${node##node/}."
    fi
  fi

  # Determine the suffix based on cluster type
  if [ "$CLUSTER_TYPE" = "int" ]; then
    suffix="-int"
  else
    suffix=""
  fi

  # Define the cnames for the node
  cnames="cms-rucio${suffix}--load-${n}-,cms-rucio-auth${suffix}--load-${n}-,cms-rucio-webui${suffix}--load-${n}-,cms-rucio-eagle${suffix}--load-${n}-,cms-rucio-trace${suffix}--load-${n}-"
  echo "Setting cnames for node ${node##node/}: $cnames"
  
  if [ "$DRY_RUN" = true ]; then
    echo "Would set landb-alias for node ${node##node/} to $cnames."
  else
    # Set the new landb aliases
    if openstack server set --property landb-alias="$cnames" "${node##node/}"; then
      echo "Set landb-alias for node ${node##node/} to $cnames."
    else
      echo "Failed to set landb-alias for node ${node##node/} to $cnames."
    fi
  fi

  n=$((n+1))
done

echo "Landb load balance setup completed."
