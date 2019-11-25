data "aws_ami" "ami_servers" {
  owners = ["amazon"]
  most_recent = true
  name_regex = "amzn2"
}

resource "aws_vpc" "VPC_Nuveshop" {  
  cidr_block            = "${var.vpc_cidr}.0/24"
  instance_tenancy      = "default"
  enable_dns_support    = "true"
  enable_dns_hostnames  = "true"
  tags = {
    Name = "VPC-NuvemShop"
  }
}

resource "aws_internet_gateway" "IGWNuvemshop" {
  vpc_id = "${aws_vpc.VPC_Nuveshop.id}"

  tags = {
    Name = "IGW-NuvemShop"
  }

  depends_on = [ "aws_vpc.VPC_Nuveshop"]
}
  
resource "aws_subnet" "SubnetPublic-1" {
  vpc_id            = "${aws_vpc.VPC_Nuveshop.id}"
  cidr_block        = "${var.vpc_cidr}.0/26"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "NuvemShop - public subnet 1"
  }

  depends_on = [ "aws_vpc.VPC_Nuveshop"]
}

resource "aws_subnet" "SubnetPublic-2" {
  vpc_id            = "${aws_vpc.VPC_Nuveshop.id}"
  cidr_block        = "${var.vpc_cidr}.64/26"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "NuvemShop - public subnet 2"
  }

  depends_on = [ "aws_vpc.VPC_Nuveshop"]
}

resource "aws_subnet" "SubnetPrivate-1" {
  vpc_id            = "${aws_vpc.VPC_Nuveshop.id}"
  cidr_block        = "${var.vpc_cidr}.128/26"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "NuvemShop - private subnet 1"
  }

  depends_on = [ "aws_vpc.VPC_Nuveshop"]
}

resource "aws_subnet" "SubnetPrivate-2" {
  vpc_id            = "${aws_vpc.VPC_Nuveshop.id}"
  cidr_block        = "${var.vpc_cidr}.192/26"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "NuvemShop - private subnet 2"
  }
}

resource "aws_eip" "eip" {
  vpc      = true
}

resource "aws_nat_gateway" "NatGateway" {
  allocation_id = "${aws_eip.eip.id}"
  subnet_id     = "${aws_subnet.SubnetPublic-1.id}"

  tags = {
    Name = "NAT GW - NuvemShop"
  }

   depends_on = [ "aws_eip.eip", "aws_subnet.SubnetPublic-1"]
}

resource "aws_route_table" "publicRT" {
  vpc_id = "${aws_vpc.VPC_Nuveshop.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.IGWNuvemshop.id}"
  }

  tags = {
    Name = "NuvemShop - Public Route Table"
  }

  depends_on = [ "aws_internet_gateway.IGWNuvemshop" ]
}

resource "aws_route_table" "privateRT" {
  vpc_id = "${aws_vpc.VPC_Nuveshop.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.NatGateway.id}"
  }

  tags = {
    Name = "NuvemShop - Private Route Table"
  }

  depends_on = [ "aws_nat_gateway.NatGateway" ]
}

resource "aws_route_table_association" "publicSubnet1RouteTableAssociation" {
  subnet_id      = "${aws_subnet.SubnetPublic-1.id}"
  route_table_id = "${aws_route_table.publicRT.id}"
  
  depends_on = [ "aws_subnet.SubnetPublic-1", "aws_route_table.publicRT"]
}

resource "aws_route_table_association" "publicSubnet2RouteTableAssociation" {
  subnet_id      = "${aws_subnet.SubnetPublic-2.id}"
  route_table_id = "${aws_route_table.publicRT.id}"
  
  depends_on = [ "aws_subnet.SubnetPublic-2", "aws_route_table.publicRT"]
}

resource "aws_route_table_association" "privateSubnet1RouteTableAssociation" {
  subnet_id      = "${aws_subnet.SubnetPrivate-1.id}"
  route_table_id = "${aws_route_table.privateRT.id}"
  
  depends_on = [ "aws_subnet.SubnetPrivate-1", "aws_route_table.privateRT"]
}




