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
$(basename $0) \- Download and upload Datadog timeboards & screenboards

.SH SYNOPSIS
$(basename $0) --help

$(basename $0) [ --always ] --download URL [ --output-dir ... ]

$(basename $0) [ --always ] --upload \fIfiles...

.SH OPTIONS
.TP
-h|--help
Displays this page
.TP
-y|--always
Always download or upload the dashboards without asking for confirmation
.TP
--download URL
Downloads the dashboard corresponding to the URL passed in parameters and stores it
locally as JSON files in the output directory (defaults to current directory)
.TP
--download-screenboard ID
Downloads the screenboard corresponding to the ID passed in parameters and stores it
locally as JSON files in the output directory (defaults to current directory)
.TP
--download-timeboard ID
Downloads the timeboard corresponding to the ID passed in parameters and stores it
locally as JSON files in the output directory (defaults to current directory)
.TP
--download-list LIST-ID
Downloads the dashboards added to the list passed in parameters and stores them
locally as JSON files in the output directory (defaults to current directory)
.TP
--output-dir DIRECTORY
Optional. Use with --download. Stores downloaded dashboards in the specified directory
.TP
--upload \fIfiles...
Uploads the boards described by the JSON files passed in arguments.
This will update boards that have a valid 'id' and create boards that don't have an 'id' attribute or that can't be found
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
Downloads the dashboards in a list

.B $(basename $0)
--download-list 1234
--output-dir ./boards
.TP
Downloads the dashboard at URL

.B $(basename $0)
--download https://app.datadoghq.com/dash/1234/my-own-timeboard
--output-dir ./boards

.TP
Update (or create) all the monitors stored as JSON files in datadog/monitors

.B $(basename $0)
--upload boards/*.json
EOF
}

function board_md5 {
  jq 'del(.modified)' "$1" | openssl md5
}

function board_mdate {
  jq -r '.modified' "$1" | cut -c1-19 | sed 's/T/ /'
}

function board_id {
  jq -r '.id' "$1"
}

function board_name {
  jq -r '.title + .board_title' "$1"
}

function curl_board {
  board_type=$1
  board_id=$2

  if [ $board_type = "screen" ]; then
    jq_filter="{ id: .id, board_type: \"${board_type}\", board_title: .board_title, description: .description, widgets: .widgets, template_variables: .template_variables, read_only: .read_only, modified: .modified }"
  elif [ $board_type = "dash" ]; then
    jq_filter=".dash | { id: .id, board_type: \"${board_type}\", title: .title, description: .description, graphs: .graphs, template_variables: .template_variables, modified: .modified }"
  fi

  curl --silent -X GET "https://api.datadoghq.com/api/v1/${board_type}/${board_id}?api_key=${api_key}&application_key=${app_key}" | jq "$jq_filter"
}

function board_type {
  jq -r '.board_type' "$1"
}

function curl_list_items {
  list_id=$1
  curl --silent -X GET "https://api.datadoghq.com/api/v1/dashboard/lists/manual/${list_id}/dashboards?api_key=${api_key}&application_key=${app_key}" \
    | jq -r ".dashboards[] | ((.id | tostring) + (.type | gsub(\"(custom_|board)\";\" \") | gsub(\"time\";\"dash\")))"
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
      url="$2"
      board_type=$(echo "$url" | sed -E 's$https://app.datadoghq.com/(screen|dashboard)/([^/]+)/.+$\1$')
      board_id=$(echo "$url"   | sed -E 's$https://app.datadoghq.com/(screen|dashboard)/([^/]+)/.+$\2$')
      if [ -z "$board_type" -o -z "$board_id" ]; then
        echo "[`basename $0`] Error: Unrecognised URL" >&2
        exit 1
      fi
      boards="${board_id} ${board_type}"
      shift 2
      ;;
    --download-screenboard)
      action="download"
      board_type="screen"
      board_id=$2
      shift 2
      ;;
    --download-timeboard)
      action="download"
      board_type="dash"
      board_id=$2
      shift 2
      ;;
    --download-list)
      action="download"
      list_id=$2
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
    if [ -n "$list_id" ]; then
      boards=$(curl_list_items $list_id)
    fi

    IFS=$'\n'
    for board in $boards; do
      board_id=$(echo $board | awk '{ print $1 }')
      board_type=$(echo $board | awk '{ print $2 }')

      remote_file=$(mktemp)

      curl_board ${board_type} ${board_id} > $remote_file
      remote_md5=$(board_md5 $remote_file)
      board_name=$(board_name $remote_file)
      board_id_found=$(jq '.id' $remote_file)

      if [ "$board_id_found" = "null" ]; then
        echo "[`basename $0`] Error: No board found matching ID $board_id" >&2
        exit 1
      fi

      local_file=$(echo ${board_type} - ${board_name}.json | sed 's/[\/:]//g')

      if [ -n "$directory" ]; then
        local_file="$directory/$local_file"
      fi

      if [ -f "$local_file" ]; then
        local_md5=$(board_md5 "$local_file")

        if [ "$remote_md5" != "$local_md5" ]; then
          #
          # the local copy is different from Datadog monitor
          #
          if [ "$always_overwrite" = "n" ]; then
            echo "Board changed \"$board_name\""
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
        local_md5=$(board_md5 "$local_file")
        board_id=$(board_id "$local_file")
        board_type=$(board_type "$local_file")

        remote_file=$(mktemp)

        curl_board $board_type $board_id > $remote_file
        board_id_found=$(board_id $remote_file)

        if [ "$board_id_found" != "null" ]; then
          #
          # Datadog dashboard still exists - update it
          #
          remote_md5=$(board_md5 $remote_file)
          remote_name=$(board_name $remote_file)
          remote_mdate=$(board_mdate $remote_file)

          if [ "$remote_md5" != "$local_md5" ]; then
            if [ "$always_overwrite" = "n" ]; then
              echo "Dashboard changed \"$remote_name\""
              echo "Last Modified at $remote_mdate"
              diff $remote_file "$local_file"
              read -p "Update Datadog dashboard ? (y/n) [y] " overwrite
              overwrite=${overwrite:-y}
            fi
            if [ "$always_overwrite" = "y" -o "$overwrite" = "y" ]; then
              curl --silent --verbose -X PUT -H "Content-type: application/json" -d "@$local_file" "https://api.datadoghq.com/api/v1/${board_type}/${board_id}?api_key=${api_key}&application_key=${app_key}" 2>&1 \
              | grep "^< HTTP/1\.1 200" > /dev/null

              if [ "$?" = 0 ]; then
                echo "Updated: https://app.datadoghq.com/${board_type}/${board_id}"
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
          board_id=$(curl --silent -X POST -H "Content-type: application/json" -d "@$local_file" "https://api.datadoghq.com/api/v1/${board_type}?api_key=${api_key}&application_key=${app_key}" \
            | jq -r '.id' 2>/dev/null)
          curl_board $board_type $board_id > $remote_file

          if [ "$?" = 0 ]; then
            #
            # new monitor created - update local copy
            #
            cp $remote_file "$local_file" && \
            echo "Created: https://app.datadoghq.com/${board_type}/${board_id}"
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
