# DDNS Provider

This project consists of an AWS hosted zone and a lambda function which can be used to update my DNS records as my local, consumer IP address changes. It should support both IPv4 and IPv6. The lambda will send an email notify of the IP address change.

The client will be a Debian LXC running on Proxmox, with Wireguard. The tentative plan is to use a bash script to check if the current IP has changed, and then CURL the lambda function to notify of any changes.