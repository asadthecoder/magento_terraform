# magento_terraform
Terraform manifests to describe AWS infrastructure for setting up Magento stack in ASG with Nginx & Varnish running on separate servers (ASGs).
Ansible is used for CM. 


Please export domain=yourdomain.com  in ansible dir before running playbooks.
Each server has its own playbook namely magento.yml and varnish.yml. Please first run magento.yml as it will output varnish.vcl file to be used by Varnish Server. Next run
varnish.yml

