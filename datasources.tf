data "aws_ami" "server_ami" {
  most_recent = true
  # note owners, a list so that there can be more than one AMI
  # the owner id is found on AWS, public AMIs, finding AMI name and then owner tag in AMIs
  owners = ["099720109477"]

  filter {
    name = "name"
    # The * at the end will make sure that the latest version is used
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}