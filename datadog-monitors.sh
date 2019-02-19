#!/bin/bash

api_key=$DATADOG_API_KEY
app_key=$DATADOG_APP_KEY
action=""
directory=""
monitor_files=""
always_overwrite="n"

function show_help {
  cat <<EOF | nroff -man - | less
.TH $(basename $0) 1

.SH NAME
$(basename $0) \- Download and upload Datadog monitors

.SH SYNOPSIS
$(basename $0) --help

$(basename $0) [ --always ] --download QUERY [ --output-dir ... ]

$(basename $0) [ --always ] --upload \fIfiles...

.SH OPTIONS
.TP
-h|--help
Displays this page
.TP
-y|--always
Always download or upload the monitors without asking for confirmation
.TP
--download QUERY
Downloads the monitors matching the query passed in parameters and store
them locally as JSON files in the output directory (defaults to current directory)
.TP
--output-dir DIRECTORY
Optional. Used with --download. Stores downloaded monitors in the specified directory
.TP
--upload \fIfiles...
Uploads the monitors described by the JSON files passed in arguments.
This will update monitors that have a valid 'id' and create monitors that don't have an 'id' attribute
.TP
--api-key KEY
The API key provided by Datadog (https://app.datadoghq.com/account/settings#api)
which can also be passed as an environment parameter (\$DATADOG_API_KEY)
.TP
--app-key KEY
The application key provided by Datadog (https://app.datadoghq.com/account/settings#api)
which can also be passed as an environment parameter (\$DATADOG_APP_KEY)
.SH EXAMPLES
.TP
Downloads the monitor tagged with specific tags

.B $(basename $0)
--download "service:notonthehighstreet env:production"
--output-dir ./monitors
.TP
Update (or create) all the monitors stored as JSON files in datadog/monitors

.B $(basename $0)
--upload monitors/*.json
EOF
}

function curl_monitor {
  curl --silent -X GET "https://api.datadoghq.com/api/v1/monitor/${1}?api_key=${api_key}&application_key=${app_key}" \
  | jq '{ id: .id, name: .name, type: .type, query: .query, message: .message, tags: .tags, options: .options, modified: .modified } | del(.options.queryConfig)'
}

function monitor_md5 {
  jq 'del(.modified)' "$1" | openssl md5
}

function monitor_id {
  jq -r '.id' "$1"
}

function monitor_name {
  jq -r '.name' "$1"
}

function monitor_mdate {
  jq -r '.modified' "$1" | cut -c1-19 | sed 's/T/ /'
}

while (( "$#" )); do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    --download)
      # get a list of id & names of the monitors to download
      action="download"
      query=$(echo "$2" | sed "s/ /%20/g")
      shift 2
      ;;
    --output-dir)
      directory=$2
      shift 2
      ;;
    -y|--always)
      always_overwrite="y"
      shift 1
      ;;
    --api-key)
      api_key=$2
      shift 2
      ;;
    --app-key)
      app_key=$2
      shift 2
      ;;
    --upload)
      action="upload"
      shift 1
      break
      ;;
    *)
      echo "[`basename $0`] Error: Unsupported flag $1" >&2
      exit 1
      ;;
  esac
done

case "$action" in
  download)
    url="https://api.datadoghq.com/api/v1/monitor/search?api_key=${api_key}&application_key=${app_key}&query=${query}&per_page=500"
    IFS=$'\n'
    monitors=($(curl --silent -X GET -H 'Content-type: application/json' "$url" | jq -r '.monitors[] | [(.id | tostring), .name, .modified] | @tsv'))
    #
    # for each monitor, get the details and store locally
    #
    IFS=$'\t'
    for output in "${monitors[@]}"; do
      monitor=($output)
      monitor_id=${monitor[0]}
      monitor_name=${monitor[1]}
      local_file=$(echo ${monitor_name}.json | sed 's/[\/:]//g')

      if [ -n "$directory" ]; then
        local_file="$directory/$local_file"
      fi

      remote_file=$(mktemp)

      curl_monitor $monitor_id > $remote_file
      remote_md5=$(monitor_md5 $remote_file)
      remote_name=$(monitor_name $remote_file)
      remote_mdate=$(monitor_mdate $remote_file)

      if [ -f "$local_file" ]; then
        local_md5=$(monitor_md5 "$local_file")

        if [ "$remote_md5" != "$local_md5" ]; then
          #
          # the local copy is different from Datadog monitor
          #
          if [ "$always_overwrite" = "n" ]; then
            echo "Monitor changed \"$remote_name\""
            echo "Last Modified at $remote_mdate"
            diff "$local_file" $remote_file
            read -p "Overwite local copy ? (y/n) [y] " overwrite
            overwrite=${overwrite:-y}
          fi
          if [ "$always_overwrite" = "y" -o "$overwrite" = "y" ]; then
            cp $remote_file "$local_file" && \
            echo "Downloaded: $local_file"
          fi
        else
          echo "Not changed: $local_file"
        fi
      else
        #
        # there are no local copy - create one
        #
        cp $remote_file "$local_file" && \
        echo "Downloaded: $local_file"
      fi
      rm -f $remote_file
    done
    ;;
  upload)
    for local_file in "$@"; do
      monitor_id=$(monitor_id "$local_file")
      local_md5=$(monitor_md5 "$local_file")

      remote_file=$(mktemp)

      curl_monitor $monitor_id > $remote_file
      monitor_id_found=$(jq '.id' $remote_file)

      if [ "$monitor_id_found" != "null" ]; then
        #
        # Datadog monitor still exists - update it
        #
        remote_md5=$(monitor_md5 $remote_file)
        remote_name=$(monitor_name $remote_file)
        remote_mdate=$(monitor_mdate $remote_file)

        if [ "$remote_md5" != "$local_md5" ]; then
          if [ "$always_overwrite" = "n" ]; then
            echo "Monitor changed \"$remote_name\""
            echo "Last Modified at $remote_mdate"
            diff $remote_file "$local_file"
            read -p "Update Datadog monitor ? (y/n) [y] " overwrite
            overwrite=${overwrite:-y}
          fi
          if [ "$always_overwrite" = "y" -o "$overwrite" = "y" ]; then
            curl --silent --verbose -X PUT -H "Content-type: application/json" -d "@$local_file" "https://api.datadoghq.com/api/v1/monitor/${monitor_id}?api_key=${api_key}&application_key=${app_key}" 2>&1 \
            | grep "^< HTTP/1\.1 200" > /dev/null

            if [ "$?" = 0 ]; then
              echo "Updated: $remote_name"
            else
              echo "[Error] Failed to upload $local_file"
              exit 1
            fi
          fi
        else
          echo "Not changed: $remote_name"
        fi
      else
        #
        # Datadog monitor can't be found - create it
        #
        curl --silent -X POST -H "Content-type: application/json" -d "@$local_file" "https://api.datadoghq.com/api/v1/monitor?api_key=${api_key}&application_key=${app_key}" \
        | jq '{ id: .id, name: .name, type: .type, query: .query, message: .message, tags: .tags, options: .options }' 2>/dev/null > $remote_file

        if [ "$?" = 0 ]; then
          #
          # new monitor created - update local copy
          #
          cp $remote_file "$local_file" && \
          echo "Created $local_file"
        else
          echo "[Error] Failed to create $local_file"
          exit 1
        fi
      fi

      rm -f $remote_file
    done
    ;;
  *)
    echo "[`basename $0`] Error: Nothing to do. Check help (-h) for more info" >&2
    exit 1
    ;;
esac
