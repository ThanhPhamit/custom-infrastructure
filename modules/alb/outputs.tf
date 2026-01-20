output "lb_listener_http_arn" {
  value = aws_lb_listener.http_prod.arn
}

output "lb_listener_http_prod_arn" {
  value = aws_lb_listener.http_prod.arn
}

output "lb_listener_http_test_arn" {
  value = aws_lb_listener.http_test.arn
}

output "lb_listener_http_redirect_arn" {
  value = aws_lb_listener.http_redirect.arn
}

output "alb_security_group_id" {
  value = aws_security_group.security_group.id
}

output "alb_arn_suffix" {
  value = aws_lb.alb.arn_suffix
}

output "id" {
  value = aws_lb.alb.id
}

output "domain" {
  value = aws_lb.alb.dns_name
}