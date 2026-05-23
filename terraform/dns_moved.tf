# State migration: module.dns → module.dns[0] when enable_hetzner_dns is true

moved {
  from = module.dns
  to   = module.dns[0]
}

moved {
  from = output.domain_cicd_showcase_de
  to   = output.dns_domain
}
