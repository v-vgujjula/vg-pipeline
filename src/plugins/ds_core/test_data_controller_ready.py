import pytest
import constants
import subprocess, os
from kubernetes import client, config

pytestmark = pytest.mark.dsarcagentstest

def test_data_controller_ready(env_dict):
    namespace = env_dict.get('NAMESPACE')
    if not namespace:
        pytest.fail('ERROR: variable NAMESPACE is required.')
    
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))

    try:
        api_instance = client.CustomObjectsApi()
        dc_status = api_instance.get_namespaced_custom_object_status(group="arcdata.microsoft.com", version="v1", plural="datacontrollers", namespace=namespace, name=namespace)
        if dc_status['status']['state'] != 'Ready':
            pytest.fail('ERROR: Data controller readiness failed')
    except Exception as e:
        pytest.fail("ERROR: Data controller readiness failed: " + str(e))

    