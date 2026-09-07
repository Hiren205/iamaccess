locals {
  cluster_name = var.k8s_cluster_name
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr_block

  azs = [
  data.aws_availability_zones.available.names[0],
  data.aws_availability_zones.available.names[2]
  ]
  private_subnets = var.private_subnet_cidr_blocks
  public_subnets  = var.public_subnet_cidr_blocks

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for ALB controller to find correct subnets
  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    environment                                    = "aws-tuum"
    project                                        = "neof-coorb-aws-002"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"   # ALB goes here
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}
# ── EKS CLUSTER ───────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.17.0" 

  name    = local.cluster_name
  kubernetes_version  = var.k8s_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access  = true
  enable_irsa = true


  tags = {
    environment = "aws-tuum"
    project     = "neof-coorb-aws-002"
  }

  # ── NODE GROUP ──────────────────────────────────────────
  eks_managed_node_groups = {
    node_config = {
      min_size     = 1
      max_size     = 2
      desired_size = 2

      instance_types = ["t3.small"]
      disk_size = 30

      labels = {
        environment = "aws-tuum"
        project     = "neof-coorb-aws-002"
      }

      tags = {
        environment = "aws-tuum"
        project     = "neof-coorb-aws-002"
      }
    }
  }

  # ── NODE SECURITY GROUP ─────────────────────────────────
  node_security_group_additional_rules = {
    ingress_nodes_internal = {
      description = "Node to node all ports"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_alb_health = {
      description = "ALB health check to nodes"
      protocol    = "tcp"
      from_port   = 8090
      to_port     = 8091
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr_block]
    }
    ingress_keycloak = {
      description = "ALB health check to Keycloak"
      protocol    = "tcp"
      from_port   = 8080
      to_port     = 8080
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr_block]
    }
    egress_all = {
      description = "Allow all outbound"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

# ── RDS POSTGRESQL ────────────────────────────────────────
resource "aws_db_subnet_group" "SubnetGroup" {
  name       = "${local.cluster_name}-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    environment = "aws-tuum"
    project     = "neof-coorb-aws-002"
  }
}

resource "aws_security_group" "rdssg" {
  name        = "${local.cluster_name}-rds-sg"
  description = "Allow PostgreSQL from EKS nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    # Only allow from EKS node security group
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    environment = "aws-tuum"
    project     = "neof-coorb-aws-002"
  }
}

resource "aws_db_instance" "databseinstance" {
  identifier = "${local.cluster_name}-postgres"

  engine         = "postgres"
  engine_version = "16.9"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 30 
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "postgres"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.SubnetGroup.name
  vpc_security_group_ids = [aws_security_group.rdssg.id]

  multi_az               = false
  publicly_accessible    = false 
  deletion_protection    = false 
  skip_final_snapshot    = true

  tags = {
    environment = "aws-tuum"
    project     = "neof-coorb-aws-002"
  }
}