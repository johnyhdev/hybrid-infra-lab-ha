# Security Exceptions

## CKV_AZURE_50

### Finding

Checkov:

CKV_AZURE_50 — Ensure Virtual Machine Extensions are not Installed

### Status

Accepted Exception

### Reason

The lab intentionally does not use Azure VM Extensions
for configuration management.

Configuration management is handled separately through
the planned Ansible management workflow.

### Risk

Azure VM Extensions can execute code inside the virtual machine.
Allowing arbitrary VM Extensions would increase the VM's
configuration and execution surface.

### Compensating Control

The VM uses:

- Azure VM Agent
- Azure Run Command / management plane
- Ansible for configuration management
- No public IP
- Restricted NSG
- SSH password authentication disabled

### Decision

CKV_AZURE_50 is intentionally excluded from the Checkov gate.

This exception must be reviewed if the infrastructure architecture
changes and VM Extensions are introduced.