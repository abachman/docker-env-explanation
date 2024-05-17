
run() {
  echo "\033[34m$@\033[0m"
  $@ > /dev/null

  if [ $? -ne 0 ]; then
    echo "\033[31;1m<< command failed >>\033[0m"
  else
    echo "\033[32;1m<< command succeeded >>\033[0m"
  fi
}

echo "\033[37;3m"
echo "  [PROVLEM 1] env_file bleeds across docker-compose.yml files, depending"
echo "  on calling order"
echo "\033[0m"

server_path=server/docker-compose.yml
client_path=client/docker-compose.yml
partners_path=partners/docker-compose.yml

run docker compose -f ${server_path} -f ${client_path} config
run docker compose -f ${partners_path} -f ${client_path} config
run docker compose -f ${partners_path}  -f ${server_path} -f ${client_path} config
run docker compose -f ${server_path}  -f ${partners_path} config
# partners env_file bleeds up to client
run docker compose -f ${client_path} -f ${partners_path} -f ${server_path} config
run docker compose -f ${client_path} -f ${server_path} -f ${partners_path} config
run docker compose -f ${partners_path} -f ${client_path} -f ${server_path} config
run docker compose -f ${partners_path} -f ${server_path} -f ${client_path} config
run docker compose -f ${server_path} -f ${partners_path} -f ${client_path} config
run docker compose -f ${server_path} -f ${client_path} -f ${partners_path} config

# client, then server
run docker compose -f ${client_path} -f ${server_path} config

echo "\033[37;3m"
echo "  [PROBLEM 2] .env is automatically loaded by docker-compose, but if"
echo "  a second docker-compose.yml file is used, the .env file is not loaded"
echo "\033[0m"

echo " :: only server/docker-compose.yml"
echo
docker compose -f ${server_path} run server

echo
echo " :: both client/docker-compose.yml and server/docker-compose.yml"
echo
docker compose -f ${client_path} -f ${server_path} run server