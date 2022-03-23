FROM ubuntu:18.04
## python 3.6 installation
RUN apt-get update \
  && apt-get install -y python3-pip python3-dev \
  && cd /usr/local/bin \
  && ln -s /usr/bin/python3 python \
  && pip3 --no-cache-dir install --upgrade pip \
  && rm -rf /var/lib/apt/lists/*
RUN apt-get update
RUN pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org pytest pytest-xdist filelock junit_xml kubernetes azure.identity
RUN pip install azure.mgmt.resource
## az arcdata installation
RUN apt-get install gnupg ca-certificates curl wget tar jq software-properties-common apt-transport-https lsb-release -y
RUN apt-get update
RUN curl -sSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN apt-add-repository https://packages.microsoft.com/ubuntu/18.04/prod
RUN apt-get update
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash
RUN az extension add --name connectedk8s --yes --debug
RUN az extension add --name k8s-configuration --yes --debug
RUN az extension add --name k8s-extension --yes --debug
RUN az extension add --name customlocation --yes --debug
RUN az extension add --name arcdata --yes --debug
RUN apt-get update
RUN /usr/bin/curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl  \
    &&  mv ./kubectl /usr/local/bin/kubectl

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash \
    && helm version

ARG SONOBUOY_VERSION
RUN curl -L https://github.com/vmware-tanzu/sonobuoy/releases/download/v${SONOBUOY_VERSION}/sonobuoy_${SONOBUOY_VERSION}_linux_amd64.tar.gz --output /bin/sonobuoy.tar.gz
RUN echo $(https://github.com/vmware-tanzu/sonobuoy/releases/download/v${SONOBUOY_VERSION}/sonobuoy_${SONOBUOY_VERSION}_linux_amd64.tar.gz)
RUN echo $(ls -l /bin/sonobuoy.tar.gz)
RUN echo $(file /bin/sonobuoy.tar.gz)
RUN ["tar", "-xzf", "/bin/sonobuoy.tar.gz", "-C", "/bin/"]

COPY ./ds_connect_core/arc_ds_connect_conformance.sh /
COPY ./ds_connect_core/ds_pre_cleanup.sh /
COPY ./ds_connect_core/pytest.ini /conformancetests/
COPY ./ds_connect_core/conftest.py /conformancetests/
COPY ./ds_connect_core/ds_setup_failure_handler.py /
COPY ./common /conformancetests/
## Ds connect tests
COPY ./ds_connect_core/ds_connect_constants.py /conformancetests/
COPY ./ds_connect_core/test_check_namespace_existence.py /conformancetests/
COPY ./ds_connect_core/test_check_pod_existence.py /conformancetests/
COPY ./ds_connect_core/test_check_pv_existence.py /conformancetests/
COPY ./ds_connect_core/test_ds_direct_cleanup.py /conformancetests/
COPY ./ds_connect_core/test_check_kubernetes_extension_arm.py /conformancetests/
COPY ./ds_connect_core/test_check_datacontroller_arm.py /conformancetests/
COPY ./ds_connect_core/test_check_customlocation_arm.py /conformancetests/
COPY ./ds_connect_core/test_check_connected_cluster_arm.py /conformancetests/
COPY ./ds_connect_core/test_check_azure_arc_namespace_existence.py /conformancetests/
COPY ./ds_connect_core/test_data_controller_ready.py /conformancetests/
COPY ./ds_connect_core/test_create_sql_mi.py /conformancetests/
## To do will add these below tests once postgres sql is ready from az cli
#COPY ./ds_connect_core/test_create_postgressql.py /conformancetests/
#COPY ./ds_connect_core/test_scale_out_postgressql.py /conformancetests/

RUN ["chmod", "+x", "ds_pre_cleanup.sh"]
RUN ["chmod", "+x", "arc_ds_connect_conformance.sh"]
RUN sed -i -e 's/\r$//' arc_ds_connect_conformance.sh
RUN sed -i -e 's/\r$//' ds_pre_cleanup.sh
ENTRYPOINT ["/arc_ds_connect_conformance.sh"]
