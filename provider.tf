data "aws_eks_cluster" "default" {
  #name = module.aws-eks-cluster.aws-eks-cluster-id
  name  = aws_eks_cluster.demo-eks.id
}

data "aws_eks_cluster_auth" "default" {
  # name = module.aws-eks-cluster.aws-eks-cluster-id
  name  = aws_eks_cluster.demo-eks.id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  # token                  = data.aws_eks_cluster_auth.default.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.id]
    command     = "aws"
  }
}

provider "kubectl" {
  #host                   = module.aws-eks-cluster.aws-eks-cluster-endpoint
  host                    = aws_eks_cluster.demo-eks.endpoint
  #cluster_ca_certificate = base64decode(module.aws-eks-cluster.aws-eks-kubeconfig-certificate-authority-data)
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.id]
    command     = "aws"
  }
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.default.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.id]
      command     = "aws"
    }
  }
}


