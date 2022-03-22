import json
import os
import pytest
import sys
import time
import subprocess
from kubernetes import client, config
from msrestazure import azure_cloud

import constants
from arm_rest_utility import fetch_aad_token_credentials
from connected_cluster_utility import get_connected_cluster_client, delete_connected_cluster
from helm_utility import list_helm_release, delete_helm_release
from kubernetes_namespace_utility import list_namespace
from kubernetes_pod_utility import get_pod_list, get_pod_logs
from results_utility import append_result_output

def test_arc_agent_cleanup():

  # Fetching environment variables.
  tenant_id = os.getenv('TENANT_ID')
  if not tenant_id:
    pytest.fail('ERROR: variable TENANT_ID is required.')

  subscription_id = os.getenv('SUBSCRIPTION_ID')
  if not subscription_id:
    pytest.fail('ERROR: variable SUBSCRIPTION_ID is required.')

  resource_group = os.getenv('RESOURCE_GROUP')
  if not resource_group:
    pytest.fail('ERROR: variable RESOURCE_GROUP is required.')

  cluster_name = os.getenv('CLUSTER_NAME')
  if not cluster_name:
    pytest.fail('ERROR: variable CLUSTER_NAME is required.')

  client_id = os.getenv('CLIENT_ID')
  if not client_id:
    pytest.fail('ERROR: variable CLIENT_ID is required.')

  client_secret = os.getenv('CLIENT_SECRET')
  if not client_secret:
    pytest.fail('ERROR: variable CLIENT_SECRET is required.')

  cleanup_timeout = int(os.getenv('CLEANUP_TIMEOUT')) if os.getenv('CLEANUP_TIMEOUT') else constants.ARC_AGENT_CLEANUP_TIMEOUT
  azure_rmendpoint = os.getenv('AZURE_RM_ENDPOINT') if os.getenv('AZURE_RM_ENDPOINT') else constants.DEFAULT_AZURE_RMENDPOINT
  plugin_result_file = '/tmp/results/cleanupLogs'

  # Loading in-cluster kube config
  try:
    config.load_incluster_config()
  except Exception as e:
    pytest.fail("Error loading the in-cluster config: " + str(e))

  # Checking presence of sonobuoy namespace
  sonobuoy_namespace_present = False
  api_instance = client.CoreV1Api()
  namespace_list = list_namespace(api_instance)
  for ns in namespace_list.items:
    if ns.metadata.name.lower() == "sonobuoy":
      sonobuoy_namespace_present = True
      break

  # Checking status of azure-arc plugins
  cmd_sonobuoy_status = ["sonobuoy", "status", "--json"]
  timeout = time.time() + cleanup_timeout
  status_check_complete = True

  if sonobuoy_namespace_present:
    print("Polling on the azure-arc plugin statuses.")
    while True:
      # Calling 'sonobuoy status' command
      response_sonobuoy_status = subprocess.Popen(cmd_sonobuoy_status, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
      output_sonobuoy_status, error_sonobuoy_status = response_sonobuoy_status.communicate()
      if response_sonobuoy_status.returncode != 0:
        pytest.fail("Unable to fetch sonobuoy plugin status: " + error_sonobuoy_status.decode("ascii"))

      # Parsing the json response to check plugin status
      sonobuoy_status = output_sonobuoy_status.decode("ascii")
      sonobuoy_status_json = json.loads(sonobuoy_status)
      plugin_list = sonobuoy_status_json.get('plugins')
      for plugin in plugin_list:
        plugin_name = plugin.get('plugin')
        plugin_status = plugin.get('status')
        if (plugin_name.startswith("azure-arc") and plugin_name != "azure-arc-agent-cleanup" and plugin_status != "complete"):
          status_check_complete = False
          break

      # Checking exit condition
      if status_check_complete:
        break

      # Checking cleanup timeout
      if time.time() > timeout:
        append_result_output("Sonobuoy plugins status: {}".format(sonobuoy_status_json), plugin_result_file)
        pytest.fail("The watch on azure-arc plugin status has timed out.")
      
      # Sleep for 60 sec
      status_check_complete = True
      time.sleep(60)

  # Checking if helm release azure-arc is installed
  if constants.HELM_RELEASE_NAME in list_helm_release(constants.HELM_RELEASE_NAMESPACE):
    # Collecting all arc-agent pod logs
    print("Collecting azure-arc agent pod logs.")
    pod_list = get_pod_list(api_instance, constants.AZURE_ARC_NAMESPACE)
    for pod in pod_list.items:
      pod_name = pod.metadata.name
      for container in pod.spec.containers:
        container_name = container.name
        log = get_pod_logs(api_instance, constants.AZURE_ARC_NAMESPACE, pod_name, container_name)
        append_result_output("Logs for the pod {} and container {}:\n".format(pod_name, container_name), "/tmp/results/{}-{}".format(pod_name, container_name))
        append_result_output("{}\n".format(log), "/tmp/results/{}-{}".format(pod_name, container_name))

    # Fetch aad token credentials from spn
    cloud = azure_cloud.get_cloud_from_metadata_endpoint(azure_rmendpoint)
    credential = fetch_aad_token_credentials(tenant_id, client_id, client_secret, cloud.endpoints.active_directory)
    
    # Deleting cc resource
    print("Deleting connected cluster resource.")
    cc_client = get_connected_cluster_client(credential, subscription_id, base_url=cloud.endpoints.resource_manager, credential_scopes=[cloud.endpoints.resource_manager + "/.default"])
    delete_connected_cluster(cc_client, resource_group, cluster_name)

    # Deleting 'azure-arc' helm release
    print("Deleting 'azure-arc' helm release")
    delete_helm_release(constants.HELM_RELEASE_NAME, constants.HELM_RELEASE_NAMESPACE)
    
