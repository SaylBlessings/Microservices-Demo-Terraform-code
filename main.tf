//Online Boutique on GCP Infrastructure Provisioning

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "kubernetes" {
  host                   = module.gke.endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.gke.endpoint
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

data "google_client_config" "default" {}
 

locals {
  microservices = [
    "adservice", "cartservice", "checkoutservice", "currencyservice",
    "emailservice", "frontend", "loadgenerator", "paymentservice",
    "productcatalogservice", "shippingservice"
  ]
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "6.0.0"
  project_id   = var.project_id
  network_name = "boutique-vpc"
  routing_mode = "REGIONAL"
  subnets = [{
    subnet_name         = "gke-subnet"
    subnet_ip           = "10.0.0.0/16"
    region              = var.region
    secondary_ip_range = {
      pods     = "10.1.0.0/16"
      services = "10.2.0.0/16"
    }
  }]
  firewall_rules = [{
    name        = "allow-internal"
    direction   = "INGRESS"
    priority    = 1000
    ranges      = ["10.0.0.0/8"]
    allow       = [{ protocol = "all" }]
    target_tags = ["gke-cluster"]
  }]
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "30.2.0"
  project_id = var.project_id
  name       = "online-boutique"
  region     = var.region
  network    = module.vpc.network_name
  subnetwork = module.vpc.subnets_names[0]
  ip_range_pods     = "pods"
  ip_range_services = "services"
  enable_private_nodes        = true
  enable_ip_aliases           = true
  enable_shielded_nodes       = true
  enable_binary_authorization = true
  enable_intranode_visibility = true
  network_policy              = true
  release_channel             = "STABLE"
  remove_default_node_pool    = true
  initial_node_count          = 1
  node_pools = [{
    name            = "primary-pool"
    machine_type    = "e2-standard-4"
    min_count       = 3
    max_count       = 10
    disk_size_gb    = 100
    auto_upgrade    = true
    auto_repair     = true
    autoscaling     = true
    service_account = module.gke_sa.email
  }]
  master_authorized_networks_config = [{
    cidr_block   = var.admin_cidr
    display_name = "admin"
  }]
}

module "gke_sa" {
  source     = "terraform-google-modules/service-accounts/google"
  version    = "4.1.2"
  project_id = var.project_id
  names      = ["gke-node"]
  roles = [
    { sa_name = "gke-node", role = "roles/logging.logWriter" },
    { sa_name = "gke-node", role = "roles/monitoring.metricWriter" },
    { sa_name = "gke-node", role = "roles/container.nodeServiceAccount" }
  ]
}

resource "kubernetes_namespace" "microservices" {
  for_each = toset(local.microservices)
  metadata {
    name = each.key
  }
}

resource "helm_release" "istio" {
  name       = "istio"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istio"
  version    = "1.20.0"
  namespace  = "istio-system"
  create_namespace = true
  values = [file("manifests/istio-values.yaml")]
}

resource "kubernetes_manifest" "istio_addons" {
  manifest = yamldecode(file("manifests/istio-addons.yaml"))
}

resource "kubernetes_manifest" "istio_gateway" {
  manifest = yamldecode(file("manifests/istio-gateway.yaml"))
}

resource "kubernetes_manifest" "istio_virtualservices" {
  manifest = yamldecode(file("manifests/istio-virtualservices.yaml"))
}

resource "kubernetes_horizontal_pod_autoscaler" "hpa" {
  for_each = toset(local.microservices)
  metadata {
    name      = "${each.key}-hpa"
    namespace = each.key
  }
  spec {
    max_replicas = 10
    min_replicas = 2
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = each.key
    }
    target_cpu_utilization_percentage = 75
  }
}

resource "kubernetes_manifest" "vpa" {
  manifest = yamldecode(file("manifests/vpa.yaml"))
}

resource "kubernetes_manifest" "network_policies" {
  manifest = yamldecode(file("manifests/network-policies.yaml"))
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.2"
  namespace  = "argocd"
  create_namespace = true
  values = [file("manifests/argocd-values.yaml")]
}

resource "google_compute_backend_service" "backend" {
  name            = "boutique-backend"
  protocol        = "HTTP"
  enable_cdn      = true
  security_policy = google_compute_security_policy.armor_policy.id
  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
  }
}

resource "google_compute_security_policy" "armor_policy" {
  name = "boutique-armor"
  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

resource "google_iap_web_backend_service_iam_binding" "iap_binding" {
  project              = var.project_id
  role                 = "roles/iap.httpsResourceAccessor"
  members              = ["user:${var.iap_user_email}"]
  web_backend_service  = google_compute_backend_service.backend.name
}

resource "google_cloudbuild_trigger" "ci_cd" {
  name = "deploy-online-boutique"
  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "main"
    }
  }
  build {
    steps {
      name = "gcr.io/cloud-builders/kubectl"
      args = ["apply", "-f", "https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml"]
    }
  }
}