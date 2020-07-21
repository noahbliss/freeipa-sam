#!/usr/bin/env bash
ssleval=true
prefix=https
passeval() { [ -z $bindpass ] && passeval="UNSET!" || passeval="SET!"; }
ssleval() { [ "$prefix" == "https" ] && ssleval="true" || ssleval="false"; }
actionseval() { [ "$ldapserver"] && [ "$binduser" ] && [ "$domain" ] && [ "$passeval" ] && actionseval="ready" || actionseval="conditions not yet met" && return 1; }

menu() {
  passeval
  ssleval
  actionseval
  clear
  echo "\
### Main Menu ###
1.) ldapserver=$ldapserver
2.) domain=$domain (ldapdomain=$ldapdomain)
3.) binduser=$binduser
4.) bindpass=$passeval
5.) ssl=$ssleval

Actions ($actionseval):
  poc | add | rm | ls | info | passwd

---   Results   ---
$results
--- End Results ---
"
}

dotask() {
  case $1 in
# Setup
    1|ldapserver)
      read -p "ldapserver=" ldapserver
      [ -z $domain ] && domain=${ldapserver#*.} && ldapdomain=$(echo "$domain" | awk -F'.' '{ print "dc="$1",dc="$2}')
      ;;
    2|domain)
      read -p "domain=" domain
      ldapdomain=$(echo "$domain" | awk -F'.' '{ print "dc="$1",dc="$2}')
      #read -p "ldapdomain=" ldapdomain
      ;;
    3|binduser)
      [ -z $domain ] && echo "We need the domain first." &&  dotask domain
      echo "Enter \"mgr\" for Directory Manager. Otherwise enter the username or full binddn (-D option in ldapsearch)"
      read -p "binduser=" swap
      [ "$swap" == "mgr" ] && binduser='cn=Directory Manager' && return
      echo "$swap" | grep '=' -q && binduser="$swap" || binduser="uid=$swap,cn=users,cn=accounts,$ldapdomain"
      ;;
    4|bindpass)
      read -sp "Enter password (will not echo): " bindpass
      ;;
    5|ssl)
      [ "$prefix" == "https" ] && prefix=http || prefix=https
      ;;

# Actions
    poc)
      results=$(ldapsearch "$prefix""://""$ldapserver" -b "$ldapdomain" -D "$binduser" -w "$bindpass")
      ;;



    exit)
      exit
      ;;
    *)
      results="\"$input\" command not found."
  esac
}

prompt() { read -p '> ' input; dotask $input; }

while :; do
  menu
  prompt
done
