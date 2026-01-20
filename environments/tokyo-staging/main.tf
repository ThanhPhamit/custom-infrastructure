module "network" {
  source = "../../modules/network"

  app_name              = var.app_name
  aws_region            = var.region
  azs_name              = var.azs_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_ciders  = var.public_subnet_ciders
  private_subnet_ciders = var.private_subnet_ciders
}

module "rds" {
  source = "../../modules/rds-cluster"
  providers = {
    aws.primary   = aws
    aws.secondary = aws
  }

  region                      = var.region
  sec_region                  = var.sec_region
  primary_azs_name            = var.azs_name
  secondary_azs_name          = []
  primary_vpc_id              = module.network.vpc_id
  private_subnet_ids_p        = module.network.private_subnet_ids
  private_subnet_ids_s        = null
  name                        = var.name
  identifier                  = var.identifier
  engine                      = var.engine
  engine_version_pg           = var.engine_version_pg
  engine_version_mysql        = var.engine_version_mysql
  instance_class              = var.db_instance_class

  database_name               = "welfandb"
  username                    = "welfanuser"
  password                    = "password"
  manage_master_user_password = var.manage_master_user_password
  setup_globaldb              = var.setup_globaldb
  setup_as_secondary          = var.setup_as_secondary
  monitoring_interval         = var.monitoring_interval
  storage_encrypted           = var.storage_encrypted
  storage_type                = var.storage_type
  primary_instance_count      = var.primary_instance_count
  secondary_instance_count    = var.secondary_instance_count
  snapshot_identifier         = var.snapshot_identifier
}
