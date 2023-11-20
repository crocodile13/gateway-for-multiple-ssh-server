# gateway-for-multiple-ssh-server
This Bash script is designed to simplify access to multiple SSH servers on the same LAN by exposing only one. It logs all keyboard input entered by users on the destination servers for intrusion monitoring purposes. It allows for managing lists of servers accessible by users (filtered by SSH public key). The script checks authentication with public keys, and upon successful authentication, redirects the user to another server requiring only a password.

1) Create a dedicated VM, which should be the only SSH server exposed on the WAN. Secure it through public key authentication.

2) Create the user 'gateway' on your machine with a password (necessary for local authentication on the gateway).

3) Copy the files into the user's home directory.

4) For security reasons, the permissions should be as follows:

    r-x rw- --- gateway root -> gateway.sh
    r-- rw- --- gateway root -> access.conf
    r-- rw- --- gateway root -> servers.conf

5) In /etc/ssh/sshd_config, add the following lines:

    SyslogFacility AUTH
    LogLevel VERBOSE

    AllowUsers gateway

    Match User gateway
    ForceCommand /home/gateway/gateway.sh.

    WARNING: The ssh log file must be readable by the 'gateway' user for the script to work. The configuration details for your .ssh/authorized_keys, server.conf, and access.conf are detailed in server.conf and access.conf.

    The logs for SSH users are in logRep="/var/log/sshLogger" by default; you can change this in the first lines of gateway.sh.
