import pytest
import constants
import subprocess, os
from subprocess import Popen, PIPE, STDOUT
from kubernetes import client, config

pytestmark = pytest.mark.dsarcagentstest

def test_check_pod_existence(env_dict):
    namespace = env_dict.get('CUSTOM_LOCATION_NAME')
    if not namespace:
        pytest.fail('ERROR: variable CUSTOM_LOCATION_NAME is required.')
    
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))
        
    api_instance = client.CoreV1Api()
    try:
        pod_list = api_instance.list_namespaced_pod(namespace)
    except Exception as e:
        pytest.fail("Error loading the pod list: " + str(e))
        
    for pod in pod_list.items:
        if not "arc-bootstrap-job-" in pod.metadata.generate_name:
            pod_status_info = pod.status.phase
            print("each pod --> pod_status_info")
            if pod_status_info != "Running":
                pytest.fail('ERROR: Check pod existence failed')
    

    