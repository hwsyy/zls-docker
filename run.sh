#!/bin/bash

# Service List: redis|mysql|mongodb|nginx|php|golang

# Default Startup Service
defaultContainer="nginx php72 mysql"
# Default Service
defaultBashContainer="php72"

mydir=$0
_b=$(ls -ld $mydir | awk '{print $NF}')
_c=$(ls -ld $mydir | awk '{print $(NF-2)}')
[[ $_b =~ ^/ ]] && mydir=$_b || mydir=$(dirname $_c)/$_b

WORK_DIR=$(
  cd $(dirname $mydir)
  pwd
)
WORK_NAME=${WORK_DIR##*/}
SOURCE_DIR=$(pwd)

cd $WORK_DIR

function main() {
  local cmd
  config
  judge
  cmd=$1
  if [[ "" != $1 ]] && [[ "help" != $1 ]] && [[ "node" != $1 ]] && [[ "npm" != $1 ]] && [[ "go" != $1 ]] && [[ "composer" != $1 ]]; then
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
  stats)
    docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    ;;
  certbot)
    _certbot $@
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
  sudo ln -s $WORK_DIR/run.sh /usr/bin/zdocker
  tips "You can now use zdocker instead of ./run.sh: "
  tips "  zdocker up"
  tips "  zdocker help"
}

function _tools() {
  tips "********please enter your choise:(1-6)****"
  cat <<EOF
  (1) Install script into system bin
  (2) Optimize php-fpm conf
  (3) Clean up all stopped containers
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
    docker container prune
    ;;
  0)
    exit 1
    ;;
  *)
    echo "Please enter the correct option"
    ;;
  esac
  #  optimize
}

function optimizePHPFpm() {
  tips "optimize php-fpm.conf"
  local mem=$(free -m | awk '/Mem:/{print $2}')
  local conf="$WORK_DIR/config/php/php-fpm.conf"
  sed -i "s@^pm.max_children.*@pm.max_children = $(($mem / 2 / 20))@" $conf
  sed -i "s@^pm.start_servers.*@pm.start_servers = $(($mem / 2 / 30))@" $conf
  sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = $(($mem / 2 / 40))@" $conf
  sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = $(($mem / 2 / 20))@" $conf
  _reload php72
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
  php72)
    _bash php72 kill -USR2 1
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
  local phpv="php72"
  local cmd
  cmd=$1
  if [[ "composer" == $cmd ]]; then
    images composer
    docker run --tty --interactive --rm --user $(id -u):$(id -g) --volume $WORK_DIR/data/composer:/tmp --volume /etc/passwd:/etc/passwd:ro --volume /etc/group:/etc/group:ro --volume $SOURCE_DIR:/app --workdir /app $WORK_NAME"_composer" $@
  else
    images $phpv
    _bash $phpv php $@
  fi
}

function _node() {
  images node
  docker run --tty --interactive --rm --volume $SOURCE_DIR:/var/www/html:rw --workdir /var/www/html $WORK_NAME"_node" "$@"
}

function _go() {
  images go
  docker run --tty --interactive --rm --volume $SOURCE_DIR:/var/www/html:rw --workdir /var/www/html $WORK_NAME"_go" "$@"
}

function images() {
  local container
  container=$1
  if [[ "" == $(echo $(docker images) | grep $WORK_NAME"_"$container) ]]; then
    tips "The $container service is for the first time, please wait ..."
    _start --build $container
  elif [[ "" == $(echo $(docker-compose images) | grep $WORK_NAME"_"$container) ]]; then
    _start $container
  fi
}

function _certbot() {
  local domain
  local vhostDir
  local certsPath="$WORK_DIR/data/letsencrypt"
  domain=$1
  if [[ "" == $domain ]]; then
    error "Please enter the domain name"
  fi
  vhostDir="$WORK_DIR/www/$domain"
  docker run -it --rm --name certbot \
    --volume "$certsPath:/etc/letsencrypt/live/archive" \
    --volume "$vhostDir:/var/www/html" \
    --volume "$WORK_DIR/log:/var/log" \
    certbot/certbot certonly -n --no-eff-email --email admin@73zls.com --agree-tos --webroot -w /var/www/html -d $domain
}

main "$@"
