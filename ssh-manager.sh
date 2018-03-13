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

    # dereference variable
    y=\$"$4"
    #echo $y
    x=`eval "expr \"$y\" "`
    #echo $2=$x
    eval "$4=\"$(cat ~/.ssh/config | awk -v RS="" -v expr="$1$2" \
    -v user="User $3" '{ if ($0 ~ expr && $0 ~ user) print$0 }')\""
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

    # Take out in final
    HOST="Host "
    GET_CONFIG_PARAGRAPH "$HOST" "$COMPUTER" "$USER" HOST_PARAGRAPH
    MATCH="Match originalhost "
    GET_CONFIG_PARAGRAPH "$MATCH" "$COMPUTER" "$USER" MATCH_PARAGRAPH

    REPLACEMENT_MATCH="Match originalhost $COMPUTER exec $VERIFY_NETWORK_CMD\n\tHostName $LOC_IP\n\tUser $USER\n\tPort $LOC_PORT\n\tIdentityFile $KEY_FILE\n"
    REPLACEMENT_HOST="Host $COMPUTER\n\tHostName $PUB_IP\n\tUser $USER\n\tPort $PUB_PORT\n\tIdentityFile $KEY_FILE\n"

    if [ ! -z "$HOST_PARAGRAPH" ]; then
        # remove paragraph
        grep -vwx "$HOST_PARAGRAPH" config
    fi
    # add to end
    #printf "$REPLACEMENT_HOST" >> config

    if [ ! -z "$MATCH_PARAGRAPH" ]; then
        # remove paragraph
        #sed -i.bkp "/$MATCH_PARAGRAPH/d" config
        echo "fuck"
    fi
    # add above Host $COMPUTER paragraph
    #sed -i.bkp "/$REPLACEMENT_HOST/i $REPLACEMENT_MATCH" config
}

COMPUTER="revival"
USER="tsnowak"
PUB_IP="68.40.191.226"
PUB_PORT="4864"
LOC_IP="192.168.0.102"
LOC_PORT="2222"
#GATHER_INFORMATION
#UPDATE_AUTHORIZED_KEYS
UPDATE_CONFIG_FILE
echo "$COMPUTER $USER $PUB_IP $PUB_PORT $LOC_IP $LOC_PORT"
