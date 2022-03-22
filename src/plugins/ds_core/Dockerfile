FROM mcr.microsoft.com/azure-cli:2.29.0
RUN pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org pytest pytest-xdist filelock junit_xml kubernetes azure.identity
RUN pip install azure.mgmt.resource
RUN apk add gnupg ca-certificates curl wget jq
RUN apk update
## az arcdata installation
RUN az extension add --upgrade --name connectedk8s --yes --debug
RUN az extension add --upgrade --name k8s-configuration --yes --debug
RUN az extension add --upgrade --name k8s-extension --yes --debug
RUN az extension add --upgrade --name customlocation --yes --debug
RUN az extension add --upgrade --name arcdata --yes --debug
RUN apk update
RUN /usr/bin/curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl  \
    &&  mv ./kubectl /usr/local/bin/kubectl

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash \
    && helm version

COPY ./ds_core/arc_ds_conformance.sh /
COPY ./ds_core/ds_pre_cleanup.sh /
COPY ./ds_core/pytest.ini /conformancetests/
COPY ./ds_core/conftest.py /conformancetests/
COPY ./ds_core/ds_setup_failure_handler.py /
COPY ./common /conformancetests/
## Ds tests
COPY ./ds_core/test_check_namespace_existence.py /conformancetests/
COPY ./ds_core/test_check_pod_existence.py /conformancetests/
COPY ./ds_core/test_check_pv_existence.py /conformancetests/
COPY ./ds_core/test_create_sql_mi.py /conformancetests/
COPY ./ds_core/test_data_controller_ready.py /conformancetests/
COPY ./ds_core/test_create_postgressql.py /conformancetests/
COPY ./ds_core/test_scale_out_postgressql.py /conformancetests/
COPY ./ds_core/test_ds_indirect_cleanup.py /conformancetests/

RUN ["chmod", "+x", "ds_pre_cleanup.sh"]
RUN ["chmod", "+x", "arc_ds_conformance.sh"]
RUN sed -i -e 's/\r$//' arc_ds_conformance.sh
RUN sed -i -e 's/\r$//' ds_pre_cleanup.sh
ENTRYPOINT ["/arc_ds_conformance.sh"]
