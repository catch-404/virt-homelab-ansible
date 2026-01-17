Ansible project to provision a full virtualized homelab with multiple specialized VMs running different workloads through various container technologies, starting from one base bare metal debian install. The playbook.yml should in itself be a fairly good overview of the general steps, but the gist of it is:
- Prepare BM debian to make it a hypervisor (via libvirt & kvm/qemu)
- Create a base qcow2 debian image with packer
- Clone the base image and create (define) & start the various VMs
- Configure the VMs for their individual workloads

This is mostly meant as my own documentation of the state of my homelab, though theoretically with the right variable changes this could be generalized enough to be used by other people with similar needs. No guarantee on that though and at your own risk.

Very much still a WIP.

Machine and user names are from [The Expanse](https://en.wikipedia.org/wiki/The_Expanse_(TV_series))