#!/bin/bash 

#Autor: Didier Nino

#Variables Globales

RES=`tput smso`  			#-----> Texto Resaltado
NOR=`tput rmso`  			#-----> Texto Normal
							#-----> "tput civis" Ocultar cursor 
							#-----> " tput cnorm" Restaurar cursor 
 
gree="\e[0;32m\033[1m"		#-----> Texto con colores
endColour="\033[0m\e[0m"
red="\e[0;31m\033[1m"
blue="\e[0;34m\033[1m"
yellow="\e[0;33m\033[1m"
purple="\e[0;35m\033[1m"
turquoise="\e[0;36m\033[1m"
gray="\e[0;37m\033[1m"

	   
sin_conf_url="https://api.blockchair.com/bitcoin/mempool/transactions?limit="   #-----> Transacciones sin confirmar
ver_tran_url="https://api.blockchair.com/bitcoin/dashboards/transaction/"       #-----> Ver o inspeccionar transacciones
ver_address_url="https://api.blockchair.com/bitcoin/dashboards/address/"		#-----> Ver la direccion de donde se ha echo la transaccion

#-----> Trap se utiliza para ejecutar una accion 
trap ctrl_c INT

#-----> declare -l nos sirve para convertir el valor de una variable en minusculas
declare -l explore_mode


function ctrl_c(){

	echo -e " ${red} [+] Exit.. ${endColour}" 
	rm -rf *.table *.tmp* 2>/dev/null
	tput cnorm; exit 1


}

function help_panel(){

	echo -e "\n ${red} Uso: ./BTCAnalytics.sh ${endColour}"
	for i in {1..80}; do echo -en "${gray}-"; done; echo -en "${endColour}"
	echo -e "\n\n\t ${gray} [-e] ${endColour} : ${yellow} Modo exploracion.. ${endColour}\n"
	echo -e "\t\t ${gray} no_confirmada: ${endColour} ${yellow}\t Listar transaccion no confirmadas ${endColour}" 
	echo -e "\t\t ${gray} inspeccionar: ${endColour} ${yellow}\t Inspeccionar un hash de transaccion ${endColour}"
    echo -e "\n\t\t\t ${gray} [-i] ${endColour} : ${yellow}\t Inspeccionar transaccion ${endColour} Ejemplo: -i transaccion \n"
	echo -e "\t\t ${gray} direccion: ${endColour} ${yellow}\t\t Inspeccionar una direccion de transaccion ${endColour}"
    echo -e "\n\t\t\t ${gray} [-a] ${endColour} : ${yellow}\t Inspeccionar una billetera o direccion ${endColour} Ejemplo: -a address \n"
    echo -e "\n\t ${gray} [-n] ${endColour} : ${yellow} Limitar el numero de resultados ${endColour} Ejemplo: -n 10 "
	echo -e "\n\n\t ${gray} [-h] ${endColour} : ${yellow} Mostrar este menu de ayuda ${endColour}"
	tput cnorm; exit 1 


}

