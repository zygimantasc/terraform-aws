import requests
import boto3

def send_cloudwatch_metric(metric_name, metric_value):
    cloudwatch = boto3.client('cloudwatch')
    namespace = 'LambdaCustomHC'

    # Send the custom metric to CloudWatch
    response = cloudwatch.put_metric_data(
        Namespace=namespace,
        MetricData=[
            {
                'MetricName': metric_name,
                'Value': metric_value,
                'Unit': 'Count',
                'StorageResolution': 1
            },
        ]
    )

def check_url(url, cloudwatch_target, target_string):
    try:
        # Make the HTTP request
        response = requests.get(url, timeout=10)
        response_text = response.text

        # Check if the target string is present in the response
        if target_string in response_text:
            send_cloudwatch_metric(cloudwatch_target, 1)
            return f"URL: {url} - OK"
        else:
            send_cloudwatch_metric(cloudwatch_target, 0)
            return f"URL: {url} - Unexpected Response."
    except Exception as e:
        send_cloudwatch_metric(cloudwatch_target, 0)
        return f"URL: {url} - An error occurred: {str(e)}"
        

def lambda_handler(event, context):

    # String to check in the HTTP response
    target_string = "<target string>"  # Replace with your target string

    results = []

    result = check_url("http://10.0.0.1:8888/", "test_node_1_availability", target_string)
    results.append(result)
    
    result = check_url("http://10.0.0.2:8888/", "test_node_2_availability", target_string)
    results.append(result)
    
    result = check_url("http://10.0.0.3:8888/", "test_node_3_availability", target_string)
    results.append(result)
    
    return {
        "statusCode": 200,
        "body": "\n".join(results)
    }
