resource "aws_default_vpc" "default-vpc" {

}

resource "aws_default_subnet" "default-subnet-a" {
  availability_zone = "ap-southeast-2a"
}

resource "aws_default_subnet" "default-subnet-b" {
  availability_zone = "ap-southeast-2b"
}

resource "aws_default_subnet" "default-subnet-c" {
  availability_zone = "ap-southeast-2c"
}

resource aws_iam_role "demo-eks-role" {

  name               = "demo-eks-role"
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
  EOF
}


resource "aws_iam_role" "demo-eks-node-role" {
  name = "demo-eks-node-role"
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.demo-eks-role.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.demo-eks-role.name
}

# Enable Security Groups for Pods
resource "aws_iam_role_policy_attachment" "eks-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.demo-eks-role.name
}

resource "aws_iam_role_policy_attachment" "node-group-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       =aws_iam_role.demo-eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "node-group-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.demo-eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "node-group-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.demo-eks-node-role.name
}


resource "aws_eks_cluster" "demo-eks" {
  name      = "demo-eks-cluster"
  role_arn  = aws_iam_role.demo-eks-role.arn
  version   = "1.24"
  vpc_config {
    subnet_ids              = [aws_default_subnet.default-subnet-a.id,aws_default_subnet.default-subnet-b.id,aws_default_subnet.default-subnet-c.id]
    security_group_ids      = [aws_security_group.demo-sg-cluster.id]
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api","audit", "authenticator", "controllerManager", "scheduler"]

  tags                      = var.tags
}

resource "aws_security_group" "demo-sg-cluster" {
  name        = "demo-sg"
  tags        = var.tags
  description = "eks cluster sg"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "eks_nodes" {
  name        = "demo-eks-nodes-sg"
  description = "sg for nodes"
  vpc_id      = aws_default_vpc.default-vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.demo-sg-cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group_rule" "cluster_inbound" {
  from_port                = 0
  protocol                 = "-1"
  #security_group_id        = module.aws-eks-cluster.aws-eks-sg-id
  security_group_id        = aws_security_group.demo-sg-cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 0
  type                     = "ingress"
}

resource "aws_eks_node_group" "demo-node-group" {
  cluster_name    = aws_eks_cluster.demo-eks.name
  node_role_arn   = aws_iam_role.demo-eks-node-role.arn
  subnet_ids      = [aws_default_subnet.default-subnet-a.id,aws_default_subnet.default-subnet-b.id,aws_default_subnet.default-subnet-c.id]
  instance_types  = ["t3.medium"] # if requirement for backend is 4cpu for HA 3 replicas change to t3 large
  version         = "1.24"


scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 3
  }
}

data "tls_certificate" "cert" {
 # url             = module.aws-eks-cluster.aws-eks-cluster-identity.issuer
  url               = aws_eks_cluster.demo-eks.identity[0].oidc[0].issuer

}

resource "aws_iam_openid_connect_provider" "openid" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cert.certificates[0].sha1_fingerprint]
  #url             = module.aws-eks-cluster.aws-eks-cluster-identity.issuer
  url              = aws_eks_cluster.demo-eks.identity[0].oidc[0].issuer
  depends_on      = [aws_eks_cluster.demo-eks]
}

resource "helm_release" "frontend-app" {
  name       = "frontend-app"
  chart      = "${path.module}/frontend"
  namespace  = "frontend"
  create_namespace = true
}

resource "helm_release" "backend-app" {
  name       = "backend-app"
  chart      = "${path.module}/backend"
  namespace  = "backend"
  create_namespace = true
}
