import pytest
import constants
import subprocess, os
from subprocess import Popen, PIPE, STDOUT
from kubernetes import client, config
from kubernetes_namespace_utility import list_namespace

pytestmark = pytest.mark.dsarcagentstest

def test_check_azure_arc_namespace_existence(env_dict):
    connected_namespace = "azure-arc"
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

    if len(ns_collection_list) <= 0 or  connected_namespace not in ns_collection_list:
        pytest.fail('ERROR: Check azure-arc namespace existence failed')
