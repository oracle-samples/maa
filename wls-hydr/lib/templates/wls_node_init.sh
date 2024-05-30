#!/bin/bash

LOG_FILE='/var/log/wls_init.log'
FAILURE='false'

OINSTALL_GID="%%OINSTALL_GID%%"
ORACLE_UID="%%ORACLE_UID%%"
CONFIG_FS="%%CONFIG_FS%%"
RUNTIME_FS="%%RUNTIME_FS%%"
PRODUCTS_FS="%%PRODUCTS_FS%%"
CONFIG_MOUNT="%%CONFIG_MOUNT%%"
RUNTIME_MOUNT="%%RUNTIME_MOUNT%%"
PRODUCTS_MOUNT="%%PRODUCTS_MOUNT%%"
PORTS=%%PORTS%%
SSH_PUB_KEY="%%SSH_PUB_KEY%%"
LBR_IP="%%LBR_IP%%"
LBR_VIRT_HOSTNAME="%%LBR_VIRT_HOSTNAME%%"
LBR_ADMIN_HOSTNAME="%%LBR_ADMIN_HOSTNAME%%"

function log(){
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    level=$1
    message=$2
    echo "$timestamp" ["${level^^}"] "$message" | tee -a "$LOG_FILE"
}

function change_gid() {
    new_gid=$1
    used_by=$2
    old_gid=$(grep ^"$used_by": /etc/group | cut -d ":" -f 3)
    log "info" "Running groupmod -g $new_gid $used_by"
    
    if ! groupmod -g "$new_gid" "$used_by" >> "$LOG_FILE" 2>&1; then 
        log "error" "Could not change GID for group $used_by"
        return 1
    fi
    log "info" "Changing ownership of all files owned by group $used_by to new GID $new_gid"
    log "info" "Running find / -path /sys -prune -o -path /proc -prune -o -group $old_gid -exec chgrp -h $used_by {} \;"
    
    # the following convoluted and (apparently) superflous line of code is used to mitigate false
    # failures caused by some temporary files found by find that are deleted before find stats them
    # GitLab issue #12
    if ! find / -path /sys -prune -o -path /proc -prune -o -group "$old_gid" -print0 |  xargs -0 -i bash -c "if test -e {}; then chgrp -h $used_by {}; fi" >> "$LOG_FILE" 2>&1; then
        log "error" "Could not change ownership of all files owned by group $used_by to new GID $new_gid"
        return 1
    fi
    return 0
}

function shift_gid() {
    gid=$1
    used_by=$(grep "$gid" /etc/group | cut -d ":" -f 1)
    new_gid=$gid
    available=0
    while [[ $available -eq 0 ]]; do 
        new_gid=$((new_gid+1));
        if ! grep -q $new_gid /etc/group; then 
            log "info" "GID $new_gid is available - changing GID for group $used_by" 
            available=1 
        fi 
    done
    change_gid "$new_gid" "$used_by"
}

function change_group_id() {
    group_name=$1
    group_gid=$2
    log "info" "Checking if GID $group_gid is used by a different group"
    if grep -q "$group_gid" /etc/group; then
        used_by=$(grep "$group_gid" /etc/group | cut -d ":" -f 1)
        log "warn" "GID $group_gid is already used by $used_by - shifting GIDs"
        if ! shift_gid "$group_gid"; then 
            log "error" "Could not shift GID of group $used_by"
            log "error" "Failed changing $group_name GID to $group_gid"
            return 1
        else
            log "info" "Successfully shifted $used_by GID"
            log "info" "Changing $group_name GID to $group_gid"
        fi
    else
        log "info" "GID $group_gid is available - changing $group_name GID to $group_gid"
    fi
    if ! change_gid "$group_gid" "$group_name"; then
        log "error" "Failure encountered when trying to change $group_name GID to $group_gid"
        return 1
    fi 
    return 0
}

