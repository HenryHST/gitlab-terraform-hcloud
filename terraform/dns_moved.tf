# State migration: module.dns → module.dns[0] when enable_hetzner_dns is true

moved {
  from = module.dns
  to   = module.dns[0]
}
