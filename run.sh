#!/bin/bash

# Service List: redis|mysql|mongodb|nginx|php|golang

# Default Startup Service
defaultContainer="nginx php mysql"
# Default Service
defaultBashContainer="php"

# # GitHub host
# 192.30.253.112 github.com
# 192.30.253.118 gist.github.com
# 151.101.112.133 assets-cdn.github.com
# 151.101.184.133 raw.githubusercontent.com
# 151.101.112.133 gist.githubusercontent.com
# 151.101.184.133 cloud.githubusercontent.com
# 151.101.112.133 camo.githubusercontent.com
# 151.101.112.133 avatars0.githubusercontent.com
# 151.101.112.133 avatars1.githubusercontent.com
# 151.101.184.133 avatars2.githubusercontent.com
# 151.101.12.133 avatars3.githubusercontent.com
# 151.101.12.133 avatars4.githubusercontent.com
# 151.101.184.133 avatars5.githubusercontent.com
# 151.101.184.133 avatars6.githubusercontent.com
# 151.101.184.133 avatars7.githubusercontent.com
# 151.101.12.133 avatars8.githubusercontent.com
# # GitHub End

mydir=$0
_b=$(ls -ld $mydir | awk '{print $NF}')
_c=$(ls -ld $mydir | awk '{print $(NF-2)}')
[[ $_b =~ ^/ ]] && mydir=$_b || mydir=$(dirname $_c)/$_b

WORK_DIR=$(
  cd $(dirname $mydir)
  pwd
)
WORK_NAME=${WORK_DIR##*/}
SCRIPT_SOURCE_DIR=$(pwd)
WHOAMI=$(whoami)
cd $WORK_DIR

function main() {
  local cmd
  config
  judge
  cmd=$1
  if [[ "" != $1 ]] && [[ "help" != $1 ]] && [[ "node" != $1 ]] && [[ "npm" != $1 ]] && [[ "sentry" != $1 ]] && [[ "go" != $1 ]] && [[ "composer" != $1 ]]; then
    shift
  fi
  case "$cmd" in
  status | s)
    _status $@
    ;;
  stop)
    _stop $@
    ;;
  buildUp | buildup)
    _build $@
    _start $@
    ;;
  restart)
    _restart $@
    ;;
  start | up)
    _start $@
    ;;
  reload)
    _reload $@
    ;;
  build)
    _build $@
    ;;
  bash)
    _bash $@
    ;;
  php | composer)
    _php $@
    ;;
  node | npm)
    _node $@
    ;;
  go)
    _go $@
    ;;
  sentry)
    _sentry $@
    ;;
  stats)
    docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    ;;
  ssl)
    _certbot $@
    ;;
  ins)
    _inspect $@
    ;;
  stop_all | stopAll | stopall)
    docker ps -a -q
    ;;
  delete_all | deleteAll | deleteall)
    docker system prune -a
    ;;
  tools)
    _tools
    ;;
  installDocker | installdocker)
    _installDocker
    ;;
  help)
    _help $@
    ;;
  logs)
    _logs $@
    ;;
  *)
    _help $@
    ;;
  esac

}

function _help() {
  local cmd=${BASH_SOURCE[0]}
  cmd=$(echo $cmd | sed 's:\/usr\/bin\/::g')
  echo '        .__                        .___                __                   '
  echo '________|  |    ______           __| _/ ____    ____  |  | __  ____ _______ '
  echo '\___   /|  |   /  ___/  ______  / __ | /  _ \ _/ ___\ |  |/ /_/ __ \\_  __ \'
  echo ' /    / |  |__ \___ \  /_____/ / /_/ |(  <_> )\  \___ |    < \  ___/ |  | \/'
  echo '/_____ \|____//____  >         \____ | \____/  \___  >|__|_ \ \___  >|__|   '
  echo '      \/           \/               \/             \/      \/     \/        '
  echo ''
  tips " $cmd start        Start up service"
  tips " $cmd stop         Stop of Service"
  tips " $cmd reload       Reload Services"
  tips " $cmd restart      Restart Services"
  tips " $cmd status       View status"
  tips " $cmd stats        Display resources used"
  tips " $cmd bash         Exec Services"
  tips " $cmd build        Build services"
  tips " $cmd buildUp      Build and start services"
  tips " $cmd tools        Toolbox"
  tips " $cmd ssl          Renew the free certificates from Let's Encrypt."
  echo ''
  echo " Designated Language Directives(php, node, npm, golang, composer)"
  echo " $cmd php -v"
  echo " $cmd npm install xxx"
  echo ' ......'
}

