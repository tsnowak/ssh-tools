#!/bin/bash

# TODO:
#  -When rewriting/correcting an incorrectly written .ssh/config account, it will only delete
#       the external account, not the local/match case (or vice-versa) ie, only deletes
#        one paragraph

# USAGE:
# This script should edit the .ssh/config file by adding the information of a new computer to it# in a manner organized between lab and personal computers.
# It should be able to add a public ID file's contents to a remote authorized_hosts file.
# It should generate a unique ssh-key for a lab computer or use the the id_rsa.pub file for a
# personal computer.


# ARGUMENTS:
# INPUT:	Multiple prompts for informations depending on what is needed.
# RETURNS:	The gamut mentioned above.


# ASSUMPTIONS:
# None


# DEPENDENCIES:
# 'brew install gnu-sed --with-default-names'


# EXAMPLE USAGE CASE:
# ________________________________________
# ./add_computer.sh
# ________________________________________


COMPUTER=""
PUB_IP=""                   # IP address/hostname of remote machine
LOC_IP=""
USER=""                     # user name on remote machine
PUB_PORT="22"               # open ssh port for remote machine
LOC_PORT="22"               # open ssh port for remote machine
PW=""                       # desired ssh-key password
SSH_CODE=""
KEY_FILE=~/.ssh/id_rsa		# ssh-key file location
MATCH=false
UPDATE_MATCH=false
IDENTITY_EXISTS=false
USE_EXISTING_CONFIG=false

VERIFY_NETWORK_CMD=/usr/local/bin/verify_local_network

# Make necessary directories and files
MAKE_REQS() {
    mkdir -p ~/.ssh/keys
    touch ~/.ssh/authorized_keys
    touch ~/.ssh/config
    touch ~/.ssh/known_hosts
}

# yes/no question template, $1=Question, $2=variable to store answer
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

# outputs a paragraph from .ssh/config with $INPUT $COMPUTER as the start of the
# paragraph
GET_CONFIG_PAR() {
        echo "$(cat ~/.ssh/config | awk -v RS="" -v computer=$COMPUTER -v \
        input="$1" '$0 ~ input computer')"
}

