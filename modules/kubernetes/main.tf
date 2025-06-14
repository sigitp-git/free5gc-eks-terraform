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

# SRIOV Device Plugin DaemonSet
resource "kubernetes_manifest" "sriov_device_plugin_daemonset" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    metadata = {
      name      = "kube-sriov-device-plugin-amd64"
      namespace = "kube-system"
      labels = {
        tier = "node"
        app  = "sriov-device-plugin"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          name = "sriov-device-plugin"
        }
      }
      template = {
        metadata = {
          labels = {
            name = "sriov-device-plugin"
            tier = "node"
            app  = "sriov-device-plugin"
          }
        }
        spec = {
          hostNetwork = true
          nodeSelector = {
            "kubernetes.io/arch" = "amd64"
            "feature.node.kubernetes.io/network-sriov.capable" = "true"
          }
          tolerations = [
            {
              key      = "node-role.kubernetes.io/master"
              operator = "Exists"
              effect   = "NoSchedule"
            }
          ]
          serviceAccountName = "sriov-device-plugin"
          containers = [
            {
              name  = "kube-sriovdp"
              image = "nfvpe/sriov-device-plugin:v3.5"
              args = [
                "-log-level=10",
                "-log-file=sriovdp.log"
              ]
              securityContext = {
                privileged = true
              }
              volumeMounts = [
                {
                  name      = "devicesock"
                  mountPath = "/var/lib/kubelet/device-plugins"
                  readOnly  = false
                },
                {
                  name      = "log"
                  mountPath = "/var/log"
                },
                {
                  name      = "config-volume"
                  mountPath = "/etc/pcidp"
                },
                {
                  name      = "device-info"
                  mountPath = "/var/run/k8s.cni.cncf.io/devinfo/dp"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "devicesock"
              hostPath = {
                path = "/var/lib/kubelet/device-plugins"
              }
            },
            {
              name = "log"
              hostPath = {
                path = "/var/log"
              }
            },
            {
              name = "config-volume"
              configMap = {
                name = "sriovdp-config"
              }
            },
            {
              name = "device-info"
              hostPath = {
                path = "/var/run/k8s.cni.cncf.io/devinfo/dp"
                type = "DirectoryOrCreate"
              }
            }
          ]
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.sriovdp_config, kubernetes_service_account.sriov_device_plugin]
}

# SRIOV Device Plugin ServiceAccount
resource "kubernetes_service_account" "sriov_device_plugin" {
  metadata {
    name      = "sriov-device-plugin"
    namespace = "kube-system"
  }
}

# Multus DaemonSet
resource "kubernetes_manifest" "multus_daemonset" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    metadata = {
      name      = "kube-multus-ds"
      namespace = "kube-system"
      labels = {
        tier = "node"
        app  = "multus"
        name = "multus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          name = "multus"
        }
      }
      template = {
        metadata = {
          labels = {
            tier = "node"
            app  = "multus"
            name = "multus"
          }
        }
        spec = {
          hostNetwork = true
          nodeSelector = {
            "kubernetes.io/arch" = "amd64"
          }
          tolerations = [
            {
              operator = "Exists"
              effect   = "NoSchedule"
            }
          ]
          serviceAccountName = "multus"
          containers = [
            {
              name  = "kube-multus"
              image = "nfvpe/multus:v3.9.3"
              command = [
                "/entrypoint.sh"
              ]
              args = [
                "--multus-conf-file=auto",
                "--cni-version=0.3.1"
              ]
              resources = {
                requests = {
                  cpu    = "100m"
                  memory = "50Mi"
                }
                limits = {
                  cpu    = "100m"
                  memory = "50Mi"
                }
              }
              securityContext = {
                privileged = true
              }
              volumeMounts = [
                {
                  name      = "cni"
                  mountPath = "/host/etc/cni/net.d"
                },
                {
                  name      = "cnibin"
                  mountPath = "/host/opt/cni/bin"
                },
                {
                  name      = "multus-cfg"
                  mountPath = "/tmp/multus-conf"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "cni"
              hostPath = {
                path = "/etc/cni/net.d"
              }
            },
            {
              name = "cnibin"
              hostPath = {
                path = "/opt/cni/bin"
              }
            },
            {
              name = "multus-cfg"
              configMap = {
                name = "multus-daemon-config"
                items = [
                  {
                    key  = "daemon-config.json"
                    path = "daemon-config.json"
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.multus_daemon_config, kubernetes_service_account.multus]
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

# SRIOV CNI DaemonSet
resource "kubernetes_manifest" "sriov_cni_daemonset" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    metadata = {
      name      = "kube-sriov-cni-ds"
      namespace = "kube-system"
      labels = {
        tier = "node"
        app  = "sriov-cni"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          name = "sriov-cni"
        }
      }
      template = {
        metadata = {
          labels = {
            name = "sriov-cni"
            tier = "node"
            app  = "sriov-cni"
          }
        }
        spec = {
          hostNetwork = true
          nodeSelector = {
            "kubernetes.io/arch" = "amd64"
          }
          tolerations = [
            {
              key      = "node-role.kubernetes.io/master"
              operator = "Exists"
              effect   = "NoSchedule"
            }
          ]
          containers = [
            {
              name  = "kube-sriov-cni"
              image = "nfvpe/sriov-cni:v2.6"
              securityContext = {
                privileged = true
              }
              volumeMounts = [
                {
                  name      = "cnibin"
                  mountPath = "/host/opt/cni/bin"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "cnibin"
              hostPath = {
                path = "/opt/cni/bin"
              }
            }
          ]
        }
      }
    }
  }
}

# Whereabouts IPAM
resource "kubernetes_manifest" "whereabouts_daemonset" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    metadata = {
      name      = "whereabouts"
      namespace = "kube-system"
    }
    spec = {
      selector = {
        matchLabels = {
          name = "whereabouts"
        }
      }
      template = {
        metadata = {
          labels = {
            name = "whereabouts"
          }
        }
        spec = {
          hostNetwork = true
          serviceAccountName = "whereabouts"
          containers = [
            {
              name  = "whereabouts"
              image = "ghcr.io/k8snetworkplumbingwg/whereabouts:v0.6.1"
              env = [
                {
                  name  = "WHEREABOUTS_NAMESPACE"
                  value = "kube-system"
                },
                {
                  name  = "WHEREABOUTS_DISABLE_STRICT_CONFIG"
                  value = "true"
                },
                {
                  name  = "WHEREABOUTS_RECONCILER_ENABLED"
                  value = "true"
                }
              ]
              volumeMounts = [
                {
                  name      = "cni-bin"
                  mountPath = "/host/opt/cni/bin"
                },
                {
                  name      = "cni-net-dir"
                  mountPath = "/host/etc/cni/net.d"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "cni-bin"
              hostPath = {
                path = "/opt/cni/bin"
              }
            },
            {
              name = "cni-net-dir"
              hostPath = {
                path = "/etc/cni/net.d"
              }
            }
          ]
        }
      }
    }
  }

  depends_on = [kubernetes_service_account.whereabouts]
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

# Network Attachment Definition for N3 VLAN 1001
resource "kubernetes_manifest" "nad_n3_1001" {
  manifest = {
    apiVersion = "k8s.cni.cncf.io/v1"
    kind       = "NetworkAttachmentDefinition"
    metadata = {
      name = "n3-1001-numa1p0-pf3"
      annotations = {
        "k8s.v1.cni.cncf.io/resourceName" = "amazon.com/bmn-mlx-sriov-pf3"
      }
    }
    spec = {
      config = jsonencode({
        type       = "sriov"
        cniVersion = "0.3.1"
        name       = "sriov-network"
        vlan       = 1001
        logLevel   = "debug"
        ipam = {
          type   = "whereabouts"
          range  = "169.30.1.0/24"
          exclude = [
            "169.30.1.1/32",
            "169.30.1.254/32"
          ]
        }
      })
    }
  }

  depends_on = [kubernetes_manifest.whereabouts_daemonset]
}

# Network Attachment Definition for N3 VLAN 1002
resource "kubernetes_manifest" "nad_n3_1002" {
  manifest = {
    apiVersion = "k8s.cni.cncf.io/v1"
    kind       = "NetworkAttachmentDefinition"
    metadata = {
      name = "n3-1002-numa1p1-pf4"
      annotations = {
        "k8s.v1.cni.cncf.io/resourceName" = "amazon.com/bmn-mlx-sriov-pf4"
      }
    }
    spec = {
      config = jsonencode({
        type       = "sriov"
        cniVersion = "0.3.1"
        name       = "sriov-network"
        vlan       = 1002
        logLevel   = "debug"
        ipam = {
          type   = "whereabouts"
          range  = "169.30.2.0/24"
          exclude = [
            "169.30.2.1/32",
            "169.30.2.254/32"
          ]
        }
      })
    }
  }

  depends_on = [kubernetes_manifest.whereabouts_daemonset]
}

# CRD for Whereabouts IPPools
resource "kubernetes_manifest" "crd_ippools" {
  manifest = {
    apiVersion = "apiextensions.k8s.io/v1"
    kind       = "CustomResourceDefinition"
    metadata = {
      name = "ippools.whereabouts.cni.cncf.io"
    }
    spec = {
      group = "whereabouts.cni.cncf.io"
      names = {
        kind     = "IPPool"
        plural   = "ippools"
        singular = "ippool"
      }
      scope = "Cluster"
      versions = [
        {
          name    = "v1alpha1"
          served  = true
          storage = true
          schema = {
            openAPIV3Schema = {
              type = "object"
              properties = {
                spec = {
                  type = "object"
                  properties = {
                    range = {
                      type = "string"
                    }
                    allocations = {
                      type = "object"
                      additionalProperties = {
                        type = "object"
                        properties = {
                          id = {
                            type = "string"
                          }
                          podref = {
                            type = "string"
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      ]
    }
  }
}

# CRD for Whereabouts OverlappingRangeIPReservations
resource "kubernetes_manifest" "crd_overlappingrangeipreservations" {
  manifest = {
    apiVersion = "apiextensions.k8s.io/v1"
    kind       = "CustomResourceDefinition"
    metadata = {
      name = "overlappingrangeipreservations.whereabouts.cni.cncf.io"
    }
    spec = {
      group = "whereabouts.cni.cncf.io"
      names = {
        kind     = "OverlappingRangeIPReservation"
        plural   = "overlappingrangeipreservations"
        singular = "overlappingrangeipreservation"
      }
      scope = "Cluster"
      versions = [
        {
          name    = "v1alpha1"
          served  = true
          storage = true
          schema = {
            openAPIV3Schema = {
              type = "object"
              properties = {
                spec = {
                  type = "object"
                  properties = {
                    containerid = {
                      type = "string"
                    }
                    podref = {
                      type = "string"
                    }
                    address = {
                      type = "string"
                    }
                  }
                }
              }
            }
          }
        }
      ]
    }
  }
}

# Label nodes for SRIOV capability
resource "null_resource" "label_nodes_sriov" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region} && kubectl label node --all feature.node.kubernetes.io/network-sriov.capable=true"
  }

  depends_on = [kubernetes_manifest.sriov_device_plugin_daemonset]
}
