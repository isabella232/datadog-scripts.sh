# Installation

```
curl -L https://github.com/notonthehighstreet/datadog-monitors.sh/raw/master/datadog-monitors.sh \
> /usr/local/bin/datadog-monitors.sh \
&& chmod +x /usr/local/bin/datadog-monitors.sh
```

# Documenation

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
