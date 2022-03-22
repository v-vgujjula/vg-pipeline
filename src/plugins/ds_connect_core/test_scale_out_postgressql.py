import pytest
import constants
import subprocess, os
from kubernetes import client, config
pytestmark = pytest.mark.dsarcagentstest

@pytest.mark.skipif(not os.getenv('PSQL_SERVERGROUP_NAME'), reason="PSQL_SERVERGROUP_NAME not found")
def test_scale_out_postgressql(env_dict):
    namespace = env_dict.get('NAMESPACE')
    if not namespace:
        pytest.fail('ERROR: variable NAMESPACE is required.')
    
    if env_dict.get('PSQL_SERVERGROUP_NAME'):
        psql_name = env_dict.get('PSQL_SERVERGROUP_NAME')
        # Loading in-cluster kube-config
        try:
            config.load_incluster_config()
        except Exception as e:
            pytest.fail("Error loading the in-cluster config: " + str(e))

        try:
            api_instance = client.CustomObjectsApi()
            postgres_status = api_instance.get_namespaced_custom_object_status(group="arcdata.microsoft.com", version="v1beta1", plural="postgresqls", namespace=namespace, name=psql_name)
            if postgres_status['status']['readyPods'] != '4/4':
                pytest.fail('ERROR: Postgres instance scaleup failed')
        except Exception as e:
            pytest.fail("ERROR: Postgres instance scaleup failed: " + str(e))
    else:
        pytest.fail('WARNING: You have not choosen to create Postgres server to scale up')
