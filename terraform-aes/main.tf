# data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}

resource "aws_security_group" "elasticsearch" {
  name        = var.name
  description = "Security Group to allow traffic to ElasticSearch"

  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "secure_cidrs" {
  count = length(var.ingress_allow_cidr_blocks) > 0 ? 1 : 0

  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "TCP"
  cidr_blocks = var.ingress_allow_cidr_blocks

  security_group_id = aws_security_group.elasticsearch.id
}

resource "aws_security_group_rule" "secure_sgs" {
  count = length(var.ingress_allow_security_groups)

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = element(var.ingress_allow_security_groups, count.index)

  security_group_id = aws_security_group.elasticsearch.id
}

resource "aws_security_group_rule" "egress_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.elasticsearch.id
}

# https://github.com/terraform-providers/terraform-provider-aws/issues/5218
resource "aws_iam_service_linked_role" "default" {
  count            = var.create_iam_service_linked_role ? 1 : 0
  aws_service_name = "es.amazonaws.com"
  description      = "AWSServiceRoleForAmazonElasticsearchService Service-Linked Role"
}

resource "aws_elasticsearch_domain" "es" {
  domain_name           = var.name
  elasticsearch_version = var.elasticsearch_version

  encrypt_at_rest {
    enabled    = var.encryption_enabled
    kms_key_id = var.encryption_kms_key_id
  }

  cluster_config {
    instance_type            = var.itype
    instance_count           = var.icount
    dedicated_master_enabled = var.dedicated_master
    dedicated_master_type    = var.mtype
    dedicated_master_count   = var.mcount
    zone_awareness_enabled   = var.zone_awareness
    zone_awareness_config {
      availability_zone_count = length(var.subnet_ids) > 2 ? 3 : 2
    }
  }

  access_policies = var.access_policies

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https = true
    tls_security_policy = "Policy-Min-TLS-1-0-2019-07"
  }

  advanced_security_options {
     enabled                        = true
     internal_user_database_enabled = true  
     master_user_options {
        #  master_user_arn      = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:user/geniusee"
         master_user_name     = "geniusee-user"	
         master_user_password = "Geniusee@!@!@!"
     }
  }


  vpc_options {
    security_group_ids = [aws_security_group.elasticsearch.id]
    subnet_ids         = var.subnet_ids
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = var.rest_action_multi_allow_explicit_index
    "indices.fielddata.cache.size"           = var.indices_fielddata_cache_size
    "indices.query.bool.max_clause_count"    = var.indices_query_bool_max_clause_count
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.volume_type
    volume_size = var.volume_size
  }

  snapshot_options {
    automated_snapshot_start_hour = var.snapshot_start
  }

  tags = {
    Domain = var.name
  }

  depends_on = [
    aws_iam_service_linked_role.default,
  ]
}

# Add ALB record on DNS
resource "aws_route53_record" "main" {
  count   = length(var.zone_id) > 0 ? 1 : 0
  zone_id = var.zone_id
  name    = var.name
  type    = "CNAME"
  ttl     = "300"

  records = [aws_elasticsearch_domain.es.endpoint]
}