############################# SECURITY GROUPS ###################################
resource "aws_security_group" "SgALB" {
  description = "Allow inbound traffic to ALB"
  vpc_id      = "${aws_vpc.VPC_Nuveshop.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "NuvemShop - SecurityGroup-ALB"
  }
}

resource "aws_security_group" "SgEC2" {
  description = "Allow inbound traffic to EC2 instances"
  vpc_id      = "${aws_vpc.VPC_Nuveshop.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = ["${aws_security_group.SgALB.id}"]
    description     = "ALB Security Group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "NuvemShop - SecurityGroup-EC2"
  }

  depends_on  = ["aws_security_group.SgALB"]
}



############################# LOAD BALANCER ###################################
resource "aws_lb" "NuvemShopALB" {
  name               = "NuvemShop-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.SgALB.id}"]
  subnets            = ["${aws_subnet.SubnetPublic-1.id}", "${aws_subnet.SubnetPublic-2.id}"]

  tags = {
    Description = "ALB on public subnet to access EC2 on private subnet"
  }
}

resource "aws_lb_target_group" "ALB-TargetGroupApache" {
  name          = "TargetGroup-Apache"
  port          = 80
  protocol      = "HTTP"
  vpc_id        = "${aws_vpc.VPC_Nuveshop.id}"
  target_type = "instance"

  depends_on    = ["aws_lb.NuvemShopALB"]
}

resource "aws_lb_target_group" "ALB-TargetGroupNginx" {
  name          = "TargetGroup-Nginx"
  port          = 80
  protocol      = "HTTP"
  vpc_id        = "${aws_vpc.VPC_Nuveshop.id}"
  target_type = "instance"

  depends_on    = ["aws_lb.NuvemShopALB"]
}

resource "aws_lb_listener" "listenerApache" {
  load_balancer_arn = "${aws_lb.NuvemShopALB.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.ALB-TargetGroupApache.arn}"
  }

  depends_on = ["aws_lb.NuvemShopALB"]
}

resource "aws_lb_listener_rule" "ruleNginx" {
  listener_arn = "${aws_lb_listener.listenerApache.arn}"
  priority     = 2
  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.ALB-TargetGroupNginx.arn}"    
  }

  condition {
    field  = "path-pattern"
    values = [ "/nginx.html" ]
  }
}



############################# EC2 INSTANCES ###################################

resource "aws_instance" "ApacheServer" {
  ami                     = "${data.aws_ami.ami_servers.id}"
  instance_type           = "${var.instance_type}"
  vpc_security_group_ids  = [ "${aws_security_group.SgEC2.id}" ]
  subnet_id               = "${aws_subnet.SubnetPrivate-1.id}"
  availability_zone       = "${var.region}a"
  user_data               = "${file("apache.sh")}"

  tags = {
    Name = "NuvemShop - Apache Server"
  }
}

resource "aws_instance" "NginxServer" {
  ami                     = "${data.aws_ami.ami_servers.id}"
  instance_type           = "${var.instance_type}"
  vpc_security_group_ids  = [ "${aws_security_group.SgEC2.id}" ]
  subnet_id               = "${aws_subnet.SubnetPrivate-1.id}"
  availability_zone       = "${var.region}a"
  user_data               = "${file("nginx.sh")}"

  tags = {
    Name = "NuvemShop - Nginx Server"
  }
}

resource "aws_lb_target_group_attachment" "ALBtagertApache" {
  target_group_arn = "${aws_lb_target_group.ALB-TargetGroupApache.arn}"
  target_id        = "${aws_instance.ApacheServer.id}"
  port             = 80

  depends_on      = [ "aws_instance.ApacheServer" ]
}

resource "aws_lb_target_group_attachment" "ALBtagertNginx" {
  target_group_arn = "${aws_lb_target_group.ALB-TargetGroupNginx.arn}"
  target_id        = "${aws_instance.NginxServer.id}"
  port             = 80

  depends_on      = [ "aws_instance.NginxServer" ]
}


############################# OUTPUTS ###################################
output "dns_alb" {
  value = "${aws_lb.NuvemShopALB.dns_name}"
}

output "dns_alb_nginx" {
  value = "${aws_lb.NuvemShopALB.dns_name}/nginx.html"
}