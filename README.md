# aws-mfa

A **bash script** or **docker command** for using AWS Multi Factor Authentication (MFA).

**aws-mfa** can output credentials to *file* (`.aws-session`) or to the *terminal* (for use with `eval`).

## Sub commands

- authenticate
- is-authenticated

## Options

```bash
--access-key-id      # REQUIRED FOR authenticate command
--secret-access-key  # REQUIRED FOR authenticate command
--mfa-device         # REQUIRED FOR authenticate command
--mfa-token-code     # REQUIRED FOR authenticate command
--region             # OPTIONAL. Default: us-west-1
--output             # OPTIONAL (file/terminal). Default: file
--debug              # OPTIONAL (false/true). Default: false
```

## Using docker

### File mode

```bash
docker run --rm -it -v "${PWD}:/work" \
  kristofferahl/aws-mfa:latest authenticate \
    --access-key-id="" \
    --secret-access-key="" \
    --mfa-device="" \
    --mfa-token-code=""
```

### Terminal mode

```bash
eval "$(docker run --rm \
  kristofferahl/aws-mfa:latest authenticate \
    --access-key-id='' \
    --secret-access-key='' \
    --mfa-device='' \
    --mfa-token-code='' \
    --output='terminal')"
```

## Using shellscript

### Pre-requisites
- aws-cli
- jq

### Example

```bash
curl https://raw.githubusercontent.com/kristofferahl/aws-mfa/master/aws-mfa.sh > ./aws-mfa.sh

source ./aws-mfa.sh
aws-mfa authenticate \
  --access-key-id='' \
  --secret-access-key='' \
  --mfa-device='' \
  --mfa-token-code=''
```
