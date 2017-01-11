/* invoke the lambda every 15 minutes */
resource "aws_cloudwatch_event_rule" "invoke_lambda_periodic" {
    name = "invoke_lambda_periodic"
    schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "invoke_lambda_periodic" {
    rule = "${aws_cloudwatch_event_rule.invoke_lambda_periodic.name}"
    target_id = "netscaler_autoscale_lambda"
    arn = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_lambda" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.netscaler_autoscale_lambda.arn}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.invoke_lambda_periodic.arn}"
}
