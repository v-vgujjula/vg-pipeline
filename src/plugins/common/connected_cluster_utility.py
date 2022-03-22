import pytest

from azure.mgmt.hybridkubernetes import ConnectedKubernetesClient


# This function returns the python client to interact with resources under the namespace 'Microsoft.Kubernetes'
def get_connected_kubernetes_client(credential, subscription_id, base_url=None, credential_scopes=None):
    return ConnectedKubernetesClient(credential, subscription_id, base_url, credential_scopes=credential_scopes)


# This function returns the python client to interact with the connected cluster resource
def get_connected_cluster_client(credential, subscription_id, base_url=None, credential_scopes=None):
    try:
        return get_connected_kubernetes_client(credential, subscription_id, base_url, credential_scopes=credential_scopes).connected_cluster
    except Exception as e:
        pytest.fail("Error occured while creating connected cluster client: " + str(e))


# This function returns a connected cluster object present in a given resource group
def get_connected_cluster(cc_client, resource_group_name, cluster_name):
    try:
        return cc_client.get(resource_group_name, cluster_name)
    except Exception as e:
        pytest.fail("Error occured while fetching the connected cluster resource: " + str(e))

# This function deletes a connected cluster resource present in a given resource group
def delete_connected_cluster(cc_client, resource_group_name, cluster_name):
    try:
        cc_client.begin_delete(resource_group_name, cluster_name)
    except Exception as e:
        pytest.fail("Error occured while deleting the connected cluster resource: " + str(e))