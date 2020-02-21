# Jaeger Tracing Demo

This folder contains a demo setup that illustrates how an OpenTracing-instrumented process can integrate with the traces produced by Istio's envoy proxies.

It consists of 2 components:

* backend - This is a web server written in Go, instrumented with the OpenTracing APIs.
* frontend - This is nginx that serves as a reverse proxy to the backend.

To deploy this demo,

* Install OpenShift Service Mesh by performing one of the following:
	* Executing the `install_service_mesh.sh` script.

	or
	
	* Performing a manual installation by following the instructions in the [OpenShift docs](https://docs.openshift.com/container-platform/4.3/service_mesh/service_mesh_install/installing-ossm.html). When you get to the step where you create the `ServiceMeshMemberRoll`, include the `demo` project as a member.
* Deploy the frontend and backend by executing the `deploy.sh` script.
* After the deployment is completed, send requests to the frontend by executing the `curl.sh` script.

To view the traces,

* Open the `kiali` web console.
* Select the `Distributed Tracing` tab in the left panel.
* Set the Namespace field to `demo` and the Service to `frontend`.
* Click on `Search Traces`.
