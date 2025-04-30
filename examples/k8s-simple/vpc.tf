variable "vpc_id" {
  type        = string
  description = "The ID of the desired VPC. Ex vpc-xxxxxx"
}
variable "public_subnets" {
  type        = list(string)
  description = "List of IDs of public subnets. Ex subnet-xxxxxx"
}
variable "private_subnets" {
  type        = list(string)
  description = "List of IDs of private subnets. Ex subnet-xxxxxx"
}
