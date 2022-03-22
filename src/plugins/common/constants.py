DEFAULT_AZURE_RMENDPOINT = "https://management.azure.com/"

HELM_RELEASE_NAME = 'azure-arc'
HELM_RELEASE_NAMESPACE = 'default'
TIMEOUT = 360
ARC_AGENT_CLEANUP_TIMEOUT = 1500

AZURE_ARC_NAMESPACE = 'azure-arc'

CLUSTER_METADATA_CRD_GROUP = 'arc.azure.com'
CLUSTER_METADATA_CRD_VERSION = 'v1beta1'
CLUSTER_METADATA_CRD_PLURAL = 'connectedclusters'
CLUSTER_METADATA_CRD_NAME = 'clustermetadata'
CLUSTER_METADATA_DICT = {'kubernetes_version': 0, 'total_node_count': 0, 'agent_version': 0}

METRICS_AGENT_LOG_LIST = ["Successfully connected to outputs.http_mdm", "Wrote batch of"]
METRICS_AGENT_ERROR_LOG_LIST = ["Could not resolve", "Could not parse"]
FLUENT_BIT_LOG_LIST = ["[engine] started (pid=1)", "[sp] stream processor started", "[http_mdm] Flush called for id: http_mdm_plugin"]
FLUENT_BIT_ERROR_LOG_LIST = ["[error] [in_tail] read error, check permissions"]
METRICS_AGENT_CONTAINER_NAME = 'metrics-agent'
FLUENT_BIT_CONTAINER_NAME = 'fluent-bit'

CLUSTER_TYPE = 'connectedClusters'
CLUSTER_RP = 'Microsoft.Kubernetes'
OPERATOR_TYPE = 'flux'
HELM_OPERATOR_VERSION = '1.4.0'
REPOSITORY_URL_HOP = 'https://github.com/Azure/arc-helm-demo.git'
CONFIGURATION_NAME_HOP = 'azure-arc-sample'
OPERATOR_SCOPE_HOP = 'cluster'
OPERATOR_NAMESPACE_HOP = 'arc-k8s-demo'
OPERATOR_NAMESPACE_HOP_DEFAULT = 'default'
OPERATOR_INSTANCE_NAME_HOP = 'azure-arc-sample'
OPERATOR_PARAMS_HOP = '--git-readonly --git-path=releases --registry-disable-scanning'
HELM_OPERATOR_PARAMS_HOP = '--set helm.versions=v3'
HELM_OPERATOR_POD_LABEL_LIST = ['arc-k8s-demo', 'helm-operator', 'azure-arc-sample']

REPOSITORY_URL_FOP = 'https://github.com/Azure/arc-k8s-demo.git'
CONFIGURATION_NAME_FOP = 'cluster-config'
OPERATOR_SCOPE_FOP = 'cluster'
OPERATOR_NAMESPACE_FOP = 'cluster-config'
OPERATOR_NAMESPACE_FOP_DEFAULT = 'default'
OPERATOR_INSTANCE_NAME_FOP = 'cluster-config'
OPERATOR_PARAMS_FOP = '--git-readonly --registry-disable-scanning'
FLUX_OPERATOR_POD_LABEL_LIST = ['cluster-config']
FLUX_OPERATOR_RESOURCES_POD_LABEL_LIST = ['arc-k8s-demo']
FLUX_OPERATOR_RESOURCE_NAMESPACE = 'default'
FLUX_OPERATOR_NAMESPACE_RESOURCE_LIST = ['team-a', 'team-b', 'itops']

AZURE_IDENTITY_CERTIFICATE_SECRET = 'azure-identity-certificate'
AZURE_IDENTITY_TOKEN_SECRET = 'identity-request-2a051a512c1afcd426dd4090206c017a675c0f002bf329cc3165a7ba3abdcc97-token'
ARC_CONFIG_NAME = 'azure-clusterconfig'
CLUSTER_IDENTITY_CRD_GROUP = 'clusterconfig.azure.com'
CLUSTER_IDENTITY_CRD_VERSION = 'v1beta1'
CLUSTER_IDENTITY_CRD_PLURAL = 'azureclusteridentityrequests'
CLUSTER_IDENTITY_CRD_NAME = 'identity-request-2a051a512c1afcd426dd4090206c017a675c0f002bf329cc3165a7ba3abdcc97'
IDENTITY_TOKEN_REFERENCE_DICTIONARY = {'dataName': 'cluster-identity-token', 'secretName': 'identity-request-2a051a512c1afcd426dd4090206c017a675c0f002bf329cc3165a7ba3abdcc97-token'}

CLEANUP_NAMESPACE_LIST = ['cluster-config', 'arc-k8s-demo', 'team-a', 'team-b', 'itops']
CLEANUP_DEPLOYMENT_LIST = ['arc-k8s-demo']
CLEANUP_SERVICE_LIST = ['arc-k8s-demo']
