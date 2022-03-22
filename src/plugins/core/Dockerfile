FROM mcr.microsoft.com/azure-cli:2.29.0

RUN pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org pytest pytest-xdist filelock junit_xml kubernetes==11.0.0 azure.identity msrestazure azure-mgmt-hybridkubernetes azure-mgmt-kubernetesconfiguration==1.0.0b1

RUN az extension add --name connectedk8s --yes --debug

RUN /usr/bin/curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl  \
    &&  mv ./kubectl /usr/local/bin/kubectl

COPY ./core/arc_conformance.sh /
COPY ./core/pytest.ini /conformancetests/
COPY ./core/conftest.py /conformancetests/
COPY ./core/helper.py /conformancetests/
COPY ./core/test_connected_cluster_metadata.py /conformancetests/
COPY ./core/test_identity_operator.py /conformancetests/
COPY ./core/test_metrics_and_logging_agent.py /conformancetests/
COPY ./core/test_kubernetes_config_flux_operator.py /conformancetests/
COPY ./core/test_kubernetes_config_helm_operator.py /conformancetests/
COPY ./common/setup_failure_handler.py /

COPY ./common/ /conformancetests/

RUN ["chmod", "+x", "/arc_conformance.sh"]
ENTRYPOINT ["./arc_conformance.sh"]