function printTable(){

    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        #El smmbolo <<< significa una redireccion de entrada.
		#Le permite pasar una cadena como entrada a un comando, en lugar de un archivo o un teclado.
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                #Este sed va a tomar la linea actual del lo que alla en data, y depues borra el resto, pero no borra nada 
                #del archivo original
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                #Cuenta cuantas columns tiene la variable
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                if [[ "${i}" -eq 1 ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/\+/{gsub(" ", "-", $0)}1' | sed 's/^--/  /g'

            fi
        fi
    fi
}


function removeEmptyLines(){

    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

function suma(){

    valors="${1}"
    number_of_decimals="${2}"
    veces=1
    for money in $valors; do
        if [ $veces -eq 1 ]; then 
            valor="${money}"
            let veces+=1
        else 
            valor=" + ${money}"
        fi

        suma+="${valor}" 
        
    done

    result="$(echo $suma | bc )"
    result_format="$( printf "%'.${number_of_decimals}f\n" ${result})"
    echo "${result_format}"

}

function repeatString(){

    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
		#con el comando printf y el formato ejemplo :' "%5s" ' va a guardar en la variable result 5 espacios en blanco
        local -r result="$(printf "%${numberToRepeat}s")"
		#echo va a imprimir el valor de "string" remplzando los espacios en blanco de result "// /" por lo que este en la variable string 
        echo -e "${result// /${string}}"
    fi
}

function isEmptyString(){

	#En esta funcion hay que recordar que el codigode exito en bash es "0" y codigo sin exito "1"
    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function trimString(){

    local -r string="${1}"
    #sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
	sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<< "${string}"
}

function transacciones_no_confirmadas(){

    number_output=$1
    contador_iteracion=17
    veces=1

	echo "" > sin_confirm.tmp
    #$number_output -gt $contador_iteracion
	
    while [ "$(cat sin_confirm.tmp | wc -l)" == "1" ]; do
		curl -s "${sin_conf_url}${number_output}" | html2text >> sin_confirm.tmp
	done
	
	# -> Aca se estan guardando todos los hashes en la variable "hashes"	
	hashes=$(cat sin_confirm.tmp | grep "hash" -A 1 | grep -Ev 'hash|--' | awk -F"," '{ print $1 }' | tr -d "\"" )

    echo "Hash|Cantidad BTC|Valor|Fecha|Tiempo" > sin_confirm.table

	
	for hash in $hashes; do 
		echo "${hash}|$(grep "$hash" -A 6 sin_confirm.tmp | grep "input_total" | awk -F"," '{ print $3}' | awk -F":" '{ print $2}' | xargs -I{}  echo "{}/100000000" |  bc -lq | awk '{printf "%.8f\n", $0}')|$(grep "$hash" -A 6 sin_confirm.tmp | grep "input_total_usd" -A 1 | grep -v "input_total_usd" | awk -F"," '{ print$1 }' | awk '{printf "%'\''.2f\n", $0}')|$(grep "$hash" -A 1 sin_confirm.tmp | grep "time" | awk -F"," '{ print $2 }' | awk -F"\"" '{ print $4 }' | awk '{ print $1 }')|$(grep "$hash" -A 1 sin_confirm.tmp | grep "time" | awk -F"," '{ print $2 }' | awk -F"\"" '{ print $4 }' | awk '{ print $2 }')" >> sin_confirm.table
	done

    valors_USD=$(cat sin_confirm.table | tr "|" " " | awk ' NR>1 { print $3}' | tr -d "," )
    valors_BTC=$(cat sin_confirm.table | awk -F"|" 'NR>1 { print $2 } ')



    echo -ne "${blue}"
    printTable "|" "$(cat sin_confirm.table)"
    echo -ne "${endColour}"

    total_amount_USD="$(suma "${valors_USD}" "2" )"
    echo "Cantidad total USD|Cantidad total BTC" > total_amount.table
    echo -n "\$${total_amount_USD}|" >> total_amount.table

    total_amount_BTC="$(suma "${valors_BTC}" "8" )"
    echo -n "${total_amount_BTC}" >> total_amount.table

    printTable "|" "$(cat total_amount.table)"

	rm *.tmp *.table 2>/dev/null
    tput cnorm; exit 0
} 

function inspect_transaction_now(){
    hash="${1}"

    echo "Entrada BTC|Salida BTC" > inspect_transaction.tmp
    while [ "$( cat inspect_transaction.tmp | wc -l )" == "1" ]; do
        curl -s "${ver_tran_url}${hash}" | awk -F"," '{ for(i=1; i<=NF; i++) print $i }' | grep  -E "input_total\"|output_total\"" | awk -F":" '{ print $2 }' |xargs -I{} echo "{}/100000000" | bc -lq | awk '{ printf "%.8f\n", $0 } ' | xargs  | tr " " "|" >> inspect_transaction.tmp
    done 
    
    printTable "|" "$(cat inspect_transaction.tmp)"

    echo "Direccion (Entradas )|Cantidad BTC" > entradas.tmp
    while [ "$( cat entradas.tmp | wc -l )" == "1" ]; do
        #curl -s "${ver_tran_url}${hash}" | awk -F"," '{ for(i=1; i<=NF; i++) print $i }' | sed -n '/inputs/,/outputs/p' | grep -E "recipient|value\"" | awk -F":" '{ print $2}' | awk 'NR%2 { printf "%s ", $0;next;}1' | awk '{  printf "%.8f ", $1/100000000; print $2}' | awk '{ print $2"|"$1 }' | awk '{gsub("\"", "", $0)}1' >> entradas.tmp
        curl -s "${ver_tran_url}${hash}" | awk -F"," '{ for(i=1; i<=NF; i++) print $i }' | sed -n '/inputs/,/outputs/p' | grep -E "recipient|value\"" | awk -F":" '{ print $2}' | awk 'NR%2 { printf "%s ", $0;next;}1' | awk '{  printf "%.8f ", $1/100000000; print $2}' | awk '{ print $2"|"$1 }' | awk '{gsub("\"", "", $0)}1' >> entradas.tmp

    done
    
    echo "Direccion (Salidas )|Cantidad BTC" > salidas.tmp
    while [ "$( cat salidas.tmp | wc -l )" == "1" ]; do
        curl -s "${ver_tran_url}${hash}" | awk -F"," '{ for(i=1; i<=NF; i++) print $i }' | sed -n '/outputs/,/context/p' | grep -E "recipient|value\"" | awk -F":" '{ print $2}' | awk 'NR%2 { printf "%s ", $0;next;}1' | awk '{  printf "%.8f ", $1/100000000; print $2}' | awk '{ print $2"|"$1 }' | awk '{gsub("\"", "", $0)}1' >> salidas.tmp
    done

    entrada="$( wc -l < entradas.tmp)"
    salida="$( wc -l < salidas.tmp )"

    paste entradas.tmp salidas.tmp | sed 's/[[:space:]]//g'  > result.table
    view_table=$(awk 'NR==2' result.table | wc -c)


    if [ ! $view_table -gt 140 ]; then

        cat entradas.tmp | awk -F"|" '{print $1"|"$2"|"}' > entradas.tmp1
        
        if [ $entrada -gt $salida ]; then
            cantidad=$(($entrada - $salida))
            for((i = 0 ; i < $cantidad ; i++ )); do
                echo "|" >> salidas.tmp
            done
        fi

        if [ $salida -gt $entrada ]; then
            cantidad=$(($salida - $entrada))
            for((i = 0 ; i < $cantidad ; i++ )); do
                echo "||" >> entradas.tmp1
            done
        fi

        paste entradas.tmp1 salidas.tmp | sed 's/[[:space:]]//g'  > result.table

    fi


    if [ $view_table -gt 140 ]; then
        printTable "|" "$(cat entradas.tmp)"
        printTable "|" "$(cat salidas.tmp)"

    else
         printTable "|" "$(cat result.table)"

    fi 



    rm -rf *.table *.tmp* 2>/dev/null
    tput cnorm;
}

function inspect_address_now(){
    address="$1"
    echo "Saldo Actual (BTC)|Cantidad recibida (BTC)|Cantidad enviada (BTC)" > address_BTC.table
    while [ "$( cat address_BTC.table | wc -l )" == "1" ]; do 
        curl -s "${ver_address_url}${address}" | tr -d "{}" | awk -F"," '{ for(i=1;i<=NF;i++) print $i}' | head -n 18 | grep -E "balance\"|received\"|spent\"" | awk -F":" '{ printf "%'\''.8f|", $2/100000000 }' | sed 's/|$//g' | awk -F"|" '{ print $0 }' >> address_BTC.table
    done

    printTable "|" "$(cat address_BTC.table)"

    echo "Saldo Actual (USD)|Cantidad recibida (USD)|Cantidad enviada (USD)" > address_USD.table
    while [ "$( cat address_USD.table | wc -l )" == "1" ]; do 
        curl -s "${ver_address_url}${address}" | tr -d "{}" |awk -F"," '{ for(i=1;i<=NF;i++) print $i}' | head -n 18  | grep -E "balance_|received_|\"spent_" | awk -F":" '{ printf "$%'\''.2f|", $2}' | sed 's/|$//g' | awk -F":" '{ print $0 }' >> address_USD.table
    done

    printTable "|" "$(cat address_USD.table)"

    curl -s "${ver_address_url}${address}" | tr -d "{}" |awk -F"," '{ for(i=1;i<=NF;i++) print $i}' | head -n 18 | grep "transaction_count" | awk -F":" 'BEGIN{ printf "%s|", "Cantidad de transacciones"}{ printf $2}' | awk '{print $0}' > transacciones.table
    printTable "|" "$(cat transacciones.table)"

    rm *.table

}

tput civis
contador=0;
while getopts "e:n:i:a:h:" arg; do 
	case $arg in
		e) explore_mode=$OPTARG; let contador+=1;;
        n) num_result=$OPTARG; let contador+=1;;
        i) inspect_transaction=$OPTARG; let contador+=1;;
        a) inspect_address=$OPTARG; let contador+=1;;
		h) help_panel;;
        esac 

done

# -> "-gt" significa mayor que  

if [ $contador -gt 0 ]; then 

	if [ "$(echo $explore_mode)" == "no_confirmada" ]; then
        #Esto se hace para verificar si la variable "num_result" no tiene nigun valor se le pasa 17 por defecto
        if [ ! $num_result ]; then
            num_result=10
        fi 
		transacciones_no_confirmadas $num_result

    elif [ "$(echo $explore_mode )" == "inspeccionar" ]; then 
        inspect_transaction_now $inspect_transaction

    elif [ $( echo $explore_mode ) == "direccion" ]; then
        inspect_address_now $inspect_address


	fi	
else 
	help_panel
fi  
