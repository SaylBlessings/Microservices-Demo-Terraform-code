# Online Boutique on Google Cloud using Terraform

This repository contains a **production-grade Terraform configuration** for deploying the [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) — a cloud-native microservices demo application — on **Google Cloud Platform (GCP)**.

---

## Architecture Overview

This infrastructure provisions:

- **Google Kubernetes Engine (GKE)** private cluster with IP aliasing
- **Separate Kubernetes namespaces** for each of the 10 microservices
- **Istio service mesh** for traffic routing, observability, and ingress control
- **Horizontal Pod Autoscaler (HPA)** and support for **Vertical Pod Autoscaler (VPA)**
- **Cloud Load Balancer with Cloud CDN** for frontend caching
- **Cloud Armor WAF** for security policy enforcement
- **Identity-Aware Proxy (IAP)** for authenticated access control
- **GitOps deployment with ArgoCD**
- **CI/CD pipeline using Cloud Build** integrated with GitHub
- **Strict network policies** for zero-trust enforcement
- **Least-privileged IAM** for all components

---

## Infrastructure Highlights

### Networking

- **CIDR Segmentation**:
  - Nodes: `10.0.0.0/16`
  - Pods: `10.1.0.0/16`
  - Services: `10.2.0.0/16`
- Fully configured **VPC-native** GKE with secondary IP ranges
- Internal-only traffic allowed via GCP firewall rules

### Security Best Practices

- **Private GKE cluster**
- **Binary Authorization**, **Shielded Nodes**, **Network Policy**
- **Cloud Armor** integrated with backend service
- **IAP** with scoped user email access
- **IAM roles** granted to service accounts only for required scopes

### Scalability and Observability

- **HPA** configured per microservice
- Support for **VPA** via manifest
- **Istio Addons** for Prometheus, Grafana, and Kiali
- CDN and autoscaling backend

### GitOps and DevOps Integration

- **Cloud Build** triggers deployment on GitHub push
- **ArgoCD** enables declarative, Git-based delivery
- Microservices are deployed across **isolated namespaces**

---

---

## Collaboration Ready

This infrastructure is **team-friendly**:

- Uses **separate namespaces** to isolate each service and its access policies
- Declarative IaC allows **peer-reviewed Git-based workflows**
- Easily supports **multiple environments** (staging, prod) via Terraform workspaces or CI pipelines
- **Minimal privilege IAM roles** help reduce accidental damage across teams

---

## Requirements

- [Terraform](https://www.terraform.io/)
- [Google Cloud CLI](https://cloud.google.com/sdk)
- A GCP project with billing enabled
- GitHub repository for Cloud Build integration

---

## Usage

1. Clone this repository and update `terraform.tfvars` with your values.

2. Initialize Terraform:
```bash
terraform init
terraform plan
terraform apply