function create_group() {
    group_name=$1
    group_gid=$2
    log "info" "Checking if GID $group_gid is used by a different group"
    if grep -q "$group_gid" /etc/group; then
        used_by=$(grep "$group_gid" /etc/group | cut -d ":" -f 1)
        log "warn" "GID $group_gid is already used by $used_by - shifting GIDs"
        if ! shift_gid "$group_gid"; then 
            log "error" "Could not shift GID of group $used_by"
            log "error" "Failed creating group $group_name with GID $group_gid"
            return 1
        else
            log "info" "Successfully shifted $used_by GID"
        fi
    else 
        log "info" "GID $group_gid not used by another group"
    fi 
    log "info" "Creating $group_name with GID $group_gid"
    log "info" "Running groupadd $group_name -g $group_gid"
    if ! groupadd "$group_name" -g "$group_gid" >> "$LOG_FILE" 2>&1; then
        log "error" "Could not create group $group_name with GID $group_gid"
        return 1
    fi
    log "info" "Created group $group_name with GID $group_gid"
    return 0
}

function change_uid() {
    new_uid=$1
    used_by=$2
    old_uid=$(grep ^"$used_by": /etc/passwd | cut -d ":" -f 3)
    log "info" "Running usermod -u $new_uid $used_by"
    
    if ! usermod -u "$new_uid" "$used_by" >> "$LOG_FILE" 2>&1; then 
        log "error" "Could not change UID for user $used_by"
        return 1
    fi
    log "info" "Changing ownership of all files owned by user $used_by to new UID $new_uid"
    log "info" "Running find / -path /sys -prune -o -path /proc -prune -o -user $old_uid -exec chown -h $used_by {} \;"
    # the following convoluted and (apparently) superflous line of code is used to mitigate false
    # failures caused by some temporary files found by find that are deleted before find stats them
    # GitLab issue #12
    if ! find / -path /sys -prune -o -path /proc -prune -o -user "$old_uid" -print0 | xargs -0 -i bash -c "if test -e {}; then chown -h $used_by {}; fi" >> "$LOG_FILE" 2>&1; then
        log "error" "Could not change ownership of all files owned by user $used_by to new UID $new_uid"
        return 1
    fi
    return 0
}

function shift_uid() {
    uid=$1
    used_by=$(id -u "$user_id" -n)
    new_uid=$uid
    available=0
    while [[ $available -eq 0 ]]; do 
        new_uid=$((new_uid+1));
        if ! id -u "$new_uid" -n > /dev/null 2>&1; then 
            log "info" "UID $new_uid is available - changing UID for user $used_by" 
            available=1 
        fi 
    done
    change_uid "$new_uid" "$used_by"
}

function change_user_id() {
    user_name=$1
    user_id=$2
    log "info" "Checking if UID $user_id is used by another user" 
    if id "$user_id" > /dev/null 2>&1; then
        used_by=$(id -u "$user_id" -n)
        log "warn" "UID $user_id used by user $used_by - shifting UIDs"
        if ! shift_uid "$user_id"; then 
            log "error" "Failures encountered when trying to shift UID"
            return 1
        else 
            log "info" "Successfully shifted user $used_by UID"
            log "info" "Changing $user_name UID to $user_id"
        fi
    else 
        log "info" "UID $user_id not used by any other user"
    fi 
    log "info" "Changing user $user_name UID to $user_id"
    if ! change_uid "$user_id" "$user_name"; then 
        log "error" "Encountered failures when trying to change user $user_name UID to $user_id"
        return 1
    fi 
    log "info" "Successfully changed user $user_name UID to $user_id"
    return 0
}

function create_user() {
    user_name=$1
    user_id=$2
    log "info" "Checking if UID $user_id is used by a another user"
    if id "$user_id" > /dev/null 2>&1; then
        used_by=$(id -u "$user_id" -n)
        log "warn" "UID $user_id is already used by $used_by - shifting UIDs"
        if ! shift_uid "$user_id"; then 
            log "error" "Could not shift UID of user $used_by"
            return 1
        else
            log "info" "Successfully shifted $used_by UID"
        fi
    else 
        log "info" "GID $user_id not used by another user"
    fi 
    log "info" "Creating $user_name with UID $user_id"
    log "info" "Running useradd -u $user_id $user_name"
    if ! useradd -u "$user_id" "$user_name" >> "$LOG_FILE" 2>&1; then
        log "error" "Could not create user $user_name with UID $user_id"
        return 1
    fi
    log "info" "Created user $user_name with UID $user_id"
    return 0
}

function myexit() {
    if [[ $FAILURE == 'true' ]]; then
        echo "RECAP: init config FAIL" | tee -a "$LOG_FILE"
        exit 1
    else
        echo "RECAP: init config SUCCESS" | tee -a "$LOG_FILE"
        exit 0
    fi 
}

