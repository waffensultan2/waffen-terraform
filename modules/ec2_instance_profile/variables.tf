variable "iam_policies" {
  type = set(object({
    effect    = string,
    actions   = list(string),
    resources = list(string)
  }))
}

variable "profile_name" {
  type        = string
  description = "This is the profile's name"
}