function judge() {
  type docker >/dev/null 2>&1 || {
    _installDocker
    error "Please install Docker!"
  }

  type docker-compose >/dev/null 2>&1 || {
    tips 'command:'
    tips '         sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose'
    tips '         sudo chmod +x /usr/local/bin/docker-compose'
    error "Please install docker-compose!"
  }
}

function askRoot() {
  if [ $(id -u) != 0 ]; then
    error "You must be root to run this script, please use root run"
  fi
}

function config() {
  local dockerComposePath="$WORK_DIR/docker-compose.yml"
  local configPath="$WORK_DIR/.env"

  if [[ ! -f $configPath ]]; then
    cp $configPath".example" $configPath
    if [ $? -ne 0 ]; then
      error ".env does not exist, initialize Error."
    else
      tips ".env does not exist, initialize."
    fi
  fi

  if [[ ! -f $dockerComposePath ]]; then
    cp $dockerComposePath".example" $dockerComposePath
    if [ $? -ne 0 ]; then
      error "docker-compose.yml does not exist, initialize Error."
    else
      tips "docker-compose.yml does not exist, initialize."
    fi
  fi
  source $configPath
}

function _installDocker() {
  #askRoot

  local info=$(cat /etc/os-release)
  if [[ "" != $(echo $info | grep CentOS) ]]; then
    tips 'OS is CentOS'
    tips 'command:'
    tips "        sudo yum install -y yum-utils device-mapper-persistent-data lvm2"
    tips "        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
    tips "        sudo yum install docker-ce docker-ce-cli containerd.io"
    tips "start:  "
    tips "        sudo systemctl start docker"
  elif [[ "" != $(echo $info | grep Ubuntu) ]]; then
    tips 'OS is Ubuntu'
    tips 'command:'
    tips "        sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common"
    tips "        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -"
    tips "        sudo apt-get update"
    tips "        sudo apt-get install docker-ce docker-ce-cli containerd.io"
    tips "start:  "
    tips "        sudo service start docker"
  else
    tips "See: https://docs.docker.com/install/"
  fi
}

function _install() {
  #askRoot
  local zdc="/usr/bin/zdc"
  local zdocker="/usr/bin/zdocker"
  if [ -f "$zdocker" ]; then
    sudo mv -f $zdocker $zdocker"-old"
  fi

  if [ -f "$zdc" ]; then
    tips "old zdc mv zdc-old"
    sudo mv -f $zdc $zdc"-old"
  fi
  sudo ln -s $WORK_DIR/run.sh $zdocker
  sudo ln -s $WORK_DIR/run.sh $zdc
  tips "You can now use zdc instead of ./run.sh: "
  tips "  zdc up"
  tips "  zdc help"
}

function _tools() {
  tips "********please enter your choise:(1-7)****"
  cat <<EOF
  (1) Install script into system bin
  (2) Auto optimize php-fpm conf
  (3) Custom composer repositories
  (4) Clean up all stopped containers
  (5) Mysql export and import
  (6) Start Sentry - Error Tracking Software
  (7) Start Yapi - api management platform
  (0) Exit
EOF
  read -p "Now select the top option to: " input
  case $input in
  1)
    _install
    ;;
  2)
    optimizePHPFpm
    ;;
  3)
    _php composer config -g repo.packagist composer $COMPOSER_PACKAGIST
    _php composer global require hirak/prestissimo
    ;;
  4)
    docker container prune
    ;;
  5)
    _mysqlTools
    ;;
  6)
    __sentry
    ;;
  7)
    __yapi
    ;;
  0)
    exit 1
    ;;
  *)
    echo "Please enter the correct option"
    ;;
  esac
}

