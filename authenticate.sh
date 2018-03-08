#!/usr/bin/env bash
declare debug=false
declare sessionFile='./.aws-session'

alias aws='docker run --rm -t $(tty &>/dev/null && echo "-i") -e "AWS_ACCESS_KEY_ID=''${AWS_ACCESS_KEY_ID}''" -e "AWS_SECRET_ACCESS_KEY=''${AWS_SECRET_ACCESS_KEY}''" -e "AWS_SESSION_TOKEN=''${AWS_SESSION_TOKEN}''" -e "AWS_DEFAULT_REGION=''${AWS_DEFAULT_REGION}''" mesosphere/aws-cli'
shopt -s expand_aliases

debug-log () {
  if [[ ${debug} == true ]]; then
    echo "[DEBUG] $1"
  fi
}

prompt () {
  echo -n "${1:?'A prompt text must be provided'}: "
  read ${2:?'A variable name must be provided'}
}

authenticate () {
  debug-log "Authenticating..."
  local AWS_ACCESS_KEY_ID="${1:?'Access key id must be provided'}"
  local AWS_SECRET_ACCESS_KEY="${2:?'Secret access key must be provided'}"
  local AWS_SESSION_TOKEN=""
  local AWS_DEFAULT_REGION="${3:?'Region must be provided'}"

  local mfaDevice="${4:?'MFA device (arn) must be provided'}"
  local accessKeyId
  local secretAccessKey
  local sessionToken

  awsAccountId="$(aws sts get-caller-identity | jq -r '.Account')"
  awsAccountName="$(aws iam list-account-aliases | jq -r '.AccountAliases[0]')"

  : ${awsAccountId:?'Failed to fetch AWS Account Id'}
  : ${awsAccountName:?'Failed to fetch AWS Account Name'}

  local mfaTokenCode=''
  while [[ "${mfaTokenCode}" == "" ]]; do
    prompt "Enter MFA code for ${awsAccountName}" mfaTokenCode
    sleep 1
  done

  mfaSessionTokenJson="$(aws sts get-session-token --serial-number ${mfaDevice} --token-code ${mfaTokenCode})"
  accessKeyId="$(echo "${mfaSessionTokenJson}" | jq -r '.Credentials.AccessKeyId')"
  secretAccessKey="$(echo "${mfaSessionTokenJson}" | jq -r '.Credentials.SecretAccessKey')"
  sessionToken="$(echo "${mfaSessionTokenJson}" | jq -r '.Credentials.SessionToken')"

  : ${accessKeyId:?"'accessKeyId' not set"}
  : ${secretAccessKey:?"'secretAccessKey' not set"}
  : ${sessionToken:?"'sessionToken' not set"}

  echo "#!/usr/bin/env bash
export AWS_ACCESS_KEY_ID='${accessKeyId}'
export AWS_SECRET_ACCESS_KEY='${secretAccessKey}'
export AWS_SESSION_TOKEN='${sessionToken}'
export AWS_DEFAULT_REGION='${AWS_DEFAULT_REGION}'
export AWS_ACCOUNT_ID='${awsAccountId}'
export AWS_ACCOUNT_NAME='${awsAccountName}'
  " >> ${sessionFile}
}

is-authenticated () {
  aws sts get-caller-identity &> /dev/null
  echo "$?"
}

declare hasSession=''
hasSession="$(is-authenticated)"

while [[ "$hasSession" != "0" ]]; do
  debug-log "No valid AWS session available"

  if [[ ! -f ${sessionFile} ]]; then
    authenticate "${AWS_MFA_ACCESS_KEY_ID}" "${AWS_MFA_SECRECT_ACCESS_KEY}" "eu-west-1" "${AWS_MFA_DEVICE_ID}"
  fi

  if [[ -f ${sessionFile} ]]; then
    debug-log "Sourcing session file"
    source ${sessionFile}
  fi

  hasSession="$(is-authenticated)"
  if [[ "${hasSession}" != "0" ]]; then
    debug-log "Ensuring invalid session file is removed"
    rm ${sessionFile} || true
  fi

  sleep 1
done

debug-log "Successfully authenticated as user"
if [[ ${debug} == true ]]; then
  aws sts get-caller-identity
fi
