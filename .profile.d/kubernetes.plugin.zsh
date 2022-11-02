# Custom plugin for zsh
#
# Kubernetes aliases
#
# Author: Ryan Peay
# Date:   Mon Aug 8 21:28:29 MST 2022
#

# Init Kubernetes configuration
KUBECONFIG=$HOME/.kube/config
KUBE_CONFIG_PATH=$KUBECONFIG
export KUBECONFIG KUBE_CONFIG_PATH

# Kube contexts
alias kubeprod="kubectx $SHARED_K8S_PRODUCTION_APP_CLUSTER ; "
alias kubestage="kubectx $SHARED_K8S_STAGING_APP_CLUSTER ; "