if [[ -z "$OINSTALL_GID" ]] || [[ "$OINSTALL_GID" =~ "%%" ]]; then
    log "error" "OINSTALL_GID has invalid value: [$OINSTALL_GID]"
    FAILURE='true'
    myexit
fi

if [[ -z "$ORACLE_UID" ]] || [[ "$ORACLE_UID" =~ "%%" ]]; then
    log "error" "ORACLE_UID has invalid value: [$ORACLE_UID]"
    FAILURE='true'
    myexit
fi

if [[ -z "$CONFIG_FS" ]] || [[ "$CONFIG_FS" =~ "%%" ]]; then
    log "error" "CONFIG_FS has invalid value: [$CONFIG_FS]"
    FAILURE='true'
    myexit
fi

if [[ -z "$RUNTIME_FS" ]] || [[ "$RUNTIME_FS" =~ "%%" ]]; then
    log "error" "RUNTIME_FS has invalid value: [$RUNTIME_FS]"
    FAILURE='true'
    myexit
fi

if [[ -z "$PRODUCTS_FS" ]] || [[ "$PRODUCTS_FS" =~ "%%" ]]; then
    log "error" "PRODUCTS_FS has invalid value: [$PRODUCTS_FS]"
    FAILURE='true'
    myexit
fi

if [[ -z "$CONFIG_MOUNT" ]] || [[ "$CONFIG_MOUNT" =~ "%%" ]]; then
    log "error" "CONFIG_MOUNT has invalid value: [$CONFIG_MOUNT]"
    FAILURE='true'
    myexit
fi

if [[ -z "$RUNTIME_MOUNT" ]] || [[ "$RUNTIME_MOUNT" =~ "%%" ]]; then
    log "error" "RUNTIME_MOUNT has invalid value: [$RUNTIME_MOUNT]"
    FAILURE='true'
    myexit
fi

if [[ -z "$PRODUCTS_MOUNT" ]] || [[ "$PRODUCTS_MOUNT" =~ "%%" ]]; then
    log "error" "PRODUCTS_MOUNT has invalid value: [$PRODUCTS_MOUNT]"
    FAILURE='true'
    myexit
fi

if [[ -z "$PORTS" ]] || [[ "$PORTS" =~ "%%" ]]; then
    log "error" "PORTS has invalid value: [$PORTS]"
    FAILURE='true'
    myexit
fi

if [[ -z "$SSH_PUB_KEY" ]] || [[ "$SSH_PUB_KEY" =~ "%%" ]]; then
    log "error" "SSH_PUB_KEY not populated"
    FAILURE='true'
    myexit
fi

if [[ -z "$LBR_IP" ]] || [[ "$LBR_IP" =~ "%%" ]]; then
    log "error" "LBR_IP not populated"
    FAILURE='true'
    myexit
fi

if [[ -z "$LBR_VIRT_HOSTNAME" ]] || [[ "$LBR_VIRT_HOSTNAME" =~ "%%" ]]; then
    log "error" "LBR_VIRT_HOSTNAME not populated"
    FAILURE='true'
    myexit
fi

if [[ -z "$LBR_ADMIN_HOSTNAME" ]] || [[ "$LBR_ADMIN_HOSTNAME" =~ "%%" ]]; then
    log "error" "LBR_ADMIN_HOSTNAME not populated"
    FAILURE='true'
    myexit
fi

log "info" "Verifying oinstall group exists and has proper GID"
if grep -q oinstall /etc/group; then
    log "info" "oinstall group exists - checking GID"
    if grep oinstall /etc/group | grep -q "$OINSTALL_GID"; then
        log "info" "oinstall has proper GID"
    else
        log "info" "oinstall exists, but has different GID than on-prem - changing GID"
        if ! change_group_id "oinstall" "$OINSTALL_GID"; then
            FAILURE='true'
        fi
    fi
else 
    log "info" "oinstall does not exist - creating with GID $OINSTALL_GID"
    if ! create_group  "oinstall" "$OINSTALL_GID"; then
        FAILURE='true'
    fi
fi

