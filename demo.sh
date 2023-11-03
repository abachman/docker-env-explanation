#!/usr/bin/env bash

blue=$(tput setaf 4)
bright=$(tput bold)
normal=$(tput sgr0)

cmd() {
  method=$1; shift 1
  report="  ${blue}${bright}$method${normal}"
  actual_command="docker compose --progress quiet $@"
  [ -n "$DEBUG" ] && echo "$ $actual_command"
  printf '%-40s' "$report"
  eval "$actual_command | grep VAR: | sed -E 's/VAR: //'"
}

cleanup() {
  echo 'quitting...'
  exit 0
}

trap cleanup INT QUIT TERM

run_all() {
  services=(
    myapp-none
    myapp-envfile
    myapp-environment
    myapp-environment-passthrough
    myapp-all
  )
  for service in "${services[@]}"; do
    echo
    gum style --padding "1 5" --border normal --border-foreground '#0088aa' "$service"
    cmd "run" $run $service
    cmd "--env-file run" --env-file=arg.env $run $service
    cmd "run -e" $run -e "VAR='run -e'" $service
    cmd "--env-file run -e" --env-file=arg.env $run -e "VAR='run -e'" $service
  done
}

run='run --rm --no-deps'

gum style --padding "1 5" --border double --border-foreground '#00aa66' "Dockerfile with ENV"
DOCKERFILE=Dockerfile-env docker compose --progress quiet build myapp

run_all

echo
echo
gum style --padding "1 5" --border double --border-foreground '#00aa66' "Dockerfile without ENV"
DOCKERFILE=Dockerfile docker compose --progress quiet build myapp

run_all
