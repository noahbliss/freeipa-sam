#!/usr/bin/env bash
ssleval=true
prefix=ldaps
passeval() { [ -z $bindpass ] && passeval="UNSET!" || passeval="SET!"; }
ssleval() { [ "$prefix" == "ldaps" ] && ssleval="true" || ssleval="false"; }
actionseval() { [ "$ldapserver" ] && [ "$binduser" ] && [ "$domain" ] && [ "$passeval" == "SET!" ] && actionseval="ready" || actionseval="conditions not yet met" && return 1; }

menu() {
  passeval
  ssleval
  actionseval
  clear
  echo "\
### FreeIPA - System Account Manager ###
1.) ldapserver=$ldapserver
2.) domain=$domain (ldapdomain=$ldapdomain)
3.) binduser=$binduser
4.) bindpass=$passeval
5.) ssl=$ssleval

Actions ($actionseval):
  add | rm | ls | info | passwd

---   Results   ---
$results
--- End Results ---
"
}

domain2ldapdomain() {
   echo "${1}" | awk -F'.' '{for(i=1;i<=NF;i++) printf "dc="$i","; print ""}' | sed 's/,$//'
}

dotask() {
  case $1 in
# Setup
    1|ldapserver)
      read -p "ldapserver=" ldapserver
      [ -z $domain ] && domain=${ldapserver#*.} && ldapdomain=$(domain2ldapdomain "$domain")
      ;;
    2|domain)
      read -p "domain=" domain
      ldapdomain=$(domain2ldapdomain "$domain")
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
      [ "$prefix" == "ldaps" ] && prefix=ldap || prefix=ldaps
      ;;

# Actions
    # poc)
    #   results=$(ldapsearch "$prefix""://""$ldapserver" -b "$ldapdomain" -D "$binduser" -w "$bindpass")
    #   ;;
    ls)
      results=$(ldapsearch -H "$prefix""://""$ldapserver" -b "cn=sysaccounts,cn=etc,$ldapdomain" -D "$binduser" -w "$bindpass" "(uid=*)" "dn" | grep 'dn: uid')
      ;;
    info)
      [ "$2" ] && local uid="$2" || uid="*"
      results=$(ldapsearch -H "$prefix""://""$ldapserver" -b "cn=sysaccounts,cn=etc,$ldapdomain" -D "$binduser" -w "$bindpass" "(uid=$uid)" "uid" "memberOf" "passwordExpirationTime")
      ;;
    add)
      local uid password
      [ "$2" ] && local uid="$2" || read -p "uid of new user=" uid
      read -sp "password of new user (blank to generate a password)=" password
      [ -z "$password" ] && password=$(randpw) && echo && echo "Generated password: $password"
      echo
      read -p "password expiration date YYYYMMDD (blank for 20380119)=" expire
      [ -z "$expire" ] && expire=20380119
echo -E "\
dn: uid=$uid,cn=sysaccounts,cn=etc,$ldapdomain
changetype: add
objectclass: account
objectclass: simplesecurityobject
uid: $uid
userPassword: $password
passwordExpirationTime: ${expire}031407Z
nsIdleTimeout: 0" | ldapmodify -H "$prefix""://""$ldapserver" -D "$binduser" -w "$bindpass" && results="Submitted." || results="Error."
      ;;
    rm)
      local uid
      [ "$2" ] && local uid="$2" || read -p "uid of user to remove=" uid
echo -E "\
dn: uid=$uid,cn=sysaccounts,cn=etc,$ldapdomain
changetype: delete" | ldapmodify -H "$prefix""://""$ldapserver" -D "$binduser" -w "$bindpass" && results="Submitted." || results="Error."
      ;;
    passwd)
    local uid password
    [ "$2" ] && local uid="$2" || read -p "uid of user=" uid
    read -sp "new password for user (blank to generate a password)=" password
    [ -z "$password" ] && password=$(randpw) && echo && echo "Generated password: $password"
    echo
    read -p "password expiration date YYYYMMDD (blank for 20380119)=" expire
    [ -z "$expire" ] && expire=20380119
echo -E "\
dn: uid=$uid,cn=sysaccounts,cn=etc,$ldapdomain
changetype: modify
replace: userPassword
userPassword: $password
-
replace: passwordExpirationTime
passwordExpirationTime: ${expire}031407Z" | ldapmodify -H "$prefix""://""$ldapserver" -D "$binduser" -w "$bindpass" && results="Submitted." || results="Error."
      ;;
    exit)
      exit
      ;;
    "")
      results=""
      ;;
    *)
      results="\"$input\" command not found."
  esac
}

prompt() { read -p '> ' input; dotask $input; }
randpw() { < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-20};echo;}

while :; do
  menu
  prompt
done