oracle_valid="true"
log "info" "Verifying oracle user exists and has proper UID"
if grep -q ^oracle: /etc/passwd; then
    log "info" "oracle user exists - checking UID"
    oracle_uid=$(grep ^oracle: /etc/passwd | cut -d ":" -f 3)
    if [[ "$oracle_uid" == "$ORACLE_UID" ]]; then 
        log "info" "oracle user has proper UID ($ORACLE_UID)"
    else 
        log "warn" "oracle user has different UID - changing" 
        if ! change_user_id "oracle" "$ORACLE_UID"; then 
            FAILURE='true'
            oracle_valid="false"
        fi
    fi 
else 
    log "info" "User oracle does not exist - creating with UID $ORACLE_UID"
    if ! create_user "oracle" "$ORACLE_UID"; then 
        FAILURE='true'
        oracle_valid="false"
    fi
fi 

if [[ "$oracle_valid" == "true" ]]; then
    log "info" "Making sure user oracle has the proper groups associated"
    log "info" "Running usermod oracle -g oinstall oracle" 
    if ! usermod -g oinstall oracle >> "$LOG_FILE" 2>&1; then
        FAILURE='true'
        log "error" "Failed to associate proper groups to oracle user"
    else
        log "info" "Proper groups associated to user oracle"
    fi
fi

log "info" "Creating /home/oracle/.ssh directory"
if ! mkdir -p /home/oracle/.ssh >> "$LOG_FILE" 2>&1; then
    log "error" "Failed creating /home/oracle/.ssh directory"
    FAILURE='true'
else
    log "info" "Adding ssh public key to 'oracle' authorized hosts"
    echo "$SSH_PUB_KEY" >> /home/oracle/.ssh/authorized_keys
fi 

log "info" "Setting .ssh directory and contents correct permissions"
chown -R oracle:oinstall /home/oracle/.ssh >> "$LOG_FILE" 2>&1
chmod 700 /home/oracle/.ssh >> "$LOG_FILE" 2>&1
chmod 600 /home/oracle/.ssh/authorized_keys >> "$LOG_FILE" 2>&1


log "info" "Checking if nfs-utils is installed"
log "info" "Running rpm -qa | grep -q nfs-utils"
if ! rpm -qa | grep -q nfs-utils; then 
    log "error" "nfs-utils is not installed - will not mount OCI file systems"
    FAILURE='true'
else 
    log "info" "nfs-utils installed - mounting OCI file systems"

fi

log "info" "Mounting OCI filesystems"
echo "### OCI filesystems" >> /etc/fstab

log "info" "Creating products mountpoint"
if ! mkdir -p "$PRODUCTS_MOUNT" >> "$LOG_FILE" 2>&1; then
    log "error" "Failure creating mount point $PRODUCTS_MOUNT"
    FAILURE='true'
else 
    log "info" "Updating /etc/fstab"
    echo -e "$PRODUCTS_FS\t$PRODUCTS_MOUNT nfs defaults,nofail,nosuid,resvport 0 0" >> /etc/fstab
    if ! grep -q "$PRODUCTS_MOUNT" /etc/fstab; then
        log "error" "Failure updating /etc/fstab"
        FAILURE='true'
    else 
        log "info" "Successfully updated /etc/fstab with products mount"   
    fi
fi
log "info" "Creating shared config mountpoint"
if ! mkdir -p "$CONFIG_MOUNT" >> "$LOG_FILE" 2>&1; then
    log "error" "Failure creating mount point $CONFIG_MOUNT"
    FAILURE='true'
else 
    log "info" "Updating /etc/fstab"
    echo -e "$CONFIG_FS\t$CONFIG_MOUNT nfs defaults,nofail,nosuid,resvport 0 0" >> /etc/fstab
    if ! grep -q "$CONFIG_MOUNT" /etc/fstab; then
        log "error" "Failure updating /etc/fstab"
        FAILURE='true'
    else 
        log "info" "Successfully updated /etc/fstab with shared config mount"
    fi
fi
log "info" "Creating shared runtime mountpoint"
if ! mkdir -p "$RUNTIME_MOUNT" >> "$LOG_FILE" 2>&1; then
    log "error" "Failure creating mount point $RUNTIME_MOUNT"
    FAILURE='true'
else 
    log "info" "Updating /etc/fstab"
    echo -e "$RUNTIME_FS\t$RUNTIME_MOUNT nfs defaults,nofail,nosuid,resvport 0 0" >> /etc/fstab
    if ! grep -q "$RUNTIME_MOUNT" /etc/fstab; then
        log "error" "Failure updating /etc/fstab"
        FAILURE='true'
    else 
        log "info" "Successfully updated /etc/fstab with shared runtime mount"
    fi
