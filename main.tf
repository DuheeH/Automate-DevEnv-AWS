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

resource "aws_security_group" "basic_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.basic_vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    # needs to specified as a string otherwise, the "-" will not be honored
    # a -1 protocol means that all traffic for all protocols are allowed
    protocol = "-1"
    # only include the dev user ip address using find my IP /32 to only include that IP
    # note "blocks", we can specify more than one CIDR block by using comma separated list
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # the egress should allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "basic_auth" {
  key_name = "basic_key"
  # file(path) is a terraform function that reads the contents of a file at the given path and returns them as a string.
  public_key = file("~/.ssh/basic_key.pub")
}

resource "aws_instance" "dev_node" {
  instance_type = "t2.micro"
  # Note here that because the AMI comes from a datasource, we need "data."
  ami = data.aws_ami.server_ami.id
  # Note here that we can use the ".key_name" instead of ".id" if we want to be more specific
  # terraform state show aws_key_pair.basic_auth
  key_name = aws_key_pair.basic_auth.id
  # Note here that you can have more than 1 VPC
  vpc_security_group_ids = [aws_security_group.basic_sg.id]
  subnet_id = aws_subnet.basic_public_subnet.id
  # Takes the user data in the userdata.tpl file to bootstrap the instance
  # Note that when we do terraform plan, we see a hash that corresponds to the user data we currently have. if the user data changes, so does the hash and so we know that it needs to update.
  user_data = file("userdata.tpl")


  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }
  
  # Ideally we should use user data or a configuration tool (Packer, Ansible) to configure a remote instance
  # In this situation, we will use a provisioner "local-exec" to configure our instance
  # The "self" attribute allows us to use instance attributes
  provisioner "local-exec" {
    # templatefile is a function that passes a file and var
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname = self.public_ip
      user = "ubuntu"
      identityfile = "~/.ssh/basic_key"
    })
    interpreter = var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "-Command"]
  }
}

# Now at this point, once we update/replace the dev-node, we can SSH into the instance by using the remote SSH extension that we downloaded
# We now have a remote dev environment!

# Optimizations
  # Be able to choose ssh config file dynamically based on defintion of host os variable
    # OS: windows, linux, mac, unix
    # we will use interpolation syntax so that we can edit as needed
      # linux -> ${var.host_os}
    # We will create a variables.tf file to store the variables
    # Now that we have a varibles, when we run certain terraform commands (plan, destroy, apply), we will need to enter a value for that variable
      # We want to avoid that because it interrupts automation
      # We can do so by creating a terraform.tfvars file
        # This will have precedence, before the variables.tf file and allows automation
        # We can test by using terraform console
          # linux in variables.tf and windows in terraform -> console will return windows when trying var.host_os
      # to override even terraform.tfvars, we write the variables value inline
        # terraform console -var="host_os=unix"
      # if we have mutliple .tfvars files, terraform will still run terraform.tfvars precedent
        # we can override this by writing inline
          # terraform console -var-file="dev.tfvars
  # Choose interperter dynamically, not as simple as interpolation syntax
    # use conditional expressions to choose dynamically based off host OS
    # powershell vs bash
    # Conditionals
      # var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "-Command"]
  # now we can have our dev environment generated dynamically!!