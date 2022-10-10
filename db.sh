#!/usr/bin/env bash

namespace=""
db_resource=""

help() {
echo "kubectl db [flags] <resource>"
  echo "  -n|--namespace"

  exit 2
}

# Set up command-line options
SHORT="n:,v;"
LONG="namespace:,version"
OPTS=$(getopt --name "kubectl-inline" --options "$SHORT" --longoptions "$LONG" -- "$@")

if [[ "$#" == 0 ]]
then
  help
fi

eval set -- "$OPTS"

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--namespace)
      namespace="$2"
      shift 2
      ;;
    -h|--help)
      help
      ;;
    -v|--version)
      version # TODO: not impl
      ;;
    --)
      shift;
      break
      ;;
  esac
done

db_resource="${1?Must provide resource}"

# XXX: This is for Zalando's PostgreSQL operator, but might need other paths for something else
json_db_to_user="$(kubectl ${namespace:+-n $namespace} get pg "$db_resource" -o json | jq '.spec.databases | to_entries[]' )"
# TODO: Why am I not using $database? How is it that I don't need it?
database="$(jq -r .key <<<"$json_db_to_user")"
user="$(jq -r .value <<<"$json_db_to_user")"
password="$(kubectl ${namespace:+-n $namespace} get secret "$user.$db_resource.credentials.postgresql.acid.zalan.do" -o 'jsonpath={.data.password}' | base64 -d)"

kubectl ${namespace:+-n $namespace} run "$db_resource-cli" --rm -i --image governmentpaas/psql -- psql "postgresql://$user:$password@$db_resource.${namespace:+$namespace.}svc:5432"
