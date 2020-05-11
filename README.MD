<br /> Install Azure CLI and login from command prompt
<br /> az login
<br />
<br /> Please execute below command and generate tanentId, ClientId
<br /> az account list --query "[].{name:name, subscriptionId:id, tenantId:tenantId}"
<br />
<br /> Set SubscriptionID
<br /> az account set --subscription="<SUBSCRIPTION_ID>"
<br />
<br /> Create a Contributor Role in order to work with Azure from Terraform
<br /> az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<SUBSCRIPTION_ID>"
