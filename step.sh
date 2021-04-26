#!/bin/bash
set -e

# define base file paths
tmp_dir="${BITRISE_STEP_SOURCE_DIR}/tmp"
license_file_path="${tmp_dir}/license.licel"
log_file_path="${BITRISE_DEPLOY_DIR}/dexprotector-log.txt"
###

# generate protected app filename
app_filename=$(basename -- "${app_file}" | sed -e 's/[-._]\?unsigned//ig')
app_name="${app_filename%%.*}"
app_ext="${app_filename##*.}"
protected_app_file_path="${BITRISE_DEPLOY_DIR}/${app_name}.protected.${app_ext}"
###

# define app platform
app_platform_lc=$(echo "${app_platform}" | awk '{print tolower($0)}') # 'Android' or 'iOS' to 'android' or 'ios'

if [ "${app_platform_lc}" = "auto" ]; then
  app_ext_lc=$(echo "${app_ext}" | awk '{print tolower($0)}')

  case ${app_ext_lc} in
  apk | aar | aab)
    app_platform_lc="android"
    ;;
  ipa)
    app_platform_lc="ios"
    ;;
  *)
    echo "File extension \".${app_ext_lc}\" is unsupported for auto define platform type. Configure app platform manually."
    exit 1
    ;;
  esac
fi

if [ "${app_platform_lc}" != "android" ] && [ "${app_platform_lc}" != "ios" ]; then
  echo "Unsupported app platform: \"${app_platform}\""
  exit 1
fi
###

mkdir "${tmp_dir}"

# make license
echo "${license_base64}" | base64 --decode > "${license_file_path}"
###

function cleanup() {
  rm -rf "${tmp_dir}"
}

trap cleanup EXIT

echo "
Config:
- App platform: ${app_platform_lc}
- App file: ${app_file}
- App protected file: ${protected_app_file_path}
- Config file: ${config_file}
- Log file: ${log_file_path}"

# set config file and license
jar_args="-configFile \"${config_file}\" -licenseFile \"${license_file_path}\""

# set verbose
if [ "${verbose}" = "yes" ]; then
  echo "- Verbose: ${verbose}"
  jar_args="${jar_args} -verbose"
fi

# set main class by app platform
if [ "${app_platform_lc}" = "ios" ]; then
  jar_main_class="com.licel.dexprotector.ios.ConsoleTask"
elif [ "${app_platform_lc}" = "android" ]; then
  jar_main_class="com.licel.dexprotector.ConsoleTask"
  # set sign mode
  if [ "${sign_mode}" != "-" ]; then
    echo "- Sign mode: ${sign_mode}"
    jar_args="${jar_args} -signMode \"${sign_mode}\""
  fi
  # set certificate
  if [ -n "${certificate}" ]; then
    echo "- Certificate: ${certificate}"
    jar_args="${jar_args} -certificate \"${certificate}\""
  fi
  # set sha256_certificate_fingerprint
  if [ -n "${sha256_certificate_fingerprint}" ]; then
    jar_args="${jar_args} -sha256CertificateFingerprint \"${sha256_certificate_fingerprint}\""
  fi
  # set keystore
  if [ -n "${keystore}" ]; then
    echo "- Keystore: ${keystore}"
    jar_args="${jar_args} -keystore \"${keystore}\""
  fi
  # set storepass
  if [ -n "${storepass}" ]; then
    jar_args="${jar_args} -storepass \"${storepass}\""
  fi
  # set keyalias
  if [ -n "${keyalias}" ]; then
    echo "- Key alias: ${keyalias}"
    jar_args="${jar_args} -alias \"${keyalias}\""
  fi
  # set keypass
  if [ -n "${keypass}" ]; then
    jar_args="${jar_args} -keypass \"${keypass}\""
  fi
  # set proguard_map_file
  if [ -n "${proguard_map_file}" ]; then
    echo "- Mapping file: ${proguard_map_file}"
    jar_args="${jar_args} -proguardMapFile \"${proguard_map_file}\""
  fi
fi

cmd="java -cp \"${jar_file}\" \"${jar_main_class}\" ${jar_args} \"${app_file}\" \"${protected_app_file_path}\""

echo "
$ ${cmd}"

{
  eval ${cmd}
} &> >(tee "${log_file_path}")

envman add --key DEXPROTECTOR_PROTECTED_APP_FILE --value "${protected_app_file_path}"
envman add --key DEXPROTECTOR_LOG_FILE --value "${log_file_path}"

echo "
Outputs:
DEXPROTECTOR_PROTECTED_APP_FILE: ${protected_app_file_path}
DEXPROTECTOR_LOG_FILE: ${log_file_path}"
