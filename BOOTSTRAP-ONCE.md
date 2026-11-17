# One-time bootstrap and PostgreSQL secrets

This note covers prerequisites that are **not** automated by this repository. It does not authorize applying infrastructure. The normal CI pipeline still requires protected-environment approval when configured and does not yet order identity and VM Terraform roots automatically.

## Prerequisites

1. Set up the pre-existing Terraform remote-state resource group, Storage Account, container and Azure RBAC for the OIDC principal used by GitHub; the two roots use separate blobs. Configure GitHub OIDC/Azure credentials, Tailscale WIF/policy, required GitHub variables, SSH public key and Cloudflare Tunnel configuration. Verify regional and VM-family quota and available SKU/zone capacity.
2. Apply the reviewed identity root first, then generate a fresh VM-resource plan and apply it only after review/approval. This order is not yet automated by the current independent workflows. For an existing installation, coordinate migration and verify the plans: the Key Vault private endpoint and DNS must work before turning off the existing route. Do not remove working network access first.
3. Key Vault secret administration requires a host with network reachability and DNS resolving the vault hostname to the private endpoint, such as a trusted control manager on the VNet. An Internet-connected workstation or GitHub-hosted runner alone cannot reach a private-only vault. An authorized administrator needs the appropriate Key Vault secret data-plane write role (for example, **Key Vault Secrets Officer**, scoped to the vault), separately from the workload's read-only identity. Allow for RBAC propagation. Review and remove temporary administrative access after enrollment according to policy.

## Set five PostgreSQL secrets once

Perform the following interactively on the trusted host as the authorized administrator. Do **not** paste passwords into shell commands, chat, source control, Terraform variables/state, workflow logs or process arguments. `read -s` hides typing and the CLI receives a root-readable temporary file path, not the password argument. Use a protected host and run as a user trusted to handle these credentials. The temporary files and Azure CLI session are placed in `/dev/shm` and deleted on exit; other privileged users on the host may still access them. Shell variables are not a hardware security boundary.

```bash
# Run in a new interactive Bash session on the trusted VNet-connected host.
ssh azureadmin@vm-workload-01

#  Run Tmux to keep session alive
sudo apt-get update && sudo apt-get install -y tmux
tmux

# Back to session
tmux attach

# Tạo thư mục cấu hình Azure riêng biệt cho phiên làm việc
export AZURE_CONFIG_DIR="/dev/shm/azure-config"
mkdir -m 700 "$AZURE_CONFIG_DIR"

# Thực hiện đăng nhập bằng device code
az login --use-device-code

# Thực hiện cấp quyền cho tài khoản thao tác trên azure vault lần đầu tiên
# ==========================================
# CẤU HÌNH BIẾN ĐẦU VÀO (Điền thông tin của bạn vào đây)
# ==========================================
email_azure_admin="an.huynh@netop.uk"
azure_subscription="8523e1c3-049c-4821-b08d-ba4c677080ac"
resource_group="rg-hybrid-infra-lab-ha"
vault_name="kvhybridinfra26111010"

# ==========================================
# THỰC THI GÁN QUYỀN (Scope ở cấp Resource Group)
# ==========================================
echo "Đang cấu hình gán quyền Key Vault Secrets Officer..."

az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee "$email_azure_admin" \
  --scope "/subscriptions/$azure_subscription/resourceGroups/$resource_group/providers/Microsoft.KeyVault/vaults/$vault_name"

echo "-> Hoàn tất! Hãy đợi khoảng 1-2 phút để Azure đồng bộ quyền trước khi chạy lại script set secret."

# Chạy vòng lặp nhập 5 Secret

for name in \
  postgresql-superuser-password \
  postgresql-replication-password \
  postgresql-app-password \
  postgresql-backup-password \
  postgresql-patroni-api-password; do
  
  echo "----------------------------------------"
  read -r -s -p "Value for $name (at least 24 characters): " value
  printf '\n'
  
  if (( ${#value} < 24 )); then
    unset value
    echo "ERROR: Value is too short (< 24 chars); aborting." >&2
    exit 1
  fi
  
  # Ghi tạm vào file bảo mật trong /dev/shm (RAM-disk)
  echo -n "$value" > /dev/shm/vault_secret_val
  unset value
  
  az keyvault secret set \
    --vault-name "$vault_name" \
    --name "$name" \
    --file "/dev/shm/vault_secret_val" \
    --encoding utf-8 \
    --only-show-errors \
    --output none
    
  rm -f /dev/shm/vault_secret_val
  echo "-> Successfully enrolled: $name"
done

printf '\nPostgreSQL secrets enrolled successfully!\n'

# Kiểm tra sự tồn tại 5 secrets lại bằng lệnh:
az keyvault secret list --vault-name "kvhybridinfra26111010" --output table


```

