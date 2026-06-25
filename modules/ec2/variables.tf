variable "keypair_name" {
  type        = string
  description = "The key name used to enter the ec2 instance"
}

variable "iam_instance_profile" {
  type        = string
  description = "The name of the iam instance profile"
}

variable "instance_type" {
  type        = string
  description = "The type of instance to launch."
  default     = "t3.micro"
}

variable "user_data" {
  type        = string
  description = "The script you want to run upon startup"
}

variable "ec2_instance_name" {
  type        = string
  description = "The name of the ec2 instance"
}
