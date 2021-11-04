# Trabajando con ECS y CodeDeploy

## Introducción
Vamos a crear un nuevo cluster de ECS, task definition y service mediante terraform.
Utilizar una estructura de directorios en el proyecto, que habilite a utilizar el mismo codigo en varios ambientes (staging|production).
Tener en cuenta que educate no permite el uso de AMI's del marketplace y esto limita a solo poder usar fargate como tipo de computo para cluster/task/service.

>**Nota 1:** Taggear correctamente los recursos.

>**Nota 2:** Atención a los nombres de los recursos de ejemplo.

>**Nota 3:** Referenciar los recursos mediante outputs de modulos. Ej. `module.web_server.instance_ip_addr`

## Despliegue de recursos de ECS
**Prerequisitos** Crear VPC `<grupo>-vpc-tf-ecs` con CIDR **10.10.0.0/16**, 2 subnets **10.10.10.0/24** y **10.10.20.0/24** (distinta AZ) y security group con regla de inbound source ```<grupo>-sg-practico-ecs-80``` **0.0.0.0/0 tcp 80**.

### *Ejemplos de uso:*

```
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}
```

```
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}
```

```
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}
```

### 1. **Cluster:** Revisar documentación de Terraform para el tipo de recurso *Cluster* [aws_ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster).

### *Ejemplo de uso:*

```
resource "aws_ecs_cluster" "foo" {
  name = ""

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
  tags = {
    Name = "ort-"
  }
}
```

### 2. **Task definition:** Revisar documentación de Terraform para el tipo de recurso *Task definition* [aws_ecs_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition).

### *Ejemplo de uso:*

```
resource "aws_ecs_task_definition" "service" {
  family = "service"
  container_definitions = jsonencode([
    {
      name      = "first"
      image     = "service-first"
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    },
    {
      name      = "second"
      image     = "service-second"
      cpu       = 10
      memory    = 256
      essential = true
      portMappings = [
        {
          containerPort = 443
          hostPort      = 443
        }
      ]
    }
  ])

  volume {
    name      = "service-storage"
    host_path = "/ecs/service-storage"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}
```

### 3. **Service** Revisar documentación de Terraform para el tipo de recurso *Service* [aws_ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service).

### *Ejemplo de uso:*

```
resource "aws_ecs_service" "mongo" {
  name            = "mongodb"
  cluster         = aws_ecs_cluster.foo.id
  task_definition = aws_ecs_task_definition.mongo.arn
  desired_count   = 3
  iam_role        = aws_iam_role.foo.arn
  depends_on      = [aws_iam_role_policy.foo]

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.foo.arn
    container_name   = "mongo"
    container_port   = 8080
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}
```

## Despliegue de aplicación con CodeDeploy

### 1. **Application:** Revisar documentación de Terraform para el tipo de recurso *Application* [aws_codedeploy_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_app).

### *Ejemplo de uso:*

```
resource "aws_codedeploy_app" "example" {
  compute_platform = "ECS"
  name             = "example"
}
```

### 1. **Deployment Group:** Revisar documentación de Terraform para el tipo de recurso *Deployment Group* [aws_codedeploy_deployment_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group).

### *Ejemplo de uso:*

```
resource "aws_codedeploy_app" "example" {
  compute_platform = "ECS"
  name             = "example"
}

resource "aws_codedeploy_deployment_group" "example" {
  app_name               = aws_codedeploy_app.example.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "example"
  service_role_arn       = aws_iam_role.example.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.example.name
    service_name = aws_ecs_service.example.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.example.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
}
```