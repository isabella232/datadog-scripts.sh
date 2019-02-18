#!/bin/bash

# datadog-boards.sh --download [ URL ] --output-dir ./boards
# datadog-boards.sh --upload ./boards/*.json

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
Always overwrite the monitor if it has been modified. When downloading, it will download
all monitors that changed
.TP
--download URL
Downloads the board corresponding to the URL passed in parameters and stores it
locally as JSON files in the current directory (which can be also specified using --output-dir)
.TP
--download-screenboard ID
Downloads the screenboard corresponding to the ID passed in parameters and stores it
locally as JSON files in the current directory (which can be also specified using --output-dir)
.TP
--download-timeboard ID
Downloads the timeboard corresponding to the ID passed in parameters and stores it
locally as JSON files in the current directory (which can be also specified using --output-dir)
.TP
--output-dir DIRECTORY
Optional. To be used with --download. Stores downloaded monitors in the specified directory instead of current.
.TP
--upload \fIfiles...
Uploads the boards described by the JSON files passed in arguments.
This will update boards that have a valid 'id' and create boards that don't have an 'id' attribute or that can't be found.
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

function board_md5 {
  jq 'del(.modified)' "$1" | openssl md5
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
      shift 2
      ;;
    --download-screenboard)
      action="download"
      board_type="screenboard"
      board_id=$2
      shift 2
      ;;
    --download-timeboard)
      action="download"
      board_type="dash"
      board_id=$2
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
    if [ $board_type = "screenboard" ]; then
      api_name="screen"
      title_attr=".board_title"
      jq_filter="{ id: .id, board_title: .board_title, description: .description, widgets: .widgets, template_variables: .template_variables, read_only: .read_only, modified: .modified }"
    elif [ $board_type = "dashboard" ]; then
      api_name="dash"
      title_attr=".title"
      jq_filter=".dash | { id: .id, title: .title, description: .description, graphs: .graphs, template_variables: .template_variables, modified: .modified }"
    fi

    remote_file=$(mktemp)
    curl --silent -X GET "https://api.datadoghq.com/api/v1/${api_name}/${board_id}?api_key=${api_key}&application_key=${app_key}" \
    | jq "$jq_filter" > $remote_file
    remote_md5=$(board_md5 "$remote_file")
    board_name=$(jq -r "$title_attr" $remote_file)
    board_id_found=$(jq '.id' $remote_file)

    if [ "$board_id_found" = "null" ]; then
      echo "[`basename $0`] Error: No board found matching ID $board_id" >&2
      exit 1
    fi

    local_file=$(echo [${board_type}] ${board_name}.json | sed 's/[\/:]//g')

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
    ;;
  upload)

    ;;
  *)
    echo "[`basename $0`] Error: Nothing to do. Check help (-h) for more info" >&2
    exit 1
    ;;
esac
