
# order of creation
# 1. create subnets in different availability zones
# 2. create db subnet group for RDS
# 3. create security groups for webserver and RDS
# 4. create RDS instance
# prerequisite : VPC should be created first before creating subnets
# assuming VPC is created in main_1a.tf with name aws_vpc.main

#what we are doing here is to create subnets in different availability zones
# using data source to get all avaialable zones in the region
data "aws_availability_zones" "available" {
    state = "available"


}

#create two subnets in two different availability zones
# This is required for RDS Multi-AZ deployment
# Subnet in AZ 1 default in the first az if one does not exit
resource "aws_subnet" "subnet_az1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]
    tags = {
        Name = "subnet1"
    }
}


# DEFAULT is to create subnet in the second az if one does not exist
resource "aws_subnet" "subnet_az2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]
    tags = {
        Name = "subnet2"
    }
}



#aws security group  for webserver
#for my ec2 instance to allow http access on port 80
resource "aws_security_group" "webserver_sg" {
    name        = "webserver_security_group"
    description = "enable http access on port 80"
    vpc_id      = aws_vpc.main.id

    # we configure ingress and egress rules
    # ingress rule to allow http access on port 80
    ingress {
        description = "http access"
        from_port   = 80
        to_port     = 80
        #why use tcp ? http uses tcp protocol
        protocol    = "tcp"
        # Allow HTTP access from anywhere (not recommended for production)
        cidr_blocks = ["0.0.0.0/0"]
    }

    # egress rule to allow all outbound traffic
    # by default all outbound traffic is allowed
    egress{
        from_port   = 0     
        to_port     = 0
        #protocol for all traffic 
        # why I would use -1 ? It means all protocols
        protocol    = "-1"
        # Allow all outbound traffic
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "webserver_sg"
    }

}

#create security group for RDS
resource "aws_security_group" "rds_sg" {
    name        = "rds_security_group"
    description = "enable mysql/aurora access on port 3306"
    vpc_id      = aws_vpc.main.id

    ingress {
        description = "mysql access"
        #why use 3306 ? it is default port for mysql
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        # Allow MySQL access from webserver security group
        # this allows only instances in webserver_sg to access RDS
        # more secure than allowing access from all IPs

        security_groups = [aws_security_group.webserver_sg.id]
    }

# egress rule to allow all outbound traffic
# by default all outbound traffic is allowed
# do we need outbound rule for RDS security group ?
# Yes, RDS instances need to communicate with other AWS services and resources,
# so an outbound rule is necessary to allow this communication.
    egress{
        from_port   = 0     
        to_port     = 0
        #protocol for all traffic 
        # why I would use -1 ? It means all protocols
        protocol    = "-1"
        # Allow all outbound traffic
        cidr_blocks = ["0.0.0.0/0"] 
    }
    tags = {
      Name = "RDS security group"
    }
}

# do we need an https ingress rule for RDS security group ?
# No, RDS does not require an HTTPS ingress rule. RDS instances typically use database



# create DB subnet group for RDS
# why we need a subnet group for RDS ?
# A DB subnet group is a collection of subnets that you create in a VPC and 
# designate for your RDS DB instances. When you create a DB instance in a VPC,
# you must specify a DB subnet group. This ensures that your DB instance is 
# created in the subnets that you have designated for your RDS instances.
resource "aws_db_subnet_group" "rds_subnet_group" {
    name       = "rds_subnet_group" 
    subnet_ids = [aws_subnet.subnet_az1.id, aws_subnet.subnet_az2.id]
    description = "Subnet group for RDS instance"
    tags = {
        Name = "RDS subnet group"
    }
}


#database subnet group for RDS
# resource "aws_db_subnet_group" "rds_subnet_group" {
#     name       = "rds_subnet_group" 
#     subnet_ids = [aws_subnet.subnet_az1.id, aws_subnet.subnet_az2.id]
#     tags = {
#         Name = "RDS subnet group"
#     }   
# }

# db instance
resource "aws_db_instance" "mydbinstance" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
#   name                 = "mydb"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
#   instance_class       = "db.t3.micro"
  skip_final_snapshot  = true
  db_name = "applicationdb"
#   identifier = "armageddon-mysql-db"
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}



 # Example RDS instance configuration
# resource "aws_db_instance" "default" {
#   allocated_storage    = 20
#   storage_type         = "gp2"
#   engine               = "mysql"
#   engine_version       = "8.0"
#   instance_class       = "db.t3.micro"
#   name                 = "mydb"
#   username             = "admin"
#   password             = "password123"
#   parameter_group_name = "default.mysql8.0"
#   skip_final_snapshot  = true
# }