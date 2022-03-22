import pytest
import constants
import subprocess, os
from subprocess import Popen, PIPE, STDOUT
from kubernetes import client, config

pytestmark = pytest.mark.dsarcagentstest

def test_check_pv_existence(env_dict):
    namespace = env_dict.get('NAMESPACE')
    if not namespace:
        pytest.fail('ERROR: variable NAMESPACE is required.')
    
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))
    
    api_instance = client.CoreV1Api()
    volumes_list = api_instance.list_persistent_volume().to_dict()['items']

    if not volumes_list:
        pytest.fail('ERROR: check PV existence failed')
    else:
        for each_vol in volumes_list:
            if each_vol['spec']['claim_ref']['namespace'] == namespace:
                if each_vol['status']['phase'] != 'Bound':
                    pytest.fail('ERROR: check PV existence failed')

    