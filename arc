#!/bin/bash
# arc-cli by Danny Wahl dwahl@instructure.com
# a simple tool to help interact
# with the arc API
# (https://instructure.instructuremedia.com/api/docs/)

# HELPER FUNCTIONS #############################################################
# ##############################################################################

dependency() {
  declare -a dep=("$@")
  command -v ${dep[2]} > /dev/null 2>&1 || prompt ${dep[@]}
}

prompt() {
  declare -a dep=("$@")
  clear
  echo >&2 "arc-cli requires ${dep[1]} (${dep[3]}) but it's not installed"
  echo >&2 "would you like to install it now?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) install ${dep[@]}; dependency ${dep[@]}; break;;
      No ) manualinstall ${dep[@]}; exit;;
    esac
  done
}

install() {
  declare -a dep=("$@")
  clear
  echo >&2 "arc-cli will attempt to install ${dep[1]} (${dep[3]})"
  hr
  if [ ${dep[3]} = "npm" ]; then
    command -v ${dep[3]} > /dev/null 2>&1 && npm install -g "${dep[1]}" || manualinstall ${dep[@]} ""
  elif [ ${dep[3]} = "pip" ]; then
    command -v ${dep[3]} > /dev/null 2>&1 && pip install "${dep[1]}" || manualinstall ${dep[@]} ""
  else
    manualinstall ${dep[@]} ""
  fi
  local status=$(echo $?)
  if [ "$status" -gt 0 ]; then
    manualinstall ${dep[@]} $status
  fi
  hr
  echo >&2 "${dep[1]} (${dep[3]}) successfully installed"
}

manualinstall() {
  declare -a dep=("$@")
  if [ ${#dep[@]} -gt 4 ]; then
    hr
    echo "arc-cli was unable to install ${dep[1]} (${dep[3]})"
    if [ ${dep[3]} = "npm" ]; then
      echo >&2 "\`npm install -g ${dep[1]}\` failed"
    elif [ ${dep[3]} = "pip" ]; then
      echo >&2 "\`pip install ${dep[1]}\` failed"
    else
      echo >&2 "\`curl\` is a system package"
    fi
  fi
  if [ ${dep[3]} = "npm" ]; then
    echo >&2 "Try using \`npm install -g ${dep[1]}\` to manually install"
  elif [ ${dep[3]} = "pip" ]; then
    echo >&2 "Try using \`pip install ${dep[1]}\` to manually install"
  else
    echo >&2 "${dep[1]} must be installed using a system package manager"
  fi
  exit 127
}

hr() {
  local start=$'\e(0' end=$'\e(B' line='qqqqqqqqqqqqqqqq'
  local cols=${COLUMNS:-$(tput cols)}
  while ((${#line} < cols)); do line+="$line"; done
  echo >&2 ""
  printf '%s%s%s\n' "$start" "${line:0:cols}" "$end"
  echo >&2 ""
}

outputrenderer="| json | pygmentize -l json"
setrenderer() {
  local renderer="$1"
  case $renderer in
    "plain")
      outputrenderer="; echo -e \"\n\"" ;;
    "color")
      outputrenderer="| json | pygmentize -l json" ;;
    *)
      echo >&2 "invalid argument \`$renderer\` for \`-r\`" && usage && exit 2 ;;
  esac
}

httpmethod="GET"
sethttp() {
  local http="$1"
  case $http in
    "get"|"GET")
      httpmethod="GET" ;;
    "post"|"POST")
      httpmethod="POST" ;;
    "put"|"PUT")
      httpmethod="PUT" ;;
    "delete"|"DELETE")
      httpmethod="DELETE" ;;
    *)
      echo >&2 "invalid argument \`$http\` for \`-x\`" && usage && exit 2 ;;
  esac
}

# HELP STUFF ###################################################################
# ##############################################################################

help() {
  usage
  exit;
}