fi

log "info" "Running mount -a" 
if ! mount -a >> "$LOG_FILE" 2>&1; then 
    log "error" "Running mount -a failed"
    FAILURE='true'
fi 

log "info" "Checking that filesystems are mounted"
valid='true'
for fs in $CONFIG_FS $RUNTIME_FS $PRODUCTS_FS; do
    if ! df -h | grep -q "$fs"; then 
        log "error" "Filesystem $fs not mounted"
        valid='false'
        FAILURE='true'
    fi 
done 
if [[ $valid == 'true' ]]; then 
    log "info" "All filesystems successfully mounted"
fi 

log "info" "Setting mount points correct ownership (oracle:oinstall)" 
# using a kdludge below because of chown: changing ownership of ‘/u01/oracle/products/.snapshot’: Operation not permitted
for mount in "$CONFIG_MOUNT" "$RUNTIME_MOUNT" "$PRODUCTS_MOUNT"; do
    if chown -R "oracle:oinstall" "$mount" 2>&1 | grep -v snapshot >> "$LOG_FILE" 2>&1; then 
        log "error" "Failed setting correct ownership for mount point $mount"
        FAILURE='true'
    else 
        log "info" "$mount correct ownership set"
    fi
done

log "info" "Opening firewalld ports"
for port in "${PORTS[@]}"; do
    log "info" "Running firewall-offline-cmd --add-port=$port/tcp"
    if ! firewall-offline-cmd --add-port="$port"/tcp >> "$LOG_FILE" 2>&1; then 
        log "error" "Failure opening port $port" 
        FAILURE='true'
    fi 
done 

log "info" "Checking that ports have been opened"
valid='true'
for port in "${PORTS[@]}"; do 
    if ! firewall-offline-cmd --list-all | grep "^[[:space:]]*ports" | grep -q "$port"; then 
        log "error" "Port $port not open"
        FAILURE='true'
        valid='false'
    fi 
done 
if [[ $valid == 'true' ]]; then 
    log "info" "All ports opened successfully"
fi 

log "info" "Restarting firewalld"
if ! systemctl restart firewalld >> "$LOG_FILE" 2>&1; then
    log "error" "Failed restarting firewalld"
    FAILURE='true'
fi 

os_version=$(grep ^VERSION= /etc/os-release | cut -d'"' -f2 | cut -d"." -f1)
if [[ "$os_version" == "7" ]]; then
    log "info" "Installing compat-libstdc++-33"
    if ! yum install -y  compat-libstdc++-33 >> "$LOG_FILE" 2>&1; then 
        log "error" "Failed to install compat-libstdc++-33"
        FAILURE='true'
    fi
fi

log "info" "Adding LBR IP to /etc/hosts"
log "info" "Setting PRESERVE_HOSTINFO=3 in /etc/oci-hostnames.conf"
if ! sed -i "s/^PRESERVE_HOSTINFO=0/PRESERVE_HOSTINFO=3/" /etc/oci-hostname.conf >> "$LOG_FILE" 2>&1; then
    log "error" "Failed setting PRESERVE_HOSTINFO=3 in /etc/oci-hostnames.conf"
    FAILURE='true'
fi
log "info" "Adding LBR virtual hostname to /etc/hosts"
if ! grep -q "^$LBR_IP\s$LBR_VIRT_HOSTNAME" /etc/hosts; then
    printf '%s\t%s\n' "$LBR_IP" "$LBR_VIRT_HOSTNAME" >> /etc/hosts
    log "info" "Added LBR virtual hostname to /etc/hosts"
else
    log "info" "LBR virtual hostname already present in /etc/hosts"
fi
log "info" "Adding LBR admin hostname to /etc/hosts"
if ! grep -q "^$LBR_IP\s$LBR_ADMIN_HOSTNAME" /etc/hosts; then
    printf '%s\t%s\n' "$LBR_IP" "$LBR_ADMIN_HOSTNAME" >> /etc/hosts
    log "info" "Added LBR admin hostname to /etc/hosts"
else
    log "info" "LBR admin hostname already present in /etc/hosts"
fi
myexit