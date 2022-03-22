import pytest
import constants
import subprocess, os
from subprocess import Popen, PIPE, STDOUT
import time
from kubernetes import client,config
config.load_kube_config()

pytestmark = pytest.mark.dsarcagentstest    
@pytest.mark.trylast
@pytest.mark.skipif(os.getenv('SKIP_CLEANUP') == "true", reason="Clean up not requested")
def test_ds_indirect_cleanup(env_dict):
    namespace = env_dict.get('NAMESPACE')
    if not namespace:
        pytest.fail('ERROR: variable NAMESPACE is required.')
    
    print("u are at delete ns")
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))
    
    v1 = client.CoreV1Api()
    try:
        for ns in v1.list_namespace().items:
            if ns.metadata.name == namespace:
                print(ns.metadata.name)
                ns_status=v1.delete_namespace(namespace)
                break

    except Exception as e:
        pytest.fail("Unable to delete the requested namespace : " + str(e))
