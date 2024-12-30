
# Preparation steps for OIDC integration

__N.B.__ only IAM admins can create the clients needed for RUCIO. If you are not one of them, please contact one and provide the json files in `client-configs` folder.

## Client for user authentication

- Get a valid token with IAM profile and store it in `TOKEN` env var
- Register the client via the proper REST call with:
```bash
curl -vvv -XPOST -H "Content-type: application/json" -H "Authorization: Bearer ${TOKEN}" https://cms-auth.web.cern.ch/api/clients -d "@client-configs/req-client-user-auth-INSTANCENAMEHERE.json"
```
- Take note of `client_id` and `client_secret` in the response

## Client for subject<-->account mapping

- Get a valid token with IAM profile and store it in `TOKEN` env var
- Register the client via the proper REST call with:
```bash
curl -vvv -XPOST -H "Content-type: application/json" -H "Authorization: Bearer ${TOKEN}" https://cms-auth.web.cern.ch/api/clients -d "@client-configs/req-client-admin-scim.json"
```
- Take note of `client_id` and `client_secret` in the response

## Prepare RUCIO secret

- Create a file named `idpsecrets.json` with the following content

```json
{
  "cms": {

    "issuer": "https://cms-auth.web.cern.ch/",

    "redirect_uris": [
      "CHANGEME e.g. https://cms-rucio-auth-int.cern.ch/auth/oidc_code",
      "CHANGEME e.g. https://cms-rucio-auth-int.cern.ch/auth/oidc_token"
    ],

    "client_id": "CLIENT_ID FOR USER AUTH",
    "registration_access_token": "",
    "client_secret": "CLIENT_SECRET FOR USER AUTH",

    "SCIM": {
     "client_id": "CLIENT_ID FOR SUBJ MAPPING",
      "registration_access_token": "",
      "client_secret": "CLIENT_SECRET FOR SUBJ MAPPING"
    }
  }
}
```

> __N.B.__ replace the entries in CAPITAL, with the information gathered on the previous steps and with the proper URLs.

- create the secret in the `rucio` namespace via:
```bash
kubectl create secret -n rucio generic server-idpsecrets --from-file=./idpsecrets.json
```