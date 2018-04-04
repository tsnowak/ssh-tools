#!/bin/bash

# Request Information
# _________________
# computer
# username
# --[ call Keyfile ]
#
# computer on local network
# - currently behind local network
#   -> update ssh-command
#
# scan config file for computer <- check for host in config file function
# - computer exists in config
#   -> fill in gaps
# - computer doesn't exist
#   -> request all information
#
# scan config file for Match case <- check for match case in config file function
# - Match case exists for the computer
#   -> fill in gaps
# - Match case doesn't exit
#   -> request all information
#
# update ssh-command
#
# -- [ call Authorized_keys ]
#
# -- [ call Update Config File ]

# Keyfile
# _________________
# use unique key file?
#  - yes
#   -> check if exists, if not make
# - no
#   -> check if id-rsa exists, if not make

# Authorized_keys
# _________________
# use ssh command information and key-file specified
# check if .pub exists in authorized_keys
# - yes
#   -> do nothing
# - no
#   -> copy .pub to authorized_keys

# Update config file
# _________________
# where computer case exists or before marker <- overwrite or write host to config function
#   -> apply Host config information
#
# if computer in local network
# where computer match case exists or before host <- overwrite or write match case to config function
#   -> apply Match case config information

# YES NO

# REQUEST

# GET CONFIG PARAGRAPH

## High Level Command Flags ##

# Add Computer (-a)
# _________________
# Request Information
# Authorized Keys
# Update Config File

# Remove Computer (-r)
# _________________
# Computer name
#
# Removed from authorized_keys
# Remove key-file
# Remove from config

# Update Across Computers (-u)
# how could I do this?
# -> keep track of a data base on server and reference?
#
# Computer config paragraph(s) [host or host and match]
#
# For each entry in database but not in local config
# -> add paragraph
# -> make keyfile (or use) specified in config paragraph
# -> add to authorized_keys


COMPUTER=""
USER=""
LOC_IP=""
LOC_PORT=""
PUB_IP=""
PUB_PORT=""

LOCAL="false"
KEY_PATH=""
SSH_COMMAND=""

VERIFY_NETWORK_CMD=/usr/local/bin/verify_local_network

# Arguments:
# 1: Query yes/no question sentence (ex: "$QUERY")
# 2: Boolean response variable (ex: LOCAL)
YES_NO() {

    # dereference variable
    y=\$"$2"
    #echo $y
    x=`eval "expr \"$y\" "`
    #echo $2=$x

    # query input
    read -r -p "$1" response
    case "$response" in
        [yY][eE][sS]|[yY])
        # assign dereferenced value
        eval "$2=\"true\""
        ;;
        *)
        eval "$2=\"false\""
        ;;
    esac
}

# TODO: check backspace issue on Ubuntu
# Arguments:
# 1: Query question sentence (ex: "$QUERY")
# 2: Reponse Variable (ex: COMPUTER)
REQUEST() {

    # dereference variable
    y=\$"$2"
    #echo $y
    x=`eval "expr \"$y\" "`
    #echo $2=$x

    echo -n "$1";
    eval "read $2"
}

# TODO: handle duplicates with same username?
# Arguments:
# 1: "Host " or "Match originalhost " i.e. paragraph to get (ex: "$INPUT")
# 2: $COMPUTER to fetch (ex: "$COMPUTER")
# 3: Variable in which to store read paragraph (ex: PARAGRAPH)
GET_CONFIG_PARAGRAPH() {

    FILE=~/.ssh/config

    # dereference variable
    y=\$"$4"
    #echo $y
    x=`eval "expr \"$y\" "`
    #echo $2=$x
    # TODO change config to ~/.ssh/config
    eval "$4=\"$(cat $FILE | awk -v RS="" -v expr="$1$2" \
    -v user="User $3" '{ if ($0 ~ expr && $0 ~ user) print$0 }')\""
}

