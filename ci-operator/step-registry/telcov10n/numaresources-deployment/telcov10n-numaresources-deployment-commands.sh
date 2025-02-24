#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

echo "************ NROP Deployment setup command ************"
# Fix user IDs in a container
~/fix_uid.sh

date +%s > $SHARED_DIR/start_time

#Environment variables required
SSH_PKEY_PATH=/var/run/ci-key/cikey
SSH_PKEY=~/key
cp $SSH_PKEY_PATH $SSH_PKEY
chmod 600 $SSH_PKEY
BASTION_IP="$(cat /var/run/bastion-ip/bastionip)"
BASTION_USER="$(cat /var/run/bastion-user/bastionuser)"
HYPERV_IP="$(cat /var/run/up-hv-ip/uphvip)"
COMMON_SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ServerAliveInterval=30"

source $SHARED_DIR/main.env


# Copy automation repo to local SHARED_DIR
echo "Copy automation repo to local $SHARED_DIR"
mkdir $SHARED_DIR/repos
ssh -i $SSH_PKEY $COMMON_SSH_ARGS ${BASTION_USER}@${BASTION_IP} \
    "tar --exclude='.git' -czf - -C /home/${BASTION_USER} ansible-automation" | tar -xzf - -C $SHARED_DIR/repos/


# Install ansible dependencies
cd $SHARED_DIR/repos/ansible-automation
pip3 install dnspython netaddr
ansible-galaxy collection install -r ansible-requirements.yaml


# Install certificates required for internal registries
export ANSIBLE_CONFIG="${SHARED_DIR}"/repos/ansible-automation/ansible.cfg
ansible-playbook -vv "${SHARED_DIR}"/repos/ansible-automation/playbooks/apply_registry_certs.yml -e kubeconfig="${SHARED_DIR}"/mgmt-kubeconfig -c local


# Install NUMAResources Operator Playbook
ansible-playbook -vv "${SHARED_DIR}"/repos/ansible-automation/playbooks/install_nrop.yaml -e hosted_kubeconfig="${SHARED_DIR}"/kubeconfig \
-e mgmt_kubeconfig="${SHARED_DIR}"/mgmt-kubeconfig -e install_sources=${T5CI_NROP_SOURCE}