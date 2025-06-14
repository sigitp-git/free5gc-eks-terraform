resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# SRIOV Device Plugin ConfigMap
resource "kubernetes_config_map" "sriovdp_config" {
  metadata {
    name      = "sriovdp-config"
    namespace = "kube-system"
  }

  data = {
    "config.json" = jsonencode({
      resourceList = [
        {
          resourceName   = "bmn-mlx-sriov-pf1"
          resourcePrefix = "amazon.com"
          selectors = {
            vendors     = ["15b3"]
            devices     = ["101e"]
            drivers     = ["mlx5_core"]
            rootDevices = ["0000:05:00.0"]
          }
        },
        {
          resourceName   = "bmn-mlx-sriov-pf2"
          resourcePrefix = "amazon.com"
          selectors = {
            vendors     = ["15b3"]
            devices     = ["101e"]
            drivers     = ["mlx5_core"]
            rootDevices = ["0000:05:00.1"]
          }
        },
        {
          resourceName   = "bmn-mlx-sriov-pf3"
          resourcePrefix = "amazon.com"
          selectors = {
            vendors     = ["15b3"]
            devices     = ["101e"]
            drivers     = ["mlx5_core"]
            rootDevices = ["0001:05:00.0"]
          }
        },
        {
          resourceName   = "bmn-mlx-sriov-pf4"
          resourcePrefix = "amazon.com"
          selectors = {
            vendors     = ["15b3"]
            devices     = ["101e"]
            drivers     = ["mlx5_core"]
            rootDevices = ["0001:05:00.1"]
          }
        }
      ]
    })
  }
}

# SRIOV Device Plugin ServiceAccount
resource "kubernetes_service_account" "sriov_device_plugin" {
  metadata {
    name      = "sriov-device-plugin"
    namespace = "kube-system"
  }
}

# Multus ServiceAccount
resource "kubernetes_service_account" "multus" {
  metadata {
    name      = "multus"
    namespace = "kube-system"
  }
}

# Multus ClusterRole
resource "kubernetes_cluster_role" "multus" {
  metadata {
    name = "multus"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/status"]
    verbs      = ["get", "update"]
  }

  rule {
    api_groups = ["k8s.cni.cncf.io"]
    resources  = ["network-attachment-definitions"]
    verbs      = ["get", "list", "watch"]
  }
}

# Multus ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "multus" {
  metadata {
    name = "multus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "multus"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "multus"
    namespace = "kube-system"
  }
}

# Multus ConfigMap
resource "kubernetes_config_map" "multus_daemon_config" {
  metadata {
    name      = "multus-daemon-config"
    namespace = "kube-system"
  }

  data = {
    "daemon-config.json" = jsonencode({
      cniVersion = "0.3.1"
      name       = "multus-cni-network"
      type       = "multus"
      capabilities = {
        portMappings = true
      }
      delegates = [
        {
          cniVersion = "0.3.1"
          name       = "aws-cni"
          plugins = [
            {
              name = "aws-cni"
            },
            {
              type = "portmap"
              capabilities = {
                portMappings = true
              }
              snat = true
            }
          ]
        }
      ]
      kubeconfig = "/etc/cni/net.d/multus.d/multus.kubeconfig"
    })
  }
}

# Whereabouts ServiceAccount
resource "kubernetes_service_account" "whereabouts" {
  metadata {
    name      = "whereabouts"
    namespace = "kube-system"
  }
}

# Whereabouts ClusterRole
resource "kubernetes_cluster_role" "whereabouts" {
  metadata {
    name = "whereabouts-cni"
  }

  rule {
    api_groups = ["k8s.cni.cncf.io"]
    resources  = ["ippools", "overlappingrangeipreservations"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# Whereabouts ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "whereabouts" {
  metadata {
    name = "whereabouts"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "whereabouts-cni"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "whereabouts"
    namespace = "kube-system"
  }
}

# Whereabouts ConfigMap
resource "kubernetes_config_map" "whereabouts_config" {
  metadata {
    name      = "whereabouts-config"
    namespace = "kube-system"
  }

  data = {
    "whereabouts.conf" = jsonencode({
      datastore = "kubernetes"
      kubernetes = {
        kubeconfig = ""
      }
    })
  }
}

# Label nodes for SRIOV capability
resource "null_resource" "label_nodes_sriov" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region} && kubectl label node --all feature.node.kubernetes.io/network-sriov.capable=true"
  }
}
