install_oracle_libraries(){
  echo $HOME
  local build_dir=${1:-}
  echo "Installing oracle libraries"
  mkdir -p $build_dir/oracle
  cd $build_dir/oracle
  local basic_download_url="https://artifactory.int.8451.com/artifactory/nodejs-oracle/instantclient-basic-linux.x64.zip"
  local sdk_download_url="https://artifactory.int.8451.com/artifactory/nodejs-oracle/instantclient-sdk-linux.x64.zip"
  curl -k "$basic_download_url" --silent --fail --retry 5 --retry-max-time 15 -o instantclient-basic.zip
  echo "Downloaded [$basic_download_url]"
  curl -k "$sdk_download_url" --silent --fail --retry 5 --retry-max-time 15 -o instantclient-sdk.zip
  echo "Downloaded [$sdk_download_url]"
  echo "unzipping libraries"
  unzip instantclient-basic.zip
  unzip instantclient-sdk.zip
  mv instantclient_12_2 instantclient
  cd instantclient
  ln -s libclntsh.so.12.2 libclntsh.so
}

list_dependencies() {
  local build_dir="$1"

  cd "$build_dir"
  if $YARN; then
    echo ""
    (yarn ls || true) 2>/dev/null
    echo ""
  else
    (npm ls --depth=0 | tail -n +2 || true) 2>/dev/null
  fi
}

run_if_present() {
  local script_name=${1:-}
  local has_script=$(read_json "$BUILD_DIR/package.json" ".scripts[\"$script_name\"]")
  if [ -n "$has_script" ]; then
    if $YARN; then
      echo "Running $script_name (yarn)"
      yarn run "$script_name"
    else
      echo "Running $script_name"
      npm run "$script_name" --if-present
    fi
  fi
}

yarn_node_modules() {
  local build_dir=${1:-}

  echo "Installing node modules (yarn)"
  cd "$build_dir"
  # according to docs: "Verifies that versions of the package dependencies in the current project’s package.json matches that of yarn’s lock file."
  # however, appears to also check for the presence of deps in node_modules
  # yarn check 1>/dev/null
  if [ "$NODE_ENV" == "production" ] && [ "$NPM_CONFIG_PRODUCTION" == "false" ]; then
    echo ""
    echo "Warning: when NODE_ENV=production, yarn will NOT install any devDependencies"
    echo "  (even if NPM_CONFIG_PRODUCTION is false)"
    echo "  https://yarnpkg.com/en/docs/cli/install#toc-yarn-install-production"
    echo ""
  fi
  yarn install --pure-lockfile --ignore-engines 2>&1
}

npm_node_modules() {
  local build_dir=${1:-}

  if [ -e $build_dir/package.json ]; then
    cd $build_dir

    if [ -e $build_dir/npm-shrinkwrap.json ]; then
      echo "Installing node modules (package.json + shrinkwrap)"
    else
      echo "Installing node modules (package.json)"
    fi
    npm install --unsafe-perm --userconfig $build_dir/.npmrc 2>&1
  else
    echo "Skipping (no package.json)"
  fi
}

npm_rebuild() {
  local build_dir=${1:-}

  if [ -e $build_dir/package.json ]; then
    cd $build_dir
    echo "Rebuilding any native modules"
    npm rebuild --nodedir=$build_dir/.heroku/node 2>&1
    if [ -e $build_dir/npm-shrinkwrap.json ]; then
      echo "Installing any new modules (package.json + shrinkwrap)"
    else
      echo "Installing any new modules (package.json)"
    fi
    npm install --unsafe-perm --userconfig $build_dir/.npmrc 2>&1
  else
    echo "Skipping (no package.json)"
  fi
}