# Removes Host and Match cases for computer+user from config and creates .bak
REMOVE_CONFIG_PARAGRAPHS() {

    # TODO change config
    FILE=~/.ssh/config

    HOST_EXPR="Host "
    MATCH_EXPR="Match originalhost "

    cp $FILE $FILE.bak

    if [ -f $FILE.tmp ]; then
        rm $FILE.tmp
    fi

    # if the expression is not in the paragraph, append it to $FILE.tmp
    awk -v RS="" -v expr1="$HOST_EXPR$1" -v expr2="$MATCH_EXPR$1" \
    -v user="User $2" \
    '{ if (! (($0 ~ expr1 || $0 ~ expr2) && $0 ~ user)) print$0 "\n"}' \
    $FILE >> $FILE.tmp

    chmod 600 $FILE.tmp

    mv $FILE.tmp $FILE
}

INITIALIZE_SPACE() {
    mkdir -p ~/.ssh/keys
    touch ~/.ssh/authorized_keys
    touch ~/.ssh/config # add markers -> make function for this?
    touch ~/.ssh/known_hosts
}

GENERATE_KEYFILE() {

    QUERY="Would you like to use a unique keyfile for this computer? [y/N] "
    YES_NO "$QUERY" UNIQUE_KEY

    if $UNIQUE_KEY; then
        KEY_PATH=~/.ssh/keys/$COMPUTER/$COMPUTER
        mkdir -p ~/.ssh/keys/$COMPUTER
    else
        KEY_PATH=~/.ssh/id_rsa
    fi

    if [ ! -f $KEY_PATH ]; then
        QUERY="Enter the desired password for the ssh-key [ENTER] (Default: ''): "
        REQUEST "$QUERY" PW
        ssh-keygen -t rsa -N "$PW" -C "$USER" -f $KEY_PATH
    fi
}

UPDATE_AUTHORIZED_KEYS() {

    PUB_KEY=$KEY_PATH.pub

    # just storing in variables for ease of debugging
    PUB_KEY_CONTENT=$(cat $PUB_KEY)
    ssh $SSH_COMMAND "mkdir -p ~/.ssh; touch \
    ~/.ssh/authorized_keys; grep -Fq '$PUB_KEY_CONTENT' ~/.ssh/authorized_keys \
    || echo '$PUB_KEY_CONTENT' >> ~/.ssh/authorized_keys"
}

GATHER_INFORMATION() {
    MATCH_CASE="false"
    SSH_LOCAL="false"

    QUERY="Enter the name of the computer you want to add and press [ENTER]: "
    REQUEST "$QUERY" COMPUTER

    QUERY="Enter the username on $COMPUTER that you want to add and press [ENTER]: "
    REQUEST "$QUERY" USER

    GENERATE_KEYFILE

    QUERY="Is $COMPUTER on a local network? [y/N]: "
    YES_NO "$QUERY" LOCAL
    if $LOCAL; then
        MATCH_CASE="true"
        QUERY="Are you also on this local network currently? [y/N]: "
        YES_NO "$QUERY" SSH_LOCAL
        # can I change ssh_command here?
        # - I need the IPs unfortunately
    fi

    if $MATCH_CASE; then
        INPUT="Match originalhost "
        GET_CONFIG_PARAGRAPH "$INPUT" "$COMPUTER" "$USER" MATCH_PARAGRAPH

        LOC_IP=$(echo "$MATCH_PARAGRAPH" | awk '/HostName/{print $2}')
        if [ -z "$LOC_IP" ]; then
            QUERY="Enter the local IP of $COMPUTER [ENTER]: "
            REQUEST "$QUERY" LOC_IP
        fi
        LOC_PORT=$(echo "$MATCH_PARAGRAPH" | awk '/Port/{print $2}')
        if [ -z "$LOC_PORT" ]; then
            QUERY="Enter the open local port for $COMPUTER [ENTER]: "
            REQUEST "$QUERY" LOC_PORT
        fi
    fi

    INPUT="Host "
    GET_CONFIG_PARAGRAPH "$INPUT" "$COMPUTER" "$USER" HOST_PARAGRAPH

    PUB_IP=$(echo "$HOST_PARAGRAPH" | awk '/HostName/{print $2}')
    if [ -z "$PUB_IP" ]; then
    	QUERY="Enter the public IP of $COMPUTER [ENTER]: "
        REQUEST "$QUERY" PUB_IP
    fi
    PUB_PORT=$(echo "$HOST_PARAGRAPH" | awk '/Port/{print $2}')
    if [ -z "$PUB_PORT" ]; then
    	QUERY="Enter the open public port for $COMPUTER [ENTER]: "
        REQUEST "$QUERY" PUB_PORT
    fi

    # KEY_PATH as global variable?
    if $SSH_LOCAL; then
        SSH_COMMAND="-i $KEY_PATH -p $LOC_PORT $USER@$LOCAL_IP"
    else
        SSH_COMMAND="-i $KEY_PATH -p $PUB_PORT $USER@$PUB_IP"
    fi
}

