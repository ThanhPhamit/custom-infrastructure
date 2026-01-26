[
  {
    "name": "${container_name}",
    "image": "${repository_url}:latest",
    "essential": true,
    "memory": ${memory_size},
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "${aws_region}",
        "awslogs-stream-prefix": "${container_name}",
        "awslogs-group": "/ecs_server/${app_name}/${container_name}"
      }
    },
    "command": [
      "node",
      "dist/main"
    ],
    "environment": [],
    "secrets": [],
    "portMappings": [
      {
        "containerPort": ${container_port},
        "hostPort": ${container_port}
      }
    ],
    "healthCheck": {
      "command": [
        "CMD-SHELL",
        "curl -f http://localhost:${container_port}${health_check_path} || exit 1"
      ],
      "interval": 10,
      "retries": 10,
      "startPeriod": 10,
      "timeout": 5
    }
  }
]