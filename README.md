# SSH-TOOLS
### A collection of scripts for automating (mostly) the management of ssh-keys

`verify_local_network` distinguishes whether you are sshing from within a local 
network to properly route the connection.

`ssh-manager.sh` helps add and remove `~/.ssh/config` entries and ssh-keys both 
locally and remotely. 

Together these two scripts make storing credentials for sshing to multiple 
computers a piece of cake.

Their usage is described below.

## verify_local_host

`ssh-manager.sh` expects the `verify_local_host` script to be in 
`usr/local/bin`.

```
sudo cp verify_local_host /usr/local/bin/.
```

This is used by the `ssh-manager.sh` script. It returns true when you are 
behind a local network, and false otherwise.

## ssh-manager.sh

You may want to copy `ssh-manager.sh` to a location where it can be easily 
called, but is not necessary.

### Usage

```
./ssh-manager.sh        # adds a computer
./ssh-manager.sh -a     # adds a computer
./ssh-manager.sh -r     # removes a computer
./ssh-manager.sh -h     # returns the help message
```

The script will prompt you with information needed to create the 
`~/.ssh/config` entry.
