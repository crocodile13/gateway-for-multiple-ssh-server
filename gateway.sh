#!/bin/bash

trap '' SIGINT SIGTERM SIGINT SIGTERM SIGSTOP SIGBUS SIGSEGV SIGABRT SIGQUIT

#=============================
logRep="/var/log/sshLogger"
serversFile="servers.conf"
accessFile="access.conf"
#=============================

cd $(dirname $0)

if [ ! -d "$logRep" ]; then
        umask 067 && mkdir -p $logRep && chown root:gateway $logRep
fi

matchAccess()
{
        local nombre="$1"
        for num in "${accessListUser[@]}"; do
                if [ "$num" == "$nombre" ]; then
                        return 1
                fi
        done
        return 0
}


#si user local, pas le menu.
if [ -n "$(printenv | grep SSH)" ]; then
        clientIp="$(echo "$SSH_CLIENT" | awk '{print $1}')"
        logFile="$clientIp-$(date +"%Y-%m-%d")"

        # Bon c'est long et chiant, en gros ca recup dans les logs de ssh l'id de la connexion a partir de l'ip port du client. Il en deduit le numero de ligne de la public key
        logMarge=20
        idSshConection=$(tail -n $logMarge /var/log/messages | grep Accepted | grep $(echo $SSH_CLIENT | cut -d " " -f 1) | grep $(echo $SSH_CLIENT | cut -d " " -f 2) | awk -F'[][]' '{print $2}' | awk '{print $NF}')
        pubKeyLine=$(tail -n $logMarge /var/log/messages | grep authorized_keys | grep $idSshConection | awk '{print $NF}' | sed -n 's/.*keys://p;q')
        userTag="$(sed -n "${pubKeyLine}p" ~/.ssh/authorized_keys | awk '{print $NF}')"
        clear
else
        logFile="local-$(date +"%Y-%m-%d")"
        echo -e "\nVous tentez d'executer le script gateway.sh directement depuis la console administrateur.\nCe script est concu pour les connexions ssh.\n"
        read -p "Voulez vous l'executer quand meme? (y/n): " continue
        if [[ ${continue} =~ [^[:alnum:]] ]]; then
                echo -e "Your answer contains non-alphanumeric characters. Please retry.\nExiting"
                exit
        elif [ "$continue" == "y" ];then
                echo -e "Ok, continue with local console.\nAll servers will be display."
                userTag="admin"
        else
                echo "Exiting"
                exit
        fi
fi

echo -e "\n\n\tHello $userTag !\n\n\tPlease, wait 2s."
sleep 2

if [ ! -f "$logRep/$logFile" ]; then
        umask 577 && touch $logRep/$logFile 
fi

accessListUser=()
if [ ! -f "$accessFile" ]; then
        echo "Le fichier de configuration '$accessFile' n'existe pas."
fi
while IFS= read -r line; do
        if [ -z "$line" ]; then
                continue
        fi
        if [[ "$line" == \#* ]]; then
                continue
        fi
        IFS=":" read -ra fields <<< "$line"
        if [ "${fields[0]}" == "$userTag" ]; then
                IFS="," read -ra numbers <<< "${fields[1]}"
                accessListUser=("${numbers[@]}")
                break
        fi
done < "$accessFile"
echo "Resultat : ${accessListUser[*]}"


#Recuperer les lignes du fichier servers.conf specifiees dans access.conf. A noter que il ne filtre pas les serveurs qui repondent ou pas.
#Tout est affiche si le userTag est "admin" (c'est a dire que il est specifie dans authorized_keys ou alors que l'acces se fait manualement via la console locale apres avoir saisi "a")
servers=()
if [ ! -f "$serversFile" ]; then
        echo "Le fichier de configuration '$serversFile' n'existe pas."
fi
# Lire le fichier ligne par ligne, en ignorant les lignes vides et les commentaires
count=0
while IFS= read -r line; do
        if [ -z "$line" ]; then
                continue
        fi
        if [[ "$line" == \#* ]]; then
                continue
        fi
        ((count++))
        matchAccess "$count"
        match=$?
        if [[ $match -eq 1 || $userTag == "admin" ]];then
                servers+=("$line")
                echo "TAMERE"
        fi

done < "$serversFile"

sshTr()
{
        #read -p "Username: " username
        commande="ssh -t -p $2 $3@$1"
        #commande="ssh -t -p $2 $3@$1 'su - $username'"
        script -afq -c "$commande" "$logRep/$logFile"
        sleep 2
}


banner()
{
    clear
    echo -e "\n============================================================"
    echo -e "                                                            "
    echo -e "  SSH gateway:                                              "
    echo -e "                                                            "
    for ((i = 0; i < ${#servers[@]}; i++)); do
        echo "  $((i + 1)) - $(echo ${servers[i]} | cut -d ":" -f 4) : $(echo ${servers[i]} | cut -d ":" -f 5)"
    done
    echo -e "                                                            "
    echo -e "============================================================"
    echo -e "                                                            "
    echo -e "  a - local admin                                           "
    echo -e "                                                            "
    echo -e "============================================================\n"
}




# Choix utilisateur et connexion au seveur demande
while true; do
        banner
        echo ""
        read -p "Make your choice: " option
        if [[ ${option} =~ ^[0-9]+$ ]] || [ "$chaine" = "a" ]; then
                echo "Your choice contains non-alphanumeric characters. Please retry."
        else
                echo ""
                if [[ "${option}" -ge 1 && "${option}" -le ${#servers[@]} ]]; then
                        read -p "Username: " username
                        if [[ ${username} =~ [^[:alnum:]] ]]; then
                                echo "Your username contains non-alphanumeric characters. Please retry"
                        else
                                sshTr $(echo ${servers[option-1]} | cut -d ":" -f 1) $(echo ${servers[option-1]} | cut -d ":" -f 2) "${username}"
                        fi
                elif [ "${option}" == "a" ]; then
                        script -afq -c "su - gateway" $logRep/$logFile
                        sleep 2

                else
                        echo "Unknow option ${option}. Try again."
                fi
        fi
        sleep 2
done