function optimizePHPFpm() {
  echo "optimize:"
  local mem=$(free -m | awk '/Mem:/{print $2}')
  local conf="$WORK_DIR/config/php/php-fpm.conf"
  local max_children="pm.max_children = $(($mem / 2 / 20))"
  local start_servers="pm.start_servers = $(($mem / 2 / 30))"
  local min_spare_servers="pm.min_spare_servers = $(($mem / 2 / 40))"
  local max_spare_servers="pm.max_spare_servers = $(($mem / 2 / 20))"
  tips "    $max_children"
  tips "    $start_servers"
  tips "    $min_spare_servers"
  tips "    $max_spare_servers"
  sed -i "s@^pm.max_children.*@$max_children@" $conf
  sed -i "s@^pm.start_servers.*@$start_servers@" $conf
  sed -i "s@^pm.min_spare_servers.*@$min_spare_servers@" $conf
  sed -i "s@^pm.max_spare_servers.*@$max_spare_servers@" $conf
  echo "restart:"
  _reload php
}

function _bash() {
  local container
  local cmd
  container=$1
  shift
  cmd=$@
  if [[ "" == $container ]]; then
    tips "No service is specified (default service): $defaultBashContainer"
    container=$defaultBashContainer
  fi
  if [[ "" == $cmd ]]; then
    if [[ "go" == $container ]]; then
      container="go"
      cmd="bash"
    else
      cmd="sh"
    fi
  fi
  docker-compose exec $container $cmd
}

function _stop() {
  docker-compose stop $@
}

function _status() {
  docker-compose ps
}

function _start() {
  local container
  container=$@
  if [[ "" == $container ]]; then
    echo "No service is specified (default service): $defaultContainer"
    container=$defaultContainer
  fi
  docker-compose up -d $container
}

function _restart() {
  local container
  container=$@
  if [[ "" == $container ]]; then
    echo "No service is specified (default service): $defaultContainer"
    container=$defaultContainer
  fi
  docker-compose restart $container
}

function _reload() {
  local container=$@
  if [[ "" == $container ]]; then
    container="nginx"
  fi

  case $container in
  php)
    _bash php kill -USR2 1
    ;;
  nginx)
    _bash nginx nginx -s reload
    ;;
  *)
    _restart $@
    ;;
  esac
}

function _build() {
  local container
  container=$@
  if [[ "" == $container ]]; then
    error "Please enter the compiled service"
  else
    docker-compose build $container
  fi
}

function tips() {
  echo -e "\033[32m$@\033[0m"
}

function error() {
  echo -e "\033[1;31m$@\033[0m" 1>&2
  exit 1
}

function _php() {
  local phpv="php"
  local cmd
  cmd=$1
  images $phpv
  local composerPath=$(
    cd ${COMPOSER_DATA_DIR/.\/$SCRIPT_SOURCE_DIR/}
    pwd
  )
  if [[ "composer" == $cmd ]]; then
    docker run --tty --interactive --rm --cap-add SYS_PTRACE --volume $composerPath:/composer:rw --volume $SCRIPT_SOURCE_DIR:/var/www/html --workdir /var/www/html $WORK_NAME"_php" $@

    #docker run --tty --interactive --rm --user $(id -u):$(id -g) --cap-add SYS_PTRACE --volume /etc/passwd:/etc/passwd:ro --volume /etc/group:/etc/group:ro --volume $composerPath:/composer:rw --volume $SCRIPT_SOURCE_DIR:/var/www/html --workdir /var/www/html $WORK_NAME"_php" $@
  else
    _bash $phpv php $@
    # docker run --tty --interactive --rm --cap-add SYS_PTRACE --volume $composerPath:/composer:rw --volume $SCRIPT_SOURCE_DIR:/var/www/html --workdir /var/www/html $WORK_NAME"_php" php $@
  fi
}

function _sentry() {
  images sentry
  _bash sentry "$@"
}

function _node() {
  images node
  docker run --tty --interactive --rm --volume $SCRIPT_SOURCE_DIR:/var/www/html:rw --workdir /var/www/html $WORK_NAME"_node" "$@"
}

function _go() {
  images go
  docker run --tty --interactive --rm --volume $SCRIPT_SOURCE_DIR:/var/www/html:rw --workdir /var/www/html $WORK_NAME"_go" "$@"
}

function images() {
  local container=$1
  if [[ "" == $(echo $(docker images) | grep $WORK_NAME"_"$container) ]]; then
    tips "The $container service is for the first time, please wait ..."
    _start --build $container
  elif [[ "" == $(echo $(docker-compose images) | grep $WORK_NAME"_"$container) ]]; then
    _start $container
  fi
}

function __path() {
  echo $1
}

function _logs() {
  local container=$1
  docker-compose $container
}

