import pytest
import constants
import subprocess, os
from subprocess import Popen, PIPE, STDOUT
from kubernetes import client, config
from kubernetes_namespace_utility import list_namespace

pytestmark = pytest.mark.dsarcagentstest

def test_check_namespace_existence(env_dict):
    namespace = env_dict.get('NAMESPACE')
    if not namespace:
        pytest.fail('ERROR: variable NAMESPACE is required.')
    
    # Loading in-cluster kube-config
    try:
        config.load_incluster_config()
    except Exception as e:
        pytest.fail("Error loading the in-cluster config: " + str(e))
    
    api_instance = client.CoreV1Api()
    ns_collection_list = []
    namespace_list = list_namespace(api_instance)
    for ns in namespace_list.items:
        namespace_name = ns.metadata.name
        ns_collection_list.append(namespace_name)

    if len(ns_collection_list) <= 0 or  namespace not in ns_collection_list:
        pytest.fail('ERROR: Check namespace existence failed')