verbosehelp() {
  echo "Usage: $0 -p :<path> [-x ::<HTTP>] [-t <token>] [-d :<domain>] [-o :<path>] [-r ::<render>] [curl opts] [-c :config]" | less
  exit;
}

usage() {
  echo -e 2>&1 "Usage: $0 ...\r\nHelp:  $0 -h"
}

version() {
  echo >&2 "arc-cli version 0.1"
  exit
}

license() {
  echo 2>&1 "LICENSE TEXT" | less
  exit
}

examples() {
  echo >&2 "$0 courses";
  echo >&2 "$0 -x PUT users/self/settings -F 'manual_mark_as_read=false'";
  echo >&2 "$0 <token> DELETE <domain> users/self/activity_stream";
  echo >&2 "$0 <token> POST <domain> users/self/files -F 'url=http://www.canvaslms.com/img/logo_instructure.png' -F 'name=instructure.png'";
}

# HANDLE DEPENDENCIES ##########################################################
# Requires: jsontool (npm), pygmentize (pip), curl, and getopts                #
# ##############################################################################

# null | name | executable | repository
# `null` is a hacky shift to avoid string manipulation of
# multi-dimensional array when passed as a parameter
json=("" "json" "json" "npm")
pygments=("" "pygments" "pygmentize" "pip")
shellgetopts=("" "getopts" "getopts" "system")
curl=("" "curl" "curl" "system")
dependencies=(JSON=${json[@]} PYGMENTS=${pygments[@]} SHELLGETOPTS=${shellgetopts[@]} CURL=${curl[@]})
for dep in "${dependencies[@]}"
  do dependency ${dep[@]}
done

# PREF FILE ####################################################################
# ##############################################################################

arc_domain=""
arc_email=""
arc_password=""
readconfig() {
  if [ -f ~/.inst ]; then
    . ~/.inst
    if [ -z $arc_domain ]; then
      echo >&2 "unable to read domain from config file \`~/.inst\`"
      echo >&2 "It must be manually added or repaired.  Format:"
      echo >&2 "arc_domain=\"<domain>\""
      exit 2
    fi
    if [ -z $arc_email ]; then
      echo >&2 "unable to read token from config file \`~/.inst\`"
      echo >&2 "It must be manually added or repaired.  Format:"
      echo >&2 "arc_email=\"<token>\""
      exit 2;
    fi
    if [ -z $arc_password ]; then
      echo >&2 "unable to read token from config file \`~/.inst\`"
      echo >&2 "It must be manually added or repaired.  Format:"
      echo >&2 "arc_password=\"<token>\""
      exit 2;
    fi
  else
    clear
    echo >&2 "config file \`~/.inst\` not found"
    echo >&2 "would you like to create it now?"
    select yn in "Yes" "No"; do
      case $yn in
        Yes )
          setconfig; break ;;
        No )
          clear
          echo >&2 "arc-cli requires a config file or use \`-d\`, \`-e\`, and \`-p\`"
          usage; exit 2 ;;
      esac
    done
  fi
}

setconfig() {
  clear
  echo -e "DO NOT create a config file on a shared system"
  echo >&2 "other system users will be able to authenticate using your"
  echo >&2 "saved credentials.  Instead use the \`-d\`, \`-e\`, and \`-p\` options"
  echo >&2 "Do you wish to proceed?"
  select ok in "Okay" "Cancel"; do
    case $ok in
      Okay)
        touch ~/.inst
        if [ $? = 0 ]; then
          setdomain
          setemail
          setpassword
          readconfig
        else
          clear
          echo >&2 "unable to create config file \`~/.inst\`"
          echo >&2 "please ensure that you have appropriate permissions"
          exit 2
        fi; break;;
      Cancel)
        clear
        echo >&2 "Enter your command again using the \`-d\`, \`-e\`, and \`-p\` options"
        usage;
        exit 0;;
    esac
  done
  clear
}

setdomain() {
  clear
  echo >&2 "what is your arc subdomain?"
  echo >&2 "https://<subdomain>.instructuremedia.com"
  read arcdomain
  echo "arc_domain=\"$arcdomain\"" >> ~/.inst
}

