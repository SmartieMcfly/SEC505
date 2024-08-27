Windows IPsec and Linux IPsec can interoperate.  This folder contains 
sample configuration files for the strongSwan IPsec solution on Linux.

Read more about Linux strongSwan at https://www.strongswan.org.

The following instructions are for Debian Linux specifically, but the
commands for other Debian-based distros (Mint, Ubuntu, Pop_OS) will
be very similar.


## Install sudo, if not already installed:
su -
apt update 
apt install sudo


## Add your user account to the sudo group, if necessary, using vi
## or nano or some other text editor, then log out and log back in:
vi /etc/group
logout


## Install strongSwan:
sudo apt install -y strongswan strongswan-swanctl


## Assign a static IP address compatible with your
## Windows virtual machines for this course:

Copy the static.network file found in the current folder to 
/etc/systemd/network/, or, alternatively, create a file named
"static.network" in that folder and add the following lines,
making sure that all lines are left-aligned in the same column:

	[Match]
	Name=en*
	
	[Network]
	Address=10.1.1.3/24

Then run:
sudo systemctl restart systemd-networkd.service


## Remove any existing strongSwan conf files:
sudo rm -v /etc/swanctl/conf.d/*.conf


## Copy in your own custom conf file:
sudo cp windefault.conf /etc/swanctl/conf.d 


## Restart the strongSwan service:
sudo systemctl restart strongswan-starter.service


## In a script, sleep for one second (otherwise, you'll get errors):
sleep 1 


## Reload the strongSwan config file:
sudo swanctl --load-all 


## Ping the Windows machine and confirm success:
ping -c 3 10.1.1.1
sudo swanctl --list-sas 


## If it doesn't work, see the notes in the windefault.conf file.