function _certbot() {
  local certsPath="$WORK_DIR"
  local ACME=~/.acme.sh/acme.sh
  local binCmd=$certsPath/.run.sh
  local zdc="/usr/bin/zdc"
  if [ -f "$zdc" ]; then
    binCmd=zdc
  fi
  local help="Usage: $binCmd ssl -d mydomain.com -w $certsPath/www/mydomain.com/public"
  local email
  local debug
  local force
  if [ ! -f "$ACME" ]; then
    echo -e "\e[31m$ACME does not exist, installing...\e[0m"
    curl https://get.acme.sh | sh
    # 自动更新
    $ACME --upgrade  --auto-upgrade
  fi

  if [[ "$1" == "" ]]; then
    error $help
  fi

  args=()

  while [ "$1" != "" ]; do
      case "$1" in
          --email )                       email="$2";                     shift;;
          --dns )                         dns="$2";                       shift;;
          -d | --domain )                 domain="$2";                    shift;;
          -B | --broad )                  broad="general analysis";       shift;;
          -a | --alias )                  alias="$2";                     shift;;
          -w | --webroot )                webroot="--webroot $2";         shift;;
          -h | --help )                   tips $help;                     exit;;
          * )                             args+=("$1")
      esac
      shift
  done
  if [[ -z "${domain}" ]]; then
      error "Please enter the domain name"
  fi

  if [[ -z "${reloadcmd}" ]]; then
     reloadcmd='zdc reload'
  fi

  if [[ -n "${dns}" ]]; then
      # dns_cf
      dns="--dns  ${dns}";
  fi

  if [[ -n "${broad}" ]]; then
      broad="-d  *.${domain}";
  fi

  if [[ -n "${alias}" ]]; then
      alias_str="--challenge-alias ${alias}";
  fi

  ## --force --debug --reloadcmd "zdc reload"

  $ACME --issue $dns $alias_str -d $domain $broad $webroot

  echo "create certs dir: $certsPath/config/nginx/conf.d/certs/$domain"
  mkdir -p $certsPath/config/nginx/conf.d/certs/$domain

  $ACME --install-cert -d $domain $broad --key-file $certsPath/config/nginx/conf.d/certs/$domain/server.key --fullchain-file $certsPath/config/nginx/conf.d/certs/$domain/server.crt

  tips "reference:"
  echo "  cp $certsPath/config/nginx/conf.d/localhost_https.conf $certsPath/config/nginx/conf.d/[DOMAIN]_https.conf"
}

function _mysqlTools() {
  local yes=0
  tips "********Mysql Tools****"
  cat <<EOF
  (1) Export
  (2) Import
  (0) Exit
EOF
  read -p "Now select the top option to: " input
  case $input in
  1)
    __determine "Mysql Export"
    yes=$?
    if [[ $yes == 1 ]]; then
      local BAK_FILE="$MYSQL_CONF_DIR/backup.sql"
      _bash mysql mysqldump --all-databases -uroot -p666666 >$BAK_FILE
      echo "export -> $BAK_FILE"
    else
      echo "Give up Export mysql"
    fi
    ;;
  2)
    tips 'command:'
    echo "        ${BASH_SOURCE[0]} bash mysql"
    echo "        mysql -uroot -p$MYSQL_ROOT_PASSWORD"
    echo "        source /mysql/backup.sql"
    ;;
  0)
    exit 1
    ;;
  *)
    echo "Please enter the correct option"
    ;;
  esac
}

function __determine() {
  echo -e "Please determine if you want to perform \033[32m$1\033[0m operation (yes|NO)"
  read -p "Now select the top option to: " input
  case $input in
  "y" | "Y" | "yes" | "YES")
    return 1
    ;;
  *)
    return 0
    ;;
  esac
}

function _inspect() {
  docker inspect $WORK_NAME"_$@"
}

function __yapi() {
  docker-compose up -d yapi
  tips "yapi: http://127.0.0.1:$YAPI_HOST_PORT"
}

function __sentry() {
  local cmd=${BASH_SOURCE[0]}
  cmd=$(echo $cmd | sed 's:\/usr\/bin\/::g')
  docker-compose up -d sentry sentry_celery_beat sentry_celery_worker
  tips "For the first time, please execute the following command to initialize sentry:\n"
  tips "  $cmd sentry upgrade"
  tips ""
}

main "$@"
