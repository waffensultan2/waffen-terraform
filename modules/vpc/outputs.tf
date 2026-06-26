output "public_subnet_one" {
    value = aws_subnet.public_subnets[0].id
}

output "aws_vpc_id" {
    value = aws_vpc.main.id
}