UPDATE_CONFIG_FILE() {
    SED="$(which sed)"

    FILE=~/.ssh/config

    HOST_PARAGRAPH=""
    MATCH_PARAGRAPH=""

    INPUT="Host "
    GET_CONFIG_PARAGRAPH "$INPUT" "$COMPUTER" "$USER" HOST_PARAGRAPH
    INPUT="Match originalhost "
    GET_CONFIG_PARAGRAPH "$INPUT" "$COMPUTER" "$USER" MATCH_PARAGRAPH

    # Take out in final
    REMOVE_CONFIG_PARAGRAPHS "$COMPUTER" "$USER"

    REPLACEMENT_MATCH="Match originalhost $COMPUTER exec $VERIFY_NETWORK_CMD\n\tHostName $LOC_IP\n\tUser $USER\n\tPort $LOC_PORT\n\tIdentityFile $KEY_PATH\n"
    REPLACEMENT_HOST="Host $COMPUTER\n\tHostName $PUB_IP\n\tUser $USER\n\tPort $PUB_PORT\n\tIdentityFile $KEY_PATH\n"

    if $LOCAL; then
        printf "$REPLACEMENT_MATCH" >> $FILE
        echo "" >> $FILE
    fi

    printf "$REPLACEMENT_HOST" >> $FILE
    echo "" >> $FILE

}

ADD_COMPUTER() {

    INITIALIZE_SPACE

    GATHER_INFORMATION
    UPDATE_AUTHORIZED_KEYS

    UPDATE_CONFIG_FILE

}

# TODO should this clean key and authorized_keys file? Meh...
REMOVE_COMPUTER() {

    PROCEED="false"

    # it'd be cool to time this and only show the warning if this was completed
    # hastily
    QUERY="Enter the name of the computer you want to remove and press [ENTER]: "
    REQUEST "$QUERY" COMPUTER

    QUERY="Enter the username on $COMPUTER that you want to remove and press [ENTER]: "
    REQUEST "$QUERY" USER

    WARNING="This will remove all config entries pertaining to $COMPUTER and $USER. Proceed? [y/N] "
    YES_NO "$WARNING" PROCEED

    if $PROCEED; then
        REMOVE_CONFIG_PARAGRAPHS "$COMPUTER" "$USER"
    else
        exit 1
    fi
}

# Output help text
HELP() {
    printf "\nUsage:\n";
    printf "[]\t\tRun with no arguments to begin adding user.\n"
    printf "[-a]\t\tAdd a config entry, ssh-key, and append to authorized_keys.\n"
    printf "[-r]\t\tRemove a User\Computer combination from the config file.\n"
    printf "[-h]\t\tOutputs help text.\n\n";
}

## Flags
##
while getopts 'arh' flag; do
  case "${flag}" in
    a)
        ADD_COMPUTER
        exit 0
        ;;
    r)
        REMOVE_COMPUTER
        exit 0
        ;;
    h)
        HELP
        exit 0
        ;;
    \?)
        #printf "Invalid option: -${OPTARG}\n" >&1;
        HELP
        exit 1
        ;;
  esac
done

if [ $OPTIND -eq 1 ]; then
    ADD_COMPUTER
fi
