# Prerequisites

The scripts use `jq` to parse and manipulate the JSON content sent from/to the API.

```
brew install jq
```

# Installation

```
curl -L https://github.com/notonthehighstreet/datadog-scripts.sh/raw/master/datadog-monitors.sh \
> /usr/local/bin/datadog-monitors.sh \
&& chmod +x /usr/local/bin/datadog-monitors.sh
```

```
curl -L https://github.com/notonthehighstreet/datadog-scripts.sh/raw/master/datadog-dashboards.sh \
> /usr/local/bin/datadog-dashboards.sh \
&& chmod +x /usr/local/bin/datadog-dashboards.sh
```

# Example

```
export DATADOG_API_KEY=...
export DATADOG_APP_KEY=...
datadog‐monitors.sh ‐‐download "service:notonthehighstreet" ‐‐output‐dir monitors
```

# datadog-monitors.sh --help

```
datadog‐monitors.sh(1)                                  datadog‐monitors.sh(1)



NAME
       datadog‐monitors.sh − Download and upload Datadog monitors


SYNOPSIS
       datadog‐monitors.sh ‐‐help

       datadog‐monitors.sh [ ‐‐always ] ‐‐download QUERY [ ‐‐output‐dir ... ]

       datadog‐monitors.sh [ ‐‐always ] ‐‐upload files...


OPTIONS
       ‐h|‐‐help
              Displays this page

       ‐y|‐‐always
              Always overwrite the monitor if it has been modified. When down‐
              loading, it will download all monitors that changed

       ‐‐download QUERY
              Downloads the monitors matching the query passed  in  parameters
              and  store  them  locally as JSON files in the current directory
              (which can be also specified using ‐‐dir)

       ‐‐output‐dir DIRECTORY
              Optional. To be used with ‐‐download. Stores downloaded monitors
              in the specified directory instead of current.

       ‐‐upload files...
              Uploads the monitors described by the JSON files passed in argu‐
              ments.  This will update monitors that have  a  valid  ’id’  and
              create monitors that don’t have an ’id’ attribute.

       ‐‐api‐key KEY
              The    API    key   provided   by   Datadog   (https://app.data‐
              doghq.com/account/settings#api) which can also be passed  as  an
              environment parameter ($DATADOG_API_KEY)

       ‐‐app‐key KEY
              The  application  key  provided  by  Datadog  (https://app.data‐
              doghq.com/account/settings#api) which can also be passed  as  an
              environment parameter ($DATADOG_APP_KEY)

EXAMPLES
       Downloads the monitor tagged with specific tags

              datadog‐monitors.sh    ‐‐download    "service:notonthehighstreet
              env:production" ‐‐output‐dir ./monitors

       Update (or create) all the monitors  stored  as  JSON  files  in  data‐
       dog/monitors

              datadog‐monitors.sh ‐‐upload monitors/*.json



                                                        datadog‐monitors.sh(1)
```

# datadog-dashboards.sh --help

```
datadog‐dashboards.sh(1)                              datadog‐dashboards.sh(1)



NAME
       datadog‐dashboards.sh  −  Download  and  upload  Datadog  timeboards  &
       screenboards


SYNOPSIS
       datadog‐dashboards.sh ‐‐help

       datadog‐dashboards.sh [ ‐‐always ] ‐‐download URL [ ‐‐output‐dir ... ]

       datadog‐dashboards.sh [ ‐‐always ] ‐‐upload files...


OPTIONS
       ‐h|‐‐help
              Displays this page

       ‐y|‐‐always
              Always download or upload the dashboards without asking for con‐
              firmation

       ‐‐download URL
              Downloads  the  dashboard  corresponding  to  the  URL passed in
              parameters and stores it locally as JSON  files  in  the  output
              directory (defaults to current directory)

       ‐‐download‐screenboard ID
              Downloads  the  screenboard  corresponding  to  the ID passed in
              parameters and stores it locally as JSON  files  in  the  output
              directory (defaults to current directory)

       ‐‐download‐timeboard ID
              Downloads the timeboard corresponding to the ID passed in param‐
              eters and stores it locally as JSON files in the  output  direc‐
              tory (defaults to current directory)

       ‐‐download‐list LIST‐ID
              Downloads  the dashboards added to the list passed in parameters
              and stores them locally as JSON files in  the  output  directory
              (defaults to current directory)

       ‐‐output‐dir DIRECTORY
              Optional.  Use  with ‐‐download. Stores downloaded dashboards in
              the specified directory

       ‐‐upload files...
              Uploads the boards described by the JSON files passed  in  argu‐
              ments.   This will update boards that have a valid ’id’ and cre‐
              ate boards that don’t have an ’id’ attribute or  that  can’t  be
              found

       ‐‐api‐key KEY
              The    API    key   provided   by   Datadog   (https://app.data‐
              doghq.com/account/settings#api) which can also be passed  as  an
              environment parameter ($DATADOG_API_KEY)

       ‐‐app‐key KEY
              The  application  key  provided  by  Datadog  (https://app.data‐
              doghq.com/account/settings#api) which can also be passed  as  an
              environment parameter ($DATADOG_APP_KEY)

EXAMPLES
       Downloads the dashboards in a list

              datadog‐dashboards.sh ‐‐download‐list 1234 ‐‐output‐dir ./boards

       Downloads the dashboard at URL

              datadog‐dashboards.sh        ‐‐download        https://app.data‐
              doghq.com/dash/1234/my‐own‐timeboard ‐‐output‐dir ./boards


       Update  (or  create)  all  the  monitors  stored as JSON files in data‐
       dog/monitors

              datadog‐dashboards.sh ‐‐upload boards/*.json



                                                      datadog‐dashboards.sh(1)
```
