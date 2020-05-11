az login
<br /> az account list --query "[].{name:name, subscriptionId:id, tenantId:tenantId}"
<br /> az account set --subscription="${SUBSCRIPTION_ID}"
<br /> az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}"
