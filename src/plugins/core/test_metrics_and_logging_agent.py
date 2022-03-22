import pytest
import constants

from kubernetes import client, config
from kubernetes_pod_utility import get_pod_list
from results_utility import append_result_output
from helper import check_kubernetes_pod_logs

pytestmark = pytest.mark.arcagentstest


def test_metrics_and_logging(env_dict):
    print("Starting metrics agent check.")

    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))

    api_instance = client.CoreV1Api() 
    pod_list = get_pod_list(api_instance, constants.AZURE_ARC_NAMESPACE, 'app.kubernetes.io/component=metrics-agent')
    metrics_agent_pod_name = None
    for pod in pod_list.items:
        if 'metrics-agent' in pod.metadata.name:
            metrics_agent_pod_name = pod.metadata.name
            break
    if not metrics_agent_pod_name:
        pytest.fail("Metrics agent pod was not found.")
    print("Successfully retrieved metrics agent pod name")
    
    # Check metrics agent pod logs
    metrics_logs_list = constants.METRICS_AGENT_LOG_LIST
    if env_dict.get('METRICS_AGENT_LOG_LIST'):  # This environment variable should be provided as comma separated logs that we want to find in the pod logs
        custom_log_list = env_dict.get('METRICS_AGENT_LOG_LIST').split(',')
        for log in custom_log_list:
            metrics_logs_list.append(log.strip())
    append_result_output("Logs List: {}\n".format(metrics_logs_list), env_dict['TEST_METRICS_AND_LOGGING_AGENT_LOG_FILE'])
    
    timeout_seconds = env_dict.get('TIMEOUT')
    check_kubernetes_pod_logs(constants.AZURE_ARC_NAMESPACE, metrics_agent_pod_name, constants.METRICS_AGENT_CONTAINER_NAME,
                              metrics_logs_list, constants.METRICS_AGENT_ERROR_LOG_LIST, env_dict['TEST_METRICS_AND_LOGGING_AGENT_LOG_FILE'], timeout_seconds)
    print("Successfully checked metrics agent pod logs.")

    print("Starting fluent bit check.")
    # Check fluent bit pod logs
    fluentbit_logs_list = constants.FLUENT_BIT_LOG_LIST
    if env_dict.get('FLUENT_BIT_LOG_LIST'):  # This environment variable should be provided as comma separated logs that we want to find in the pod logs
        custom_log_list = env_dict.get('FLUENT_BIT_LOG_LIST').split(',')
        for log in custom_log_list:
            fluentbit_logs_list.append(log.strip())
    append_result_output("Logs List: {}\n".format(fluentbit_logs_list), env_dict['TEST_METRICS_AND_LOGGING_AGENT_LOG_FILE'])

    check_kubernetes_pod_logs(constants.AZURE_ARC_NAMESPACE, metrics_agent_pod_name, constants.FLUENT_BIT_CONTAINER_NAME,
                              fluentbit_logs_list, constants.FLUENT_BIT_ERROR_LOG_LIST, env_dict['TEST_METRICS_AND_LOGGING_AGENT_LOG_FILE'], timeout_seconds)
    print("Successfully checked fluent-bit pod logs.")