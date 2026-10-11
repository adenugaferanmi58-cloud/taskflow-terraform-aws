# 1. Generated password (letters and digits only, so it is safe inside a connection URL)
resource "random_password" "db" {
  length  = 24
  special = false
}

# 2. Subnet group: RDS may only use these (private) subnets
resource "aws_db_subnet_group" "main" {
  name       = "taskflow-db-subnets"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = { Name = "taskflow-db-subnets" }
}

# 3. The database
resource "aws_db_instance" "main" {
  identifier     = "taskflow-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_encrypted = true

  db_name  = "taskflow"
  username = "taskflow_admin"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false # single AZ to keep costs low while learning

  skip_final_snapshot = true # learning only: lets terraform destroy remove it cleanly

  tags = { Name = "taskflow-db" }
}

# 4. Secret holding the connection details
resource "aws_secretsmanager_secret" "db" {
  name                    = "taskflow/db-credentials"
  recovery_window_in_days = 0 # delete immediately on destroy so we can rebuild with the same name
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}