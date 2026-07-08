variable "aws_region" {
  description = "AWS region to deploy in"
  type        = string
  default     = "eu-central-1"
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro qualifies for free tier)"
  type        = string
  default     = "t3.micro"
}

variable "cloudflare_tunnel_tokens" {
  description = "Cloudflare tunnel tokens per site (leave empty to skip cloudflared)"
  type = object({
    hub    = optional(string, "")
    site_a = optional(string, "")
    site_b = optional(string, "")
  })
  default = {}
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
