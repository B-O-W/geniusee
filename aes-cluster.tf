
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

module "es-cluster" {
  source = "./terraform-aes"

  name                      = "geniusee-es"
  elasticsearch_version     = "7.10"
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnets
  itype                     = "t3.small.elasticsearch"
  icount                    = 3
  zone_awareness            = true
  ingress_allow_cidr_blocks = ["10.0.0.0/16"]
  access_policies           = <<CONFIG
{   
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": "*",
            "Effect": "Allow",
            "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/geniusee-es/*"
        }
    ]
}
CONFIG

}