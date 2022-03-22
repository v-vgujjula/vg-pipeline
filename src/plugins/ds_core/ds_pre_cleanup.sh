#!/bin/bash
NAMESPACE=$1
# Cleanup azure arc data service artifacts
# Note: not all of these objects will exist in your environment depending on which version of the Arc data controller was installed
# Custom resource definitions (CRD)
kubectl delete crd datacontrollers.arcdata.microsoft.com --ignore-not-found
kubectl delete crd postgresqls.arcdata.microsoft.com --ignore-not-found
kubectl delete crd sqlmanagedinstances.sql.arcdata.microsoft.com --ignore-not-found
kubectl delete crd sqlmanagedinstancerestoretasks.tasks.sql.arcdata.microsoft.com --ignore-not-found
kubectl delete crd dags.sql.arcdata.microsoft.com --ignore-not-found
kubectl delete crd exporttasks.tasks.arcdata.microsoft.com --ignore-not-found
kubectl delete crd monitors.arcdata.microsoft.com --ignore-not-found
# Cluster roles and role bindings
kubectl delete clusterrole arcdataservices-extension --ignore-not-found
kubectl delete clusterrole $NAMESPACE:cr-arc-metricsdc-reader --ignore-not-found
kubectl delete clusterrole $NAMESPACE:cr-arc-dc-watch --ignore-not-found
kubectl delete clusterrole cr-arc-webhook-job --ignore-not-found
# Substitute the name of the namespace the data controller was deployed in into {namespace}.  If unsure, get the name of the mutatingwebhookconfiguration using 'kubectl get clusterrolebinding'
kubectl delete clusterrolebinding $NAMESPACE:crb-arc-metricsdc-reader --ignore-not-found
kubectl delete clusterrolebinding $NAMESPACE:crb-arc-dc-watch --ignore-not-found
kubectl delete clusterrolebinding crb-arc-webhook-job --ignore-not-found
# API services
# Up to May 2021 release
kubectl delete apiservice v1alpha1.arcdata.microsoft.com --ignore-not-found
kubectl delete apiservice v1alpha1.sql.arcdata.microsoft.com --ignore-not-found
# June 2021 release
kubectl delete apiservice v1beta1.arcdata.microsoft.com --ignore-not-found
kubectl delete apiservice v1beta1.sql.arcdata.microsoft.com --ignore-not-found
# GA/July 2021 release
kubectl delete apiservice v1.arcdata.microsoft.com --ignore-not-found
kubectl delete apiservice v1.sql.arcdata.microsoft.com --ignore-not-found
# Substitute the name of the namespace the data controller was deployed in into {namespace}.  If unsure, get the name of the mutatingwebhookconfiguration using 'kubectl get mutatingwebhookconfiguration'
kubectl delete mutatingwebhookconfiguration arcdata.microsoft.com-webhook-$NAMESPACE --ignore-not-found
## if direct connect cleanup 
#kubectl delete ns azure-arc --ignore-not-found
kubectl delete clusterrole $NAMESPACE:cr-arc-dc-watch --ignore-not-found
kubectl delete clusterrole $NAMESPACE:cr-arc-metricsdc-reader --ignore-not-found
kubectl delete clusterrole cr-arc-webhook-job --ignore-not-found
kubectl delete clusterrolebindings $NAMESPACE:crb-arc-dc-watch --ignore-not-found
kubectl delete clusterrolebindings $NAMESPACE:crb-arc-metricsdc-reader --ignore-not-found
kubectl delete clusterrolebindings crb-arc-webhook-job --ignore-not-found