# Ask for required input
INPUT() {

    # Prompt for computer name
    echo -n "Enter the computer alias you want to add and press [ENTER]: ";
    read COMPUTER;

    # Make a unique key for this computer
    QUERY="Would you like to make a unique key for this computer? [y/N] "
    YES_NO "$QUERY" UNIQUE_KEY

	# Whether we will need to make a new key
	if ([ ! -d ~/.ssh/keys/$COMPUTER ] && [ "$UNIQUE_KEY" = true ]); then
        mkdir -p ~/.ssh/keys/$COMPUTER
		MAKE_KEY=true
    elif ([ ! -f ~/.ssh/id_rsa ] && [ "$UNIQUE_KEY" = false ]); then
		MAKE_KEY=true
	else
        if [ "$UNIQUE_KEY" = true ]; then
            QUERY=".ssh/keys/$COMPUTER/$COMPUTER.pub already exists! Replace? [y/N] "
            YES_NO "$QUERY" MAKE_KEY
        else
            QUERY=".ssh/id_rsa.pub already exists! Replace? [y/N] "
            YES_NO "$QUERY" MAKE_KEY
        fi
    fi

    # Whether to setup Match case or not
    QUERY="Is this computer behind a local network? [y/N] "
    YES_NO "$QUERY" MATCH

    # Whether to ssh to local ip
    if $MATCH; then
        QUERY="Are you currently at home behind the local network? [y/N] "
        YES_NO "$QUERY" AT_LOCAL
    fi

    # Whether to use existing information in config file
    if grep -Fxq "Host $COMPUTER" ~/.ssh/config; then
        QUERY=".ssh/config entry detected for $COMPUTER. Keep this"
        QUERY="$QUERY information? [y/N] "
        YES_NO "$QUERY" USE_EXISTING_CONFIG
	fi

    # Whether to update Match case or not
	if "$MATCH" = false; then
		UPDATE_MATCH=false
    elif [ $(grep -Fxq "Match originalhost $COMPUTER exec $VERIFY_NETWORK_CMD" \
    ~/.ssh/config) ] && [ "$LOCAL" = true ]; then
        UPDATE_MATCH=false
	else
		UPDATE_MATCH=true
	fi

	## Use the config file information, but still check for errors w.r.t. IdentityFile and
	## Match information
	##
    # TODO: I don't think this supports config exists + local with no ssh_key,
    # because ssh_code doesn't get updated appropriately
	if $USE_EXISTING_CONFIG; then

        # DEM AWK CHAINS DOH!
        # Key Insights: RS = record separator variable, set it to a blank line!
        INPUT="Host "
        HOST_CONFIG_PAR="$(GET_CONFIG_PAR "$INPUT")"
		# Get the paragraph after "Match original host $COMPUTER"
        INPUT="Match originalhost "
        MATCH_CONFIG_PAR="$(GET_CONFIG_PAR "$INPUT")"

        # Get local ip info if we needed to update match
		if [ "$UPDATE_MATCH" = true ]; then
        	echo -n "Enter the Static Local IP address of the computer to add"\
            "and press [ENTER]: ";
        	read LOC_IP;

        	echo -n "Enter the open ssh Port of the computer to add and "\
            "press [ENTER] (Default: 22): ";
        	read LOC_PORT;
        # otherwise find it in file
		else
			LOC_IP=$(echo "$MATCH_CONFIG_PAR" | awk '/HostName/{print $2}')
			LOC_PORT=$(echo "$MATCH_CONFIG_PAR" | awk '/Port/{print $2}')
		fi

        # Output paragraph after Host $COMPUTER and then parse that for 2nd
        # word after HostName, etc.
        USER=$(echo "$PUB_AWK_CAT" | awk '/User/{print $2}')
        if [ -z "$USER"]; then
        	echo -n "User field empty in .ssh/config[ENTER]: ";
        	read PUB_IP;
        fi
        PUB_IP=$(echo "$PUB_AWK_CAT" | awk '/HostName/{print $2}')
        if [ -z "$PUB_IP"]; then
        	echo -n "Public IP field empty in .ssh/config[ENTER]: ";
        	read PUB_IP;
        fi
        PUB_PORT=$(echo "$PUB_AWK_CAT" | awk '/Port/{print $2}')
        if [ -z "$PUB_PORT"]; then
        	echo -n "Public Port field empty in .ssh/config[ENTER]: ";
        	read PUB_IP;
        fi

        if [ "$(echo "$PUB_AWK_CAT" | grep -Fo "IdentityFile")" == \
        "IdentityFile" ]; then
            IDENTITY_EXISTS=true
            SSH_CODE="-i $KEY_FILE "
        else
            IDENTITY_EXISTS=false
        fi


		if $LOCAL; then
			SSH_CODE="$SSH_CODE-p $LOC_PORT $USER@$LOC_IP"
		else
			SSH_CODE="$SSH_CODE-p $PUB_PORT $USER@$PUB_IP"
		fi

    # otherwise manually input info
    else

		# User doesn't change for location
        echo -n "Enter the User of the computer to add and press [ENTER]: ";
        read USER;

		# Prompt for all information if computer is behind local network
		if $MATCH; then
			echo -n "Enter the Public IP address of the router to which the"\
            "computer is connected [ENTER]: ";
        	read PUB_IP;

			echo -n "Enter the External Port which forwards to the computer"\
            "[ENTER] (Default: 22): ";
        	read PUB_PORT;

        	echo -n "Enter the Static Local IP address of the computer to add"\
            "and press [ENTER]: ";
        	read LOC_IP;

        	echo -n "Enter the open ssh Port of the computer to add and press"\
            "[ENTER] (Default: 22): ";
        	read LOC_PORT;

			if $LOCAL; then
				SSH_CODE="-p $LOC_PORT $USER@$LOC_IP"
			else
				SSH_CODE="-p $PUB_PORT $USER@$PUB_IP"
			fi
		# Otherwise just prompt for public information
		else
        	echo -n "Enter the IP address of the computer to add"\
            "and press [ENTER]: ";
        	read PUB_IP;

        	echo -n "Enter the Port of the computer to add and press [ENTER]"\
            "(Default: 22): ";
        	read PUB_PORT;

        	SSH_CODE="-p $PUB_PORT $USER@$PUB_IP"
		fi

    fi

    echo ""

}

# generates the unique or general ssh_key
GENERATE_KEY() {
    if $MAKE_KEY; then
        echo -n "Enter the desired password for the ssh-key [ENTER] (Default: ''): ";
        read PW;
        if $UNIQUE_KEY; then
            ssh-keygen -t rsa -N "$PW" -C "$USER" -f ~/.ssh/keys/$COMPUTER/$COMPUTER
        else
            ssh-keygen -t rsa -N "$PW" -C "$USER" -f ~/.ssh/id_rsa
        fi
    fi
}

# updates remote authorized_keys accordingly
UPDATE_AUTHORIZED_KEYS() {

    if $UNIQUE_KEY; then
        KEY_FILE=~/.ssh/keys/$COMPUTER/$COMPUTER.pub
    else
        KEY_FILE=~/.ssh/id_rsa.pub
    fi

    # TODO: combine steps so that only 1 ssh is required
    # just storing in variables for ease of debugging
    KEY_FILE_CONTENT=$(cat $KEY_FILE)
    SSH_AUTH_CONTENT=$(ssh $SSH_CODE "grep -F '$KEY_FILE_CONTENT' \
    ~/.ssh/authorized_keys; mkdir -p ~/.ssh")

    # check if the authorized_keys file has the pub id already
    if [ "$SSH_AUTH_CONTENT" == "$KEY_FILE_CONTENT" ]
    then
        echo "Public key exists in $COMPUTER:~/.ssh/authorized_keys. Not"\
        "replicating."
    else
        # pipes the cat output of the $KEY_FILE into the authorized_keys
        # file over ssh
        `cat $KEY_FILE | ssh $SSH_CODE "cat >> ~/.ssh/authorized_keys"`;
    fi
}

