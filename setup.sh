#!/usr/bin/env bash
# Author: Habib Guliyev | 01.08.21 | Provision IaaC
# Main Functions:
function main() {
    provisionClusters
    loadKubeConfig
    deployIngressLB
    deployFluentd
    exposeKibanaUI
    deployWordpressApp
}

function terraformProvision() { # Terraform commands
    terraform init -upgrade
    terraform plan
    terraform apply --auto-approve
}

function provisionClusters() { # Provision EKS Cluster
    terraformProvision
}

function loadKubeConfig() { # Load Kubernetes Config file
    aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
}

function deployWordpressApp() { # Deploy Wordpress Application with MySql DB
    kubectl apply -k ./manifests/
}

function deployFluentd() { # Deploy Fluentd DaemonSets
    kubectl apply -f ./manifests/fluentd.yml
}

function exposeKibanaUI() { # Expose Kibana UI
    kubectl apply -f ./manifests/kibana-svc-ing.yml
}

function deployIngressLB() { # Deploy Ingress LB within AWS NLB
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-0.32.0/deploy/static/provider/aws/deploy.yaml
}

main