This creates a **new version** if a name already exists; run it only for first enrollment, not as a deployment step or a credential-rotation procedure. If interrupted, some names may already exist; do not blindly rerun it against a live cluster. Updating vault values alone does not rotate PostgreSQL credentials: active Patroni configuration changes are intentionally refused until a coordinated, tested rotation is performed. Values must be at least 24 characters and must not contain newlines. Keep copies according to your credential-recovery policy; do not send them to an assistant.

## Set Cloudflare API token secrets

```bash
vault_name="kvhybridinfra26111010"
cf_secret_name="cloudflare-api-token"

echo "----------------------------------------"
echo "Kiểm tra trạng thái secret '$cf_secret_name' trong Key Vault '$vault_name'..."

# Kiểm tra xem secret đã tồn tại trên Key Vault hay chưa
if az keyvault secret show --vault-name "$vault_name" --name "$cf_secret_name" --output none 2>/dev/null; then
  echo "⚠️ CẢNH BÁO: Secret '$cf_secret_name' đã tồn tại trên Key Vault."
  read -r -p "Bạn có muốn ghi đè (update) giá trị mới không? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "-> Đã hủy thao tác. Giữ nguyên secret cũ hiện tại."
    exit 0
  fi
fi

# Nhập token mới
echo "----------------------------------------"
read -r -s -p "Paste Cloudflare API Token vào đây: " cf_token_value
printf '\n'

# Kiểm tra độ dài cơ bản
if (( ${#cf_token_value} < 30 )); then
  unset cf_token_value
  echo "ERROR: Cloudflare API Token quá ngắn hoặc không hợp lệ; aborting." >&2
  exit 1
fi

# Ghi tạm vào RAM-disk (/dev/shm) an toàn
echo -n "$cf_token_value" > /dev/shm/vault_secret_val
unset cf_token_value

# Đẩy lên Azure Key Vault
az keyvault secret set \
  --vault-name "$vault_name" \
  --name "$cf_secret_name" \
  --file "/dev/shm/vault_secret_val" \
  --encoding utf-8 \
  --only-show-errors \
  --output none

# Dọn dẹp RAM-disk
rm -f /dev/shm/vault_secret_val
echo "-> Successfully enrolled/updated: $cf_secret_name"

# Kiểm tra lại tổng quan danh sách secrets
echo "----------------------------------------"
echo "Danh sách các secrets hiện có trong Key Vault:"
az keyvault secret list --vault-name "$vault_name" --output table

# Xem value đã nhập cho secret:
az keyvault secret show \
  --vault-name "kvhybridinfra26111010" \
  --name "postgresql-superuser-password" \
  --query "value" \
  --output tsv
```

## Thu hồi quyền thao tác trên Azure Key vault
Thực hiện sau khi đã thao tác xong với Azure Keyvault

```bash
az role assignment delete \
  --role "Key Vault Secrets Officer" \
  --assignee "$email_azure_admin" \
  --scope "/subscriptions/$azure_subscription/resourceGroups/$resource_group/providers/Microsoft.KeyVault/vaults/$vault_name"

#Kiểm tra nhanh quyền đã bị thu hồi chưa nếu không chờ được 2 - 5 phút
# Đăng xuất khỏi phiên hiện tại
az logout

# Tạo lại thư mục tạm và đăng nhập lại để lấy token mới nhất
export AZURE_CONFIG_DIR="/dev/shm/azure-config"
az login --use-device-code

# Xóa thư mục cấu hình tạm:
rm -rf /dev/shm/azure-config

# Done
```

## Key Vault call frequency and costs

The PostgreSQL Ansible role runs `prepare_runtime.py` once **per database member per execution of the role**. Each successful execution obtains one identity token from Azure IMDS and performs **five Key Vault secret GETs**. With three members that is normally 15 secret reads per role run. It is not executed for each application query, WAL archive, database failover or Patroni process restart in the current code. Failed/partial runs and operator/API calls add requests; no global rate cap is implemented. Three-member examples: 10 role runs/day ≈ 4,500 reads/month (30 days); 1,000 runs/day ≈ 450,000 reads/month. These are estimates, not quotas, bills, or guarantees.

The Cloudflare token refresher is separate: each connector reads its Key Vault secret on service start and on a 12-hour timer, plus retries or restarts. Azure Storage operations for Loki, dispatcher state, PostgreSQL WAL and backups are separate from Key Vault operations. Consult current Azure pricing and monitor actual operation counts before setting budgets/alerts; this repository does not establish a spending cap.