setemail() {
  clear
  echo >&2 "What is your arc login email address?"
  read arcemail
  echo >&2 "arc_email=\"$arcemail\"" >> ~/.inst
}

setpassword() {
  clear
  echo >&2 "What is your arc login password?"
  read arcpassword
  echo >&2 "arc_password=\"$arcpassword\"" >> ~/.inst
}

# OUTPUT FILE ##################################################################
# ##############################################################################

outputpath=""
setoutput() {
  if [ -f $1 ]; then
    clear
    echo "\`$1\` exists, overwrite it?"
    select ow in "Yes" "No"; do
      case $ow in
        Yes )
          outputpath="> $1"; break ;;
        No )
          echo >&2 "will not overwrite file."
          exit 1
      esac
    done
  else
    outputpath="> $1"
  fi
}
# PARSE OPTS ###################################################################
# ##############################################################################

curlopts=""
if [ $# -eq 0 ] && [ ! -f ~/.inst ]; then
  readconfig
  help
elif [ $# -eq 0 ] && [ -f ~/.inst ]; then
  help
else
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    while getopts ":hlvcr:x:e:p:d:o:F:" opt; do
      case $opt in
        h)
          verbosehelp ;;
        l)
          license ;;
        v)
          version ;;
        c)
          setconfig ;;
        r)
          setrenderer $OPTARG ;;
        x)
          sethttp $OPTARG ;;
        d)
          arc_domain="$OPTARG" ;;
        e)
          arc_email="$OPTARG" ;;
        p)
          arc_password="$OPTARG" ;;
        o)
          setoutput $OPTARG;;
        F)
          # -F opts are concatenated and
          # transparently passed to curl
          curlopts="$curlopts -F $OPTARG" ;;
        \?)
          echo >&2 "invalid option: \`-$OPTARG\`" && usage && exit 2 ;;
        :)
          echo >&2 "missing argument for \`-$OPTARG\`" && usage && exit 2 ;;
      esac
    done
    shift $((OPTIND-1))
    if [ $# -gt 0 ] && ! [[ "$1" =~ ^- ]]; then
      path="$1"
      shift
      break
    else
      echo "No API method provided!"
      usage
      exit 2
    fi
  done
  if [ "$1" == "--" ]; then
    shift
    path=("${path[@]}" "$@")
  fi
fi

# BUILD COMMAND ################################################################
# ##############################################################################

if [ -z "$arc_domain" ] && [ -z "$arc_email" ] && [ -z "$arc_password" ]; then
  readconfig
elif [ -z "$arc_domain" ] || [ -z "$arc_email" ] || [ -z "$arc_password" ]; then
  echo >&2 "\`-d\`, \`-e\`, and \`-p\` are required when not using a config file"
  usage
  exit 2
fi

if [ -n "$outputpath" ] && [ -n "$outputrenderer" ]; then
  outputrenderer=""
fi

# START SESSION ################################################################
# ##############################################################################
# TODO: ERROR HANDLING

session=""
userid=""
token=""
session=$(curl --tlsv1.2 --retry 2 --retry-connrefused -s -S -g -H "Content-Type: application/json" --data '{"email":"'$arc_email'","password":"'$arc_password'"}' -X POST https://$arc_domain.instructuremedia.com/api/auth/session)
token=$(echo "$session" | python -c 'import sys, json; print json.load(sys.stdin)["session"]["token"]')
userid=$(echo "$session" | python -c 'import sys, json; print json.load(sys.stdin)["session"]["user"]["id"]')

# RUN QUERY ####################################################################
# ##############################################################################

command="curl --tlsv1.2 --retry 2 --retry-connrefused -s -S -g -H 'Authorization: Bearer user_id=\"$userid\", token=\"$token\"' -X $httpmethod https://$arc_domain.instructuremedia.com/api/$path$curlopts $outputrenderer $outputpath"
eval $command
