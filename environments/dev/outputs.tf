# WHY re-export?
# The module outputs are only accessible within the module call.
# Re-exporting them here makes them visible when you run
# "terraform output" from the dev directory — super helpful
# for debugging and for other tools that read Terraform output.

output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "database_subnet_ids" {
  value = module.networking.database_subnet_ids
}

output "nat_gateway_ips" {
  value = module.networking.nat_gateway_ips
}