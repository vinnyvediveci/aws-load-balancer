

resource "aws_security_group" "basic" {
  name   = "basic"
  vpc_id = aws_vpc.test.id

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

  tags = {
    Name = "basic-access"
  }

}


resource "aws_instance" "server_1" {
  ami               = var.ami
  instance_type     = var.instance_type
  availability_zone = var.availability_zones[0]
  subnet_id         = aws_subnet.subnet_a.id
  key_name          = "terraform"
  security_groups   = [aws_security_group.basic.id]


  connection {
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file(var.key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo amazon-linux-extras install nginx1.12 -y",
      "sudo rm /usr/share/nginx/html/index.html",
      "echo '<h1> This is server 1 </h1>' > index.html",
      "sudo mv index.html /usr/share/nginx/html/",
      "sudo service nginx start"
    ]
  }
  tags = {
    Name = "Server 1"
  }
}

resource "aws_instance" "server_2" {
  depends_on        = [aws_instance.server_1]
  ami               = var.ami
  instance_type     = var.instance_type
  availability_zone = var.availability_zones[1]
  subnet_id         = aws_subnet.subnet_b.id
  key_name          = var.key_name
  security_groups   = [aws_security_group.basic.id]

  connection {
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file(var.key_path)
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
  tags = {
    Name = "Server 2"
  }
}



resource "aws_elb" "test_load_balancer" {

  subnets         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_groups = [aws_security_group.basic.id]
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


  instances                   = [aws_instance.server_1.id, aws_instance.server_2.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400


  tags = {
    Name = "load-balancer"
  }
}
