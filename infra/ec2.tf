data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "producer_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  key_name = "badr-project-key"

  user_data = <<-EOF
                #!/bin/bash

                while fuser /var/lib/yum/history/lock >/dev/null 2>&1; do sleep 5; done
                yum update -y
                yum install -y git curl python3

                curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR="/usr/local/bin" sh

                APP_DIR="/home/ec2-user/ecommerce-etl-aws"
                rm -rf $APP_DIR
                sudo -u ec2-user git clone https://github.com/BALK-03/ecommerce-etl-aws.git $APP_DIR
                
                cd $APP_DIR
                sudo -u ec2-user /usr/local/bin/uv sync

                VENV_PYTHON="$APP_DIR/.venv/bin/python3"
                PRODUCER_SCRIPT="$APP_DIR/src/producer/producer.py"
                LOG_FILE="/home/ec2-user/producer.log"

                touch $LOG_FILE
                chown ec2-user:ec2-user $LOG_FILE

                CRON_COMMAND="* * * * * $VENV_PYTHON $PRODUCER_SCRIPT >> $LOG_FILE 2>&1"

                echo "$CRON_COMMAND" | sudo -u ec2-user crontab -

                echo "Producer Deployment Complete at $(date)" >> /home/ec2-user/deploy.log
                EOF
              
  tags = {
    Name = "Data-Producer-Node"
  }
}
