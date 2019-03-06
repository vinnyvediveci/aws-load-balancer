variable "access_key" {}
variable "secret_key" {}
variable "key_path" {}

provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "us-east-1"
}

resource "aws_vpc" "test" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    tags {
        Name = "load balancer test"
    }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.test.id}"
}

resource "aws_subnet" "testa" {
    vpc_id = "${aws_vpc.test.id}"
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags {
        Name = "test A"
    }
}

resource "aws_subnet" "testb" {
    vpc_id = "${aws_vpc.test.id}"
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
    tags {
        Name = "test B"
    }
}

resource "aws_route_table" "test_route" {
  vpc_id = "${aws_vpc.test.id}"

route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
 }

 tags {
        Name = "new route table"
    }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.testa.id}"
  route_table_id = "${aws_route_table.test_route.id}"
}

resource "aws_route_table_association" "b" {
  subnet_id      = "${aws_subnet.testb.id}"
  route_table_id = "${aws_route_table.test_route.id}"
}

resource "aws_security_group" "basic" {
  name = "basic"
  vpc_id      = "${aws_vpc.test.id}"
  ingress {
    cidr_blocks = ["0.0.0.0/0"]  
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]  
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
tags {
        Name = "basic-access"
    }
}

resource "aws_instance" "server1" {
    ami = "ami-04bfee437f38a691e"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    subnet_id = "${aws_subnet.testa.id}"
    key_name = "Susan"
    security_groups = ["${aws_security_group.basic.id}"]
   connection {
        user = "ec2-user"
        private_key = "${file(var.key_path)}"
}
    
    provisioner "remote-exec" {
        inline = [
        "sudo yum update -y",
        "sudo amazon-linux-extras install nginx1.12 -y",
        "sudo rm /usr/share/nginx/html/index.html",
        "echo ' <h1> This is server 1 </h1>' > index.html",
        "sudo mv index.html /usr/share/nginx/html/",
        "sudo service nginx start"
]
}
    tags {
        Name = "Server 1"
    }
}

resource "aws_instance" "server2" {
  depends_on = ["aws_instance.server1"]
    ami = "ami-04bfee437f38a691e"
    instance_type = "t2.micro"
    availability_zone = "us-east-1b"
    subnet_id = "${aws_subnet.testb.id}"
    key_name = "Susan"
    security_groups = ["${aws_security_group.basic.id}"]
   connection {
        user = "ec2-user"
        private_key = "${file(var.key_path)}"
}
    
    provisioner "remote-exec" {
        inline = [
        "sudo yum update -y",
        "sudo amazon-linux-extras install nginx1.12 -y",
        "sudo rm /usr/share/nginx/html/index.html",
        "echo '<h1> This is server 2 </h1>' > index.html",
        "sudo mv index.html /usr/share/nginx/html/",
        "sudo service nginx start"
]
}
    tags {
        Name = "Server 2"
    }
}

resource "aws_elb" "new" {
  
  subnets = ["${aws_subnet.testa.id}", "${aws_subnet.testb.id}"]
  security_groups = ["${aws_security_group.basic.id}"]
   listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  
  instances                   = ["${aws_instance.server1.id}", "${aws_instance.server2.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400


  tags {
        Name = "load-balancer"
    }
}