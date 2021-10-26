# magento_terraform

Terraform manifests to describe AWS infrastructure for setting up Magento stack in ASG with Nginx & Varnish running on separate servers (ASGs). Ansible is used for CM.

Please export domain=yourdomain.com in ansible dir before running main.yml that first setups Magento on NGINX and then Varnish server.
