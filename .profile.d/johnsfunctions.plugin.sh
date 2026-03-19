#!/usr/bin/env bash

### Courtesy function to clobber DR Kubernetes resources, credits to MoJoJuJu
# DR_K8S_CLUSTER, DR_AWS_ACCOUNT_ID, DR_ACCOUNT_REGION, LIVE_AWS_ACCOUNT_ID, LIVE_ACCOUNT_REGION should be set in _personalprefs.plugin.zsh and exported.  Or you can add it as another input parameter to these functions if you prefer.

clobber_dr_kube_resources() {
  # Default values
  DR_ACCOUNT_ID="$DR_AWS_ACCOUNT_ID"
  DR_CLOBBER_DRY_RUN="true"
  DR_CLUSTER_NAME="$DR_K8S_CLUSTER"
  RESOURCE_TYPES=("configmaps" "serviceaccounts" "rolebindings" "secretproviderclass")
  VERBOSE_MODE="false"
  DR_NAMESPACE=""

  # Parse command line arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --account)
        DR_ACCOUNT_ID="$2"
        shift 2
        ;;
      --apply)
        unset DR_CLOBBER_DRY_RUN
        shift 1
        ;;
      --eks-cluster)
        DR_CLUSTER_NAME="$2"
        shift 2
        ;;
      --resources)
        RESOURCE_TYPES=($2)
        shift 2
        ;;
      --namespace)
        DR_NAMESPACE="$2"
        shift 2
        ;;
      --verbose)
        VERBOSE_MODE="true"
        shift 1
        ;;
      *)
        if [ -z "$DR_NAMESPACE" ]; then
          DR_NAMESPACE="$1"
          shift 1
        else
          echo "Unknown parameter: $1"
          return 1
        fi
        ;;
    esac
  done

  # Check required arguments
  if [ -z "$DR_NAMESPACE" ]; then
    echo "Error: --namespace is required."
    echo "Flags: --account | --apply | --eks-cluster | --namespace | --resources | --verbose"
    echo "By default this will only show the resources."
    echo "To apply run with --apply."
    return 1
  fi

  # Double, triple check that we're running this against the DR environment
  if ! CURRENT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --no-cli-pager); then
    echo "No active AWS session. Please run 'assume'"
    return 1
  fi

  if [ "$CURRENT_ACCOUNT_ID" != "$DR_AWS_ACCOUNT_ID" ]; then
    echo "Your AWS session is for account $CURRENT_ACCOUNT_ID, not $DR_ACCOUNT_ID. Exiting."
    return 1
  else
    echo "Confirmed AWS session for account $CURRENT_ACCOUNT_ID. Proceeding."
    # Get the EKS cluster name and control plane of the current context we're connected to
    CURRENT_CLUSTER_NAME=$(kubectl config current-context)
    echo $CURRENT_CLUSTER_NAME
    DR_CLUSTER_CONTROL_PLANE=$(aws eks describe-cluster --name $DR_CLUSTER_NAME --query cluster.endpoint --output text --no-cli-pager)
    echo $DR_CLUSTER_CONTROL_PLANE

    if [[ "$DR_CLUSTER_CONTROL_PLANE" != *"$DR_ACCOUNT_REGION"* ]] || [[ "$CURRENT_CLUSTER_NAME" != *"$DR_ACCOUNT_REGION"* ]]; then
      echo "Current kube context: $CURRENT_CLUSTER_NAME"
      echo "Desired kube context: $DR_CLUSTER_NAME at $DR_CLUSTER_CONTROL_PLANE"
      echo "Exiting."
      return 1
    else
      echo "Confirmed kube context for $CURRENT_CLUSTER_NAME. Proceeding."
      if [ -n "$DR_CLOBBER_DRY_RUN" ]; then
        echo "    !!!! READONLY RUN !!!!"
        echo "TO APPLY RUN WITH --apply FLAG"
        for resource in "${RESOURCE_TYPES[@]}"; do
          echo "Getting resource: $resource"
          if [ "$VERBOSE_MODE" = "true" ]; then
            kubectl get "$resource" -n "$DR_NAMESPACE" -o json | jq 'walk(if type == "string" then gsub("'"$LIVE_AWS_ACCOUNT_ID"'"; "'"$DR_AWS_ACCOUNT_ID"'") | gsub("'"$LIVE_ACCOUNT_REGION"'"; "'"$DR_ACCOUNT_REGION"'") else . end)'
          else
            kubectl get "$resource" -n "$DR_NAMESPACE" -o json | jq 'walk(if type == "string" then gsub("'"$LIVE_AWS_ACCOUNT_ID"'"; "'"$DR_AWS_ACCOUNT_ID"'") | gsub("'"$LIVE_ACCOUNT_REGION"'"; "'"$DR_ACCOUNT_REGION"'") else . end)' 2>&1 | grep -v "Warning:"
          fi
        done
      else
        kubectl_error=0
        for resource in "${RESOURCE_TYPES[@]}"; do
          echo "Getting resource: $resource"
          if [ "$VERBOSE_MODE" = "true" ]; then
            kubectl get "$resource" -n "$DR_NAMESPACE" -o json | jq 'walk(if type == "string" then gsub("'"$LIVE_AWS_ACCOUNT_ID"'"; "'"$DR_AWS_ACCOUNT_ID"'") | gsub("'"$LIVE_ACCOUNT_REGION"'"; "'"$DR_ACCOUNT_REGION"'") else . end)' | kubectl apply -f - || kubectl_error=1
          else
            kubectl_output=$(kubectl get "$resource" -n "$DR_NAMESPACE" -o json | jq 'walk(if type == "string" then gsub("'"$LIVE_AWS_ACCOUNT_ID"'"; "'"$DR_AWS_ACCOUNT_ID"'") | gsub("'"$LIVE_ACCOUNT_REGION"'"; "'"$DR_ACCOUNT_REGION"'") else . end)' | kubectl apply -f - 2>&1)
            echo "$kubectl_output" | grep -v "Warning:"
            kubectl_exit_code=${PIPESTATUS[1]}
            if [ "$kubectl_exit_code" != "0" ]; then
              kubectl_error=1
            fi
          fi
        done
        if [ $kubectl_error -eq 0 ]; then
          kubectl rollout restart deployment --namespace="$DR_NAMESPACE"
        else
          echo "Errors occurred during kubectl commands. Skipping rollout restart."
        fi
      fi
    fi
  fi
  return 0
}
