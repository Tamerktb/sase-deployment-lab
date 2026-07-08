output "resource_count" {
  value = 15
}

output "hub_public_ip" {
  value = aws_instance.hub.public_ip
}

output "hub_private_ip" {
  value = aws_instance.hub.private_ip
}

output "site_a_public_ip" {
  value = aws_instance.site_a.public_ip
}

output "site_a_private_ip" {
  value = aws_instance.site_a.private_ip
}

output "site_b_public_ip" {
  value = aws_instance.site_b.public_ip
}

output "site_b_private_ip" {
  value = aws_instance.site_b.private_ip
}

output "ssh_commands" {
  value = {
    hub    = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.hub.public_ip}"
    site_a = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.site_a.public_ip}"
    site_b = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.site_b.public_ip}"
  }
}

output "wg_quick_commands" {
  value = "After SSH: sudo wg-quick up /etc/wireguard/wg0.conf"
}

output "teardown" {
  value = <<-EOT
    When done:
      1. terraform destroy -auto-approve
      2. Verify in AWS Console that all 15 resources are removed
  EOT
}
