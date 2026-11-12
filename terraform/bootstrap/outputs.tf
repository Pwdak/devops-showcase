output "tf_state_bucket" {
  description = "-> variable GitHub TF_STATE_BUCKET"
  value       = aws_s3_bucket.tfstate.bucket
}

output "tf_lock_table" {
  description = "Table DynamoDB de verrouillage"
  value       = aws_dynamodb_table.lock.name
}

output "ecr_repository_url" {
  description = "URL du dépôt ECR"
  value       = aws_ecr_repository.app.repository_url
}

output "github_actions_role_arn" {
  description = "-> variable GitHub AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}
