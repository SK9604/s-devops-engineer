module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "devops-engineer-vpc"
  cidr = "10.21.0.0/16"

  azs = ["ap-northeast-2a", "ap-northeast-2c"]

  public_subnets = ["10.21.1.0/24", "10.21.2.0/24"]
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "role"                   = "public"
  }
  
  private_subnets = ["10.21.32.0/24", "10.21.33.0/24"]
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "role"                            = "private"
  }

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  create_igw = true
}
