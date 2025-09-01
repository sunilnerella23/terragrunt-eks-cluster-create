# Include the root `terragrunt.hcl` configuration. The root configuration contains settings that are common across all
# components and environments, such as how to configure remote state.

include "root" {
  path = find_in_parent_folders()
}

# Source Terraform modules
terraform {
  source = "git@github.com:sunilnerella23/terraform-eks-cluster-create.git//modules/eks-cluster-stack?ref=main"
}
locals {
  account_vars   = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  aws_account_id = local.account_vars.locals.aws_account_id
  irsa           = yamldecode(file("${get_terragrunt_dir()}/configs/irsa.yaml"))
  mimir_ruler_bucket_name                 = "mimir-bucket"
  mimir_alert_manager_storage_bucket_name = "mimir-alertmanager"
  mimir_block_storage_bucket_name         = "mimir-blocks-storage"
  mimir_service_role_name                 = "mimir-role"
  kyverno_service_role_name               = "kyverno-role"
}
# Inputs to the source Terraform module
inputs = {
  cluster_name                   = "eks_cluster_name"
  cluster_version                = "1.32"
  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = [ ] //add the public cidrs as needed
  # Enable AWS Managed addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id                   = ["vpc-id"] //define the vpc id of your cluster

  subnet_ids = [""] //define the subnets for your cluster

  subnet_ids_public        = [""] //define public subnets as needed

  eks_managed_node_group_defaults = {
    instance_types = ["i3.xlarge"]
  }

   eks_managed_node_groups = {
    preprodeksng_basic = {
      subnet_ids = [""]
      min_size       = 1
      max_size       = 4
      desired_size   = 1
      instance_types = ["i3.4xlarge"]
      capacity_type  = "ON_DEMAND"
      launch_template_version = 1
      labels = {
        large = "true"
      }
      # New Changes
      ami_release_version = "1.32.3-20250519"
      cluster_version = "1.32"
      use_latest_ami_release_version = false
      force_update_version = true
    }
    monitoring_eks = {
      subnet_ids = [""]
      min_size       = 5
      max_size       = 10
      desired_size   = 5
      instance_types = ["i3.xlarge"]
      ami_type = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"
      launch_template_version = 2      
      labels = {
        monitoring = "true"
      }
      taints = {
        monitoring = {
          key    = "monitoring"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
       ami_release_version = "1.32.3-20250519"
       cluster_version = "1.32"
       use_latest_ami_release_version = false
       force_update_version = true
    }
    general = {
      subnet_ids = dependency.vpc.outputs.private_subnets
      min_size       = 2
      max_size       = 10
      desired_size   = 4
      instance_types = ["m5.xlarge"]
      ami_type = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"
      launch_template_version = 2      
      labels = {
        general = "true"
      }
       ami_release_version = "1.32.3-20250519"
       cluster_version = "1.32"
       use_latest_ami_release_version = false
       force_update_version = true
    }

##testing green adding nodepool and node class
  # Karpneter EC2 Node Classes
  karpenter_ec2_node_classes = {
  "default_v1" = {
    name = "default-v1"
    ami_family = "AL2"
    subnet_selector = {
      tags = {
        "karpenter.sh/discovery" = "private"
        "Environment" = "pre-prod"
      }
    }
    security_group_selector = {
      tags = {
        "aws:eks:cluster-name" = "<clustername defined above>" //define the above clustername
      }
    }
    ami_selector = {
      id = "ami-000d3c3a825868e3c" 
    }
    tags = {
      "karpenter.sh/discovery" = "private"
      "IntentLabel" = "apps"
    }
    block_device_mappings = {
      deviceName = "/dev/xvda"
      ebs = {
        volumeSize = "50Gi"
        volumeType = "gp3"
        encrypted = true
        deleteOnTermination = true
      }
    }
  }    
}

 # Karpenter Node templates
  karpenter_nodepools = {
    "general-blue" = {
      name = "general-blue"
      node_class_ref = "default-v1"
      labels = {
        "general" = "true"
      }
      instance_types = [
        "i3.xlarge"
      ]
      capacity_type = ["on-demand"]
      zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      taints = [
        {
          key    = "general"
          value  = "true"
          effect = "NoSchedule"
        }
      ]
      cpu_limit = "100"
      memory_limit = "4000Gi"
    }        
    "graviton-streaming-pv-preprod" = {
      name = "graviton-streaming-pv-preprod"
      node_class_ref = "default-v1"
      labels = {
        "large" = "true"
        "graviton"   = "true"
      }
      instance_types = [
        "i4g.4xlarge",
        "i4g.2xlarge"
      ]
      capacity_type = ["on-demand"]
      zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
      taints = [
        {
          key    = "graviton-streaming-pv"
          value  = "true"
          effect = "NoSchedule"
        }
      ]
      cpu_limit = "2000"
      memory_limit = "7000Gi"
    }    
  }

  # Enable/Disbale addons, other than the AWS managed ones
  enable_aws_efs_csi_driver                    = false
  enable_aws_fsx_csi_driver                    = false
  enable_argocd                                = false
  enable_argo_rollouts                         = true
  enable_argo_workflows                        = false
  enable_aws_cloudwatch_metrics                = false
  enable_aws_privateca_issuer                  = false
  enable_cert_manager                          = false
  enable_cluster_autoscaler                    = false
  enable_secrets_store_csi_driver              = true
  enable_secrets_store_csi_driver_provider_aws = true
  enable_kube_prometheus_stack                 = true
  enable_external_dns                          = false
  enable_external_secrets                      = false
  enable_gatekeeper                            = false
  enable_aws_load_balancer_controller          = true
  manage_aws_auth_configmap                    = true
  enable_istio                                 = true
  enable_karpenter                             = true
  enable_openebs                               = true
  enable_volume_cleanup                        = true
  enable_metrics_server                        = true
  enable_prometheus_adapter                    = true
  enable_kubecost                              = false
  enable_nodelocaldnscache                     = true
  enable_kyverno_notation_aws                  = true
  enable_memcache_chunk                        = true
  enable_memcache_result                       = true

  enable_readonly_role = true
  enable_devops_role = true 
  enable_aws_for_fluentbit                     = true

  aws_for_fluentbit = {
    values = [
      <<EOT
      hotReload:
        enabled: true
      tolerations:
        - operator: Exists      
      EOT
    ]
    s3_bucket_arns = [""]     //bucket names for s3 buckets
  }


  kube_prometheus_stack = {
    values = [
      <<EOT
      prometheus:
        prometheusSpec:
          additionalScrapeConfigs:
          - job_name: anyName
            static_configs:
            - targets:
              - 
          additionalRemoteWrite:
          - url: http://mimir-distributed-nginx.mimir.svc:80/api/v1/push
          EOT
    ]
  }
  kubecost_helm_config = {
    values = [
      <<-EOT
          global:
            prometheus:
              enabled: false
              fqdn: http://kube-prometheus-stack-prometheus.kube-prometheus-stack.svc.cluster.local:9090
            grafana:
              enabled: true
              tolerations:
                - key: "monitoring"
                  operator: "Equal"
                  value: "true"
                  effect: "NoSchedule"
          service:
            type: LoadBalancer
            port: 443
            annotations: 
              service.beta.kubernetes.io/aws-load-balancer-type: external
              service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
              service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
          prometheus:
            server:
              global:
                external_labels:
                  cluster_id: <cluster name>
        EOT
    ]
  }

  aws_auth_roles = [

    {
      rolearn  = "arn:aws:iam::${local.aws_account_id}:role/admin"
      username = "admin"
      groups = [
        "system:masters"
      ]
    },
    {
      rolearn  = "arn:aws:iam::${local.aws_account_id}:role/readonly"
      groups   = []
      username = "eks-readonly"
    },
    {
      rolearn  = "arn:aws:iam::${local.aws_account_id}:role/devops"
      username = "eks-devops"
      groups = []
    },
    {
      rolearn  = "arn:aws:iam::${local.aws_account_id}:role/spaces-tf-execution-role"
      username = "terraform"
      groups = [
        "system:masters"
      ]
    }
  ]
  irsa_configs = local.irsa.roles //to create the irsa role required for the application
  environment  = "" //define env name
  karpenter_configs = {
    cpu_limit      = "2000"
    memory_limit   = "2000Gi"
    instance_types = ["i3.large", "i3.xlarge", "i3.2xlarge", "i3.4xlarge", "i3.8xlarge", "i3.16xlarge"]
    capacity_type  = ["spot", "on-demand"]
    consolidation  = true
    subnet_tag     = "private"
    labels = {
      large  = "true"
      intent = "apps"      
    }
  }
  karpenter = {
    chart_version = "1.0.6"
    values = [
        <<-EOT
          tolerations:
            - key: "monitoring"
              operator: "Equal"
              value: "true"
              effect: "NoSchedule"
        EOT
      ]
  }
  /// line #344 to #353 will be needed only if you have argocd in different cluster
  argocd_controller_role_arn = [
    "" //argocd arn if its in different account or cluster
  ]

  register_as_spoke = true
  management_cluster_state = {
    bucket = "" //statefile bucket 
    key = "" //statefile path
    role_arn = "" //role with trust relation from argocd cluster to this cluster
  }

  eks_addons_helm_releases = {
    openebs = {
      description      = "Containerized Attached Storage for Kubernetes"
      namespace        = "openebs"
      create_namespace = true
      chart            = "openebs"
      chart_version    = "3.9.0"
      repository       = "https://openebs.github.io/charts"
      values = [
        <<-EOT
          localprovisioner:
            hostpathClass:
              name: openebs-hostpath-xfs
              basePath: /eksmounts/
              xfsQuota:
                enabled: true
        EOT
      ]
    }
    prometheus-adapter = {
      description      = "Installs the prometheus-adapter for the Custom Metrics API"
      namespace        = "kube-prometheus-stack"
      create_namespace = true
      chart            = "prometheus-adapter"
      chart_version    = "4.10.0"
      repository       = "https://prometheus-community.github.io/helm-charts"
      values = [
        <<-EOT
          logLevel: 6
          grafana:          
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
          prometheus:
            url: http://kube-prometheus-stack-prometheus.kube-prometheus-stack.svc.cluster.local
            path: /
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
          rules:
            custom: []
            default: false
            existing: null
            external:
            - metricsQuery: round(<<.Series>>{<<.LabelMatchers>>})
              name:
                matches: ^haproxy_frontend_bytes_in_total$
              resources:
                namespaced: false
              seriesQuery: '{__name__=~"^haproxy_.*"}'
            - metricsQuery: round(<<.Series>>{<<.LabelMatchers>>})
              name:
                matches: ^kafka_consumergroup_group_lag$
              resources:
                namespaced: false
              seriesQuery: '{__name__=~"^kafka_.*"}' 
        EOT
      ]
    }

    nodelocaldnscache = {
      description      = "NodeLocal DNS Cache helm chart"
      namespace        = "kube-system"
      create_namespace = false
      chart            = "node-local-dns"
      chart_version    = "1.6.0"
      repository       = "https://lablabs.github.io/k8s-nodelocaldns-helm/"
      values = [
        <<-EOT
          metrics:
            prometheusScrape: "false"
            port: 9254
        EOT
      ]
    }
    mimir-distributed = {
      description      = "Install grafana mimir distributed for persisten metrics storage to S3"
      namespace        = "mimir"
      create_namespace = true
      chart            = "mimir-distributed"
      chart_version    = "5.2.1"
      repository       = "https://grafana.github.io/helm-charts"
      values = [
        <<-EOT
          alertmanager:
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
            persistentVolume:
              size: 50Gi
              storageClass: openebs-hostpath-xfs
          compactor:
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
            persistentVolume:
              size: 50Gi
              storageClass: openebs-hostpath-xfs
          store_gateway:
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
            persistentVolume:
              size: 50Gi
              storageClass: openebs-hostpath-xfs
          ingester:
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
            persistentVolume:
              size: 50Gi
              storageClass: openebs-hostpath-xfs
          minio:
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
            enabled: false
          mimir:
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
            enterprise:
              enabled: false
            graphite:
              enabled: false
            structuredConfig:
              limits:
                max_global_series_per_user: 20000000
                ingestion_rate: 200000
                ingestion_burst_size: 1000000
              ruler_storage:
                backend: s3
                s3:
                  endpoint: s3.us-east-1.amazonaws.com
                  region: us-east-1
                  bucket_name: ${local.mimir_ruler_bucket_name}
                  insecure: false
              alertmanager_storage:
                backend: s3
                s3:
                  endpoint: s3.us-east-1.amazonaws.com
                  region: us-east-1
                  bucket_name: ${local.mimir_alert_manager_storage_bucket_name}
                  insecure: false
              blocks_storage:
                backend: s3
                s3:
                  endpoint: s3.us-east-1.amazonaws.com
                  region: us-east-1
                  bucket_name: ${local.mimir_block_storage_bucket_name}
                  insecure: false
          overrides_exporter:
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
          querier:                
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
          distributor:                
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
          nginx:                
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
          query_frontend:                
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
          query_scheduler:                
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
          rollout_operator:                
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"                
          ruler:                
            tolerations:
              - key: "monitoring"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"                
          serviceAccount:
            name: ${local.mimir_service_role_name}-sa
            annotations:
              eks.amazonaws.com/role-arn: arn:aws:iam::${local.aws_account_id}:role/eks/pre-prod-bg-sup-us1-${local.mimir_service_role_name}-IRSA
        EOT
      ]
    }
    kyverno = {
      description      = "Install kyverno"
      namespace        = "kyverno"
      create_namespace = true
      chart            = "kyverno"
      chart_version    = "3.1.4"
      repository       = "https://kyverno.github.io/kyverno"
      values           = [file("${get_terragrunt_dir()}/helm_configs/kyverno_values.yaml")]
    kafka-lag-exporter = {
      name = "kafka-lag-exporter"
      repository = "https://seglo.github.io/kafka-lag-exporter/repo/"
      chart = "kafka-lag-exporter"
      version = "0.8.2"
      create_namespace = true
      namespace = "kafka-lag-exporter"
      values = [
        <<-EOT
        clusters:
        - bootstrapBrokers: 
          name: bi-cluster
        EOT
      ]
    }
  }

  mimir_s3_buckets = [
    "${local.mimir_ruler_bucket_name}",
    "${local.mimir_alert_manager_storage_bucket_name}",
    "${local.mimir_block_storage_bucket_name}"
  ]

  mimir_irsa = {
    app_name = "${local.mimir_service_role_name}"
    policy = [
      {
        allowed_actions = [
          "s3:*"
        ]
        resources = [
          "*"
        ]
      }
    ]
  }
}

