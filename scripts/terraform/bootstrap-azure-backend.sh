#!/usr/bin/env bash
# ============================================================================
# Bootstrap Azure Storage backend for Terraform state.
#
# Crée :
#   - Resource Group dédié (rg-cia-gr46-tfstate, francecentral)
#   - Storage Account (ciagr46tfstate, Standard_LRS, TLS 1.2 min)
#   - Container Blob (tfstate) avec versioning + soft-delete 30 jours
#
# Idempotent : peut être relancé sans dégât (utilise --query pour check).
#
# Pré-requis : az CLI loggé (`az login`) sur la bonne subscription Students.
# Durée : ~2 minutes.
#
# Usage :
#   bash scripts/terraform/bootstrap-azure-backend.sh
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# Configuration (alignée avec terraform/backend.tf.example)
# ----------------------------------------------------------------------------
RG="rg-cia-gr46-tfstate"
LOCATION="francecentral"          # région autorisée Students
SA="ciagr46tfstate"               # storage account (3-24 chars, lowercase, unique global)
CONTAINER="tfstate"
SOFT_DELETE_DAYS=30

# ----------------------------------------------------------------------------
# Pré-flight
# ----------------------------------------------------------------------------
echo "▶  Pré-flight checks..."
if ! command -v az >/dev/null 2>&1; then
    echo "❌ az CLI not installed. Install: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

CURRENT_SUB=$(az account show --query "name" -o tsv 2>/dev/null || echo "")
if [[ -z "$CURRENT_SUB" ]]; then
    echo "❌ Not logged in to Azure. Run: az login"
    exit 1
fi
echo "   ✓ az CLI ready, subscription: $CURRENT_SUB"

# ----------------------------------------------------------------------------
# 1. Resource Group
# ----------------------------------------------------------------------------
echo ""
echo "▶  [1/4] Resource Group '$RG' ($LOCATION)..."
if az group show -n "$RG" >/dev/null 2>&1; then
    echo "   = RG already exists, skipping creation"
else
    az group create -n "$RG" -l "$LOCATION" \
        --tags project=CIA group=GR46 purpose=tfstate managed-by=bootstrap-script \
        -o none
    echo "   ✓ RG created"
fi

# ----------------------------------------------------------------------------
# 2. Storage Account
# ----------------------------------------------------------------------------
echo ""
echo "▶  [2/4] Storage Account '$SA'..."
if az storage account show -n "$SA" -g "$RG" >/dev/null 2>&1; then
    echo "   = SA already exists, skipping creation"
else
    az storage account create \
        -n "$SA" \
        -g "$RG" \
        -l "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --enable-hierarchical-namespace false \
        --https-only true \
        --tags project=CIA group=GR46 purpose=tfstate \
        -o none
    echo "   ✓ SA created"
fi

# ----------------------------------------------------------------------------
# 3. Enable blob versioning + soft-delete (state safety)
# ----------------------------------------------------------------------------
echo ""
echo "▶  [3/4] Enable versioning + soft-delete ($SOFT_DELETE_DAYS days)..."
az storage account blob-service-properties update \
    -n "$SA" \
    -g "$RG" \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days "$SOFT_DELETE_DAYS" \
    -o none
echo "   ✓ versioning + soft-delete enabled"

# ----------------------------------------------------------------------------
# 4. Container Blob
# ----------------------------------------------------------------------------
echo ""
echo "▶  [4/4] Container '$CONTAINER'..."
if az storage container show \
    --name "$CONTAINER" \
    --account-name "$SA" \
    --auth-mode login >/dev/null 2>&1; then
    echo "   = Container already exists, skipping creation"
else
    az storage container create \
        --name "$CONTAINER" \
        --account-name "$SA" \
        --auth-mode login \
        --public-access off \
        -o none
    echo "   ✓ Container created"
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "✅  Azure Storage backend bootstrap COMPLETE"
echo "============================================================"
echo "Resource Group     : $RG"
echo "Storage Account    : $SA"
echo "Container          : $CONTAINER"
echo "Versioning         : enabled"
echo "Soft-delete        : $SOFT_DELETE_DAYS days"
echo ""
echo "Next steps:"
echo "  # 1. Pour chaque stack Terraform :"
echo "  for STACK in siteA siteB siteC-azure; do"
echo "      cp terraform/backend.tf.example terraform/\$STACK/backend.tf"
echo "      sed -i \"s|KEY_TO_ADAPT|\$STACK.tfstate|\" terraform/\$STACK/backend.tf"
echo "  done"
echo ""
echo "  # 2. Migrer state local → distant :"
echo "  cd terraform/siteA && terraform init -migrate-state"
echo ""
echo "Doc complète : docs/runbooks/terraform-state.md §4"
