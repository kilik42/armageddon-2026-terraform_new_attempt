#aws_default_vpc "default" {}
resource "aws_vpc" "main" {

  cidr_block = "10.0.0.0/16"
    tags = {
        Name = "main_vpc"
    }   

}