# Add a new entry to the .ssh/config file for a remote machine
HANDLE_CONFIG() {

	# check if sed else /usr/local/bin/sed (MacOSX)
	OS_KERNEL=$(uname -a | grep -Fo "GNU")
	if [ "$OS_KERNEL" == "GNU" ]; then
		SED=sed
	else
		SED=/usr/local/bin/sed
	fi

    # .ssh/config marker for lab (#>>>) vs. personal (#<<<) computers
    # ORGANIZATION BITCHES!
    if [ "$UNIQUE_KEY" = true ]
    then
        MARKER="#>>>";
    else
        MARKER="#<<<";
    fi

    # add Match case and Host $COMPUTER paragraphs
    if $UPDATE_MATCH; then

    # only add Host $COMPUTER paragraph
    else

    fi

	# Plausible Cases:
	# (config exists, but not match) 	CMN=true, CE=true
	# (both exist) 						CMN=false, CE=true
	# (neither exist) 					CMN=true, CE=false
    if $USE_EXISTING_CONFIG; then
        echo "Config entry for $COMPUTER exists. Not replicating."
        $SED -i.bkp "/^Host $COMPUTER/,/^$/{/^Host/!{/^$/!d}}" ~/.ssh/config;
        $SED -i.bkp "/^Host $COMPUTER/a\ \tHostName $PUB_IP\n\tUser $USER\n\tPort $PUB_PORT\n\tIdentityFile $KEY_FILE" ~/.ssh/config;
    else
        ## Creates a backup of the old config file and adds the new machine to the config file          ##
        $SED -i.bkp "/$MARKER/i Host $COMPUTER\n\tHostName $PUB_IP\n\tUser $USER\n\tPort $PUB_PORT\n\tIdentityFile $KEY_FILE\n\n" ~/.ssh/config;
    fi

	# If needed, this should put the Match statement in the line above normal config file
	# information for the computer
	if $UPDATE_MATCH; then
		echo "Adding Match Case for $COMPUTER."
        $SED -i.bkp "/Host $COMPUTER/i Match originalhost $COMPUTER exec $VERIFY_NETWORK_CMD\n\tHostName $LOC_IP\n\tUser $USER\n\tPort $LOC_PORT\n\tIdentityFile $KEY_FILE\n" ~/.ssh/config;
	else
        echo "Match case not updated."
    fi

	## Overwrites config file information with correct information
    ##
    if ! $IDENTITY_EXISTS; then
		# beginning of line Host $COMPUTER to beginning of line empty line
		# Don't delete the Host line, but delete everything after until empty line
        $SED -i.bkp "/^Host $COMPUTER/,/^$/{/^Host/!{/^$/!d}}" ~/.ssh/config;
        $SED -i.bkp "/^Host $COMPUTER/a\ \tHostName $PUB_IP\n\tUser $USER\n\tPort $PUB_PORT\n\tIdentityFile $KEY_FILE" ~/.ssh/config;
    else
        echo "IdentityFile not updated."
	fi

}

MANAGE_SSH() {
    MAKE_REQS
    INPUT
    GENERATE_KEY
    UPDATE_AUTHORIZED_KEYS
    HANDLE_CONFIG
}

# Output help text
HELP() {
    printf "\nUsage:\n";
    printf "[]\t\tApplication run with no arguments -- follow on-screen prompts.\n"
    #printf "[-a]\t\tUse to add <REMOTE> to <LOCAL>:~/.ssh/config, create a new, unique ssh-key in\n\t\t<LOCAL>:~/.ssh/keys/<REMOTE>/., and add <LOCAL> to <REMOTE>~/.ssh/authorized_keys.\n";
    #printf "[-c]\t\tUse to add <REMOTE> to <LOCAL>:~/.ssh/config.\n";
    #printf "[-k]\t\tUse to create a new, unique ssh-key in <LOCAL>:~/.ssh/keys/<REMOTE>/.\n";
    #printf "[-u]\t\tUse to add <LOCAL> to <REMOTE>~/.ssh/authorized_keys.\n\n";
    printf "[-h]\t\tOutputs help text.\n\n";
    exit 1
}

## Flags
##
while getopts 'h' flag; do
  case "${flag}" in
    h)
        HELP
        exit 1
        ;;
    \?)
        #printf "Invalid option: -${OPTARG}\n" >&1;
        HELP
        exit 1
        ;;
  esac
done

if [ $OPTIND -eq 1 ]; then
    MANAGE_SSH
fi
