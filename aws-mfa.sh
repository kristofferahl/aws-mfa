#!/usr/bin/env bash

declare sessionFile='./.aws-session'

declare optAccessKeyId=''
declare optSecretAccessKey=''
declare optRegion=''
declare optMfaDevice=''
declare optMfaTokenCode=''
declare optOutput=''
declare optDebug=''

# TODO: Fix bug where last option isn't parsed properly

debug-log () {
  if [[ "${optDebug}" == "true" ]]; then
    echo "aws-mfa [DEBUG] $1"
  fi
}

error-log () {
  echo "aws-mfa [ERROR] $1" >&2
}

prompt () {
  if [[ "${optOutput}" != "terminal" ]]; then
    echo -n "[aws-mfa] ${1:?'A prompt text must be provided'}: "
    read ${2:?'A variable name must be provided'}
  fi
}

source-session-file () {
  if [[ -f ${sessionFile} ]]; then
    debug-log "Sourcing session file"
    # shellcheck source=/dev/null
    source ${sessionFile}
  fi
}

authenticate () {
  debug-log "Authenticating..."

  # shellcheck disable=SC2034
  export AWS_ACCESS_KEY_ID="${optAccessKeyId:?'must be provided'}"
  # shellcheck disable=SC2034
  export AWS_SECRET_ACCESS_KEY="${optSecretAccessKey:?'must be provided'}"
  # shellcheck disable=SC2034
  export AWS_SESSION_TOKEN=""
  # shellcheck disable=SC2034
  export AWS_DEFAULT_REGION="${optRegion:-'must be provided'}"

  local mfaDevice="${optMfaDevice:?'must be provided'}"
  local mfaTokenCode="${optMfaTokenCode}"

  local accessKeyId
  local secretAccessKey
  local sessionToken

  awsAccountId="$(aws sts get-caller-identity 2> /dev/null | jq -r '.Account' 2> /dev/null)"
  awsAccountName="$(aws iam list-account-aliases 2> /dev/null | jq -r '.AccountAliases[0]' 2> /dev/null)"

  if [[ "${awsAccountId}" == "" ]]; then
    error-log "Authentication failed!"
    error-log "Invalid 'access key id' or 'secret access key' provided."
    clean-environment
    return 1
  fi

  if [[ "${optOutput}" != "terminal" ]]; then
    while [[ "${mfaTokenCode}" == "" ]]; do
      prompt "Enter MFA token code for ${awsAccountName}" mfaTokenCode
    done
  fi

  mfaSessionTokenJson="$(aws sts get-session-token --serial-number ${mfaDevice} --token-code ${mfaTokenCode} 2> /dev/null)"
  accessKeyId="$(echo "${mfaSessionTokenJson}" | jq -r '.Credentials.AccessKeyId' 2> /dev/null)"
  secretAccessKey="$(echo "${mfaSessionTokenJson}" | jq -r '.Credentials.SecretAccessKey' 2> /dev/null)"
  sessionToken="$(echo "${mfaSessionTokenJson}" | jq -r '.Credentials.SessionToken' 2> /dev/null)"

  if [[ "${accessKeyId}" == "" ]] || [[ "${secretAccessKey}" == "" ]] || [[ "${sessionToken}" == "" ]]; then
    error-log "Authentication failed!"
    error-log "Invalid 'mfa device' or 'mfa token code' provided."
    clean-environment
    return 2
  else
    local output
    output="export AWS_ACCESS_KEY_ID='${accessKeyId}'
export AWS_SECRET_ACCESS_KEY='${secretAccessKey}'
export AWS_SESSION_TOKEN='${sessionToken}'
export AWS_DEFAULT_REGION='${AWS_DEFAULT_REGION}'
export AWS_ACCOUNT_ID='${awsAccountId}'
export AWS_ACCOUNT_NAME='${awsAccountName}'"

    if [[ "${optOutput}" == "file" ]]; then
      debug-log "Output is set to ${optOutput} (${sessionFile})"
      echo -e "#!/usr/bin/env bash\n${output}" >> ${sessionFile}
    else
      debug-log "Output is set to ${optOutput}"
      echo "${output}"
    fi
    return 0
  fi
}

is-authenticated () {
  aws sts get-caller-identity &> /dev/null
  echo "$?"
}

clean-environment () {
  export AWS_ACCESS_KEY_ID=''
  export AWS_SECRET_ACCESS_KEY=''
  export AWS_DEFAULT_REGION=''
}

aws-mfa-is-authenticated () {
  source-session-file
  if [[ "$(is-authenticated)" == "0" ]]; then
    echo "true"; exit 0;
  else
    echo "false"; exit 1;
  fi
}

aws-mfa-authenticate () {
  debug-log "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
  debug-log "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"
  debug-log "AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}"
  debug-log "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}"
  debug-log "AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
  debug-log "AWS_ACCOUNT_NAME=${AWS_ACCOUNT_NAME}"

  local hasSession=''
  local error='0'

  hasSession="$(is-authenticated)"
  while [[ "$hasSession" != "0" ]]; do
    debug-log "No valid AWS session available"

    if [[ ! -f ${sessionFile} ]]; then
      authenticate
      error="$?"
      case "${error}" in
        '1') return ${error};; # Invalid credentials
        '2') return ${error};; # Invalid mfa token code or device
      esac
    fi

    source-session-file

    hasSession="$(is-authenticated)"

    if [[ "${hasSession}" != "0" ]]; then
      debug-log "Ensuring invalid session file is removed"
      rm ${sessionFile} || true
    fi
  done

  if [[ "${optDebug}" == "true" ]]; then
    debug-log "Successfully authenticated as user: $(aws sts get-caller-identity)"
  fi
}

aws-mfa () {
  local cmd="aws-mfa-${1}"
  case "$cmd" in
    aws-mfa-authenticate|aws-mfa-is-authenticated) ;;
    *)
      error-log "Invalid subcommand!";
      error-log "Usage: aws-mfa <subcommand> [--option1=value --option2=value]"
      return 1;;
  esac

  while [ "$#" -gt 1 ]; do
    case "$1" in
      --access-key-id=*) optAccessKeyId="${1#*=}"; shift 1;;
      --secret-access-key=*) optSecretAccessKey="${1#*=}"; shift 1;;
      --region=*) optRegion="${1#*=}"; shift 1;;
      --mfa-device=*) optMfaDevice="${1#*=}"; shift 1;;
      --mfa-token-code=*) optMfaTokenCode="${1#*=}"; shift 1;;
      --output=*) optOutput="${1#*=}"; shift 1;;
      --debug=*) optDebug="${1#*=}"; shift 1;;

      --access-key-id|--secret-access-key|--mfa-device|--mfa-token-code)
        error-log "$1 requires a value (--option=value)";
        return 1;;
      -*)
        error-log "Unknown option: $1";
        return 1;;
      *) shift 1;;
    esac
  done

  optRegion="${optRegion:-"us-west-1"}"
  optOutput="${optOutput:-"file"}"
  optDebug="${optDebug:-"false"}"

  debug-log "CMD: ${cmd}"
  debug-log "ARGS: ${*}"
  debug-log "optAccessKeyId     : ${optAccessKeyId}"
  debug-log "optSecretAccessKey : ${optSecretAccessKey}"
  debug-log "optRegion          : ${optRegion}"
  debug-log "optMfaDevice       : ${optMfaDevice}"
  debug-log "optMfaTokenCode    : ${optMfaTokenCode}"
  debug-log "optOutput          : ${optOutput}"
  debug-log "optDebug           : ${optDebug}"

  $cmd
}
