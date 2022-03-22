FROM python:3.6

RUN pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org pytest kubernetes azure.identity msrestazure azure-mgmt-hybridkubernetes

RUN /usr/bin/curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl  \
    &&  mv ./kubectl /usr/local/bin/kubectl

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash \
    && helm version

ARG SONOBUOY_VERSION

RUN curl -L https://github.com/vmware-tanzu/sonobuoy/releases/download/v${SONOBUOY_VERSION}/sonobuoy_${SONOBUOY_VERSION}_linux_amd64.tar.gz --output /bin/sonobuoy.tar.gz

RUN ["tar", "-xzf", "/bin/sonobuoy.tar.gz", "-C", "/bin/"]

COPY ./arc_agent_cleanup/arc_agent_cleanup.sh /
COPY ./arc_agent_cleanup/cleanup.py /
COPY ./common/results_utility.py /
COPY ./common/constants.py /
COPY ./common/kubernetes_namespace_utility.py /
COPY ./common/helm_utility.py /
COPY ./common/kubernetes_pod_utility.py  /
COPY ./common/connected_cluster_utility.py /
COPY ./common/arm_rest_utility.py /
COPY ./common/setup_failure_handler.py /

RUN ["chmod", "+x", "/arc_agent_cleanup.sh"]

ENTRYPOINT ["./arc_agent_cleanup.sh"]

