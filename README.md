## Create a private AKS with Azure Active Directory integration and Rback

This Terraform module performs the following actions : 
1. Create a Admin group in the Azure Active Directory
2. Create an AD application to gets Azure AD group membership for a user
3. Create an AD application to handle login with the Kubernetes CLI
4. Create the cluster AKS with Rback
5. Add the Ad Admin group to the AKS group admin


## Usage in Terraform
```hcl

```