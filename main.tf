# Create a VPC
resource "aws_vpc" "basic_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "basic_public_subnet" {
  # The id that we are referencing here can be found by running "terraform state show aws_vpc.basic_vpc" and scrolling down to the id value
  vpc_id = aws_vpc.basic_vpc.id
  # The subnet should have a IP range than the VPC
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    # Since we have a public IP, we should include a tag to make sure that we don't deploy private instances to this public subnet
    Name = "dev-public"
  }
}

# After runnning terraform apply, go to the AWS extension and add subnet so that you can see the subnet in the JSON file

resource "aws_internet_gateway" "basic_internet_gateway" {
  vpc_id = aws_vpc.basic_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

# "terraform fmt" will change the formatting to make it look nicer

resource "aws_route_table" "basic_public_rt" {
  vpc_id = aws_vpc.basic_vpc.id

  tags = {
    Name = "dev_public_rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.basic_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.basic_internet_gateway.id
}

resource "aws_route_table_association" "basic_public_assoc" {
  subnet_id      = aws_subnet.basic_public_subnet.id
  route_table_id = aws_route_table.basic_public_rt.id
}
