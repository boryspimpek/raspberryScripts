#!/bin/bash

show_menu() {
  clear
  echo "================================================"
  echo "            🛠️  WIFI CONNECTIOMS"
  echo "================================================"
  echo "1) 🔌 Skanuj i połącz z siecią Wi-Fi"
  echo "2) 🔁 Zarządzanie połączeniami"
  echo "3) 🧼 Usuń wszystkie zapisane sieci Wi-Fi"
  echo "4) 🔌 Toggle wlan"
  echo "5) 📶 Toggle Wi-Fi"
  echo "6) 📡 Utwórz Hotspot Wi-Fi"
  echo "7) 🧾 Informacje o urządzeniach i stanie sieci"
  echo "q) ❌ Wyjście"
  echo "================================================"
}

connect_to_wifi() {
  clear
  echo -e "\n🌐 Wybierz interfejs Wi-Fi:"
  select iface in "wlan0" "wlan1" "wlan2" "Anuluj"; do
    case "$REPLY" in
      1|3)
        INTERFACE=$iface
        break
        ;;
      4)
        return
        ;;
      *)
        echo "❌ Nieprawidłowy wybór."
        ;;
    esac
  done

  clear
  echo -e "\n🔍 Skanuję sieci Wi-Fi na interfejsie: $INTERFACE..."
  sudo nmcli device wifi rescan ifname "$INTERFACE" >/dev/null 2>&1
  sleep 2

  SSIDS=$(nmcli -t -f SSID,SIGNAL device wifi list ifname "$INTERFACE" | awk -F: '!seen[$1]++ && $1 != "" {printf "%s (%s%%)\n", $1, $2}')
  if [ -z "$SSIDS" ]; then
    echo "❌ Nie znaleziono żadnych sieci Wi-Fi."
    read -p "ENTER, by wrócić do menu..." dummy
    return
  fi

  echo -e "\n📡 Wybierz sieć Wi-Fi:"
  IFS=$'\n' read -rd '' -a ssid_list <<<"$SSIDS"
  select chosen in "${ssid_list[@]}" "Anuluj"; do
    if [[ $REPLY -gt 0 && $REPLY -le ${#ssid_list[@]} ]]; then
      SSID=$(echo "$chosen" | cut -d'(' -f1 | sed 's/ *$//')
      read -s -p "🔑 Hasło do \"$SSID\" (q aby wrócić): " PASSWORD
      echo
      if [[ "$PASSWORD" == "q" ]]; then break; fi
      sudo nmcli device wifi connect "$SSID" password "$PASSWORD" ifname "$INTERFACE"
      break
    elif [[ $REPLY -eq $((${#ssid_list[@]} + 1)) ]]; then
      break
    else
      echo "❌ Nieprawidłowy wybór."
    fi
  done

  read -p "ENTER, by wrócić do menu..." dummy
}

connection_mgmt() {
  clear
  echo -e "\n🔁 Connection Manager:"
  echo "_____________________________"
  echo

  mapfile -t connections < <(nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless' | cut -d: -f1)

  if [ ${#connections[@]} -eq 0 ]; then
    echo "❌ Brak zapisanych połączeń Wi-Fi."
    read -p "ENTER, by wrócić do menu..." dummy
    return
  fi

  mapfile -t active_connections < <(nmcli -t -f NAME,TYPE connection show --active | grep ":802-11-wireless" | cut -d: -f1)

  declare -a wlan0_list
  declare -a wlan1_list
  declare -a wlan2_list
  declare -a indexed_connections

  for con in "${connections[@]}"; do
    iface=$(nmcli connection show "$con" | grep "interface-name" | awk '{print $2}')
    if [[ "$iface" == "wlan0" ]]; then
      wlan0_list+=("$con")
    elif [[ "$iface" == "wlan1" ]]; then
      wlan1_list+=("$con")
    elif [[ "$iface" == "wlan2" ]]; then
      wlan2_list+=("$con")
    fi
  done

  echo "🔌 Połączenia dla wlan0:"
  echo "------------------------"
  for con in "${wlan0_list[@]}"; do
    indexed_connections+=("$con")
    num=${#indexed_connections[@]}
    autoconnect=$(nmcli -g connection.autoconnect connection show "$con")
    if printf '%s\n' "${active_connections[@]}" | grep -qx "$con"; then
      echo "$num) $con ✅ AKTYWNE (autoconnect: $autoconnect)"
    else
      echo "$num) $con (autoconnect: $autoconnect)"
    fi
  done

  echo -e "\n🔌 Połączenia dla wlan1:"
  echo "------------------------"
  for con in "${wlan1_list[@]}"; do
    indexed_connections+=("$con")
    num=${#indexed_connections[@]}
    autoconnect=$(nmcli -g connection.autoconnect connection show "$con")
    if printf '%s\n' "${active_connections[@]}" | grep -qx "$con"; then
      echo "$num) $con ✅ AKTYWNE (autoconnect: $autoconnect)"
    else
      echo "$num) $con (autoconnect: $autoconnect)"
    fi
  done

  echo -e "\n🔌 Połączenia dla wlan2:"
  echo "------------------------"
  for con in "${wlan2_list[@]}"; do
    indexed_connections+=("$con")
    num=${#indexed_connections[@]}
    autoconnect=$(nmcli -g connection.autoconnect connection show "$con")
    if printf '%s\n' "${active_connections[@]}" | grep -qx "$con"; then
      echo "$num) $con ✅ AKTYWNE (autoconnect: $autoconnect)"
    else
      echo "$num) $con (autoconnect: $autoconnect)"
    fi
  done

  echo -e "\nDostępne opcje:"
  echo "1) Aktywuj połączenie"
  echo "2) Dezaktywuj połączenie"
  echo "3) Usuń połączenie"
  echo "4) Pokaż szczegóły"
  echo "5) Autoconnect on"
  echo "6) Autoconnect off"
  echo "7) Wróć"

  while true; do
    read -p "Wybierz opcję (1-7): " opt

    if [[ "$opt" == "7" || -z "$opt" ]]; then
      echo "↩️  Powrót do menu."
      read -p "ENTER, by kontynuować..." dummy
      return
    elif [[ "$opt" =~ ^[1-6]$ ]]; then
      read -p "Wybierz numer połączenia: " num
      if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#indexed_connections[@]} )); then
        conn_name="${indexed_connections[$((num-1))]}"
        case $opt in
          1) iface=$(nmcli -g connection.interface-name connection show "$conn_name")
             sudo nmcli connection up "$conn_name" ifname "$iface"            
             ;;
          2) sudo nmcli connection down "$conn_name" ;;
          3) sudo nmcli connection delete "$conn_name" ;;
          4) clear; nmcli connection show "$conn_name" ;;
          5) echo AUTO=$(nmcli -g connection.autoconnect connection show "$conn_name")
             sudo nmcli connection modify "$conn_name" connection.autoconnect yes
             echo AUTO=$(nmcli -g connection.autoconnect connection show "$conn_name")
             echo "✅ Autoconnect włączony."
             ;;
          6) echo AUTO=$(nmcli -g connection.autoconnect connection show "$conn_name")
             sudo nmcli connection modify "$conn_name" connection.autoconnect no
             echo AUTO=$(nmcli -g connection.autoconnect connection show "$conn_name")
             echo "✅ Autoconnect wyłączony."
             ;;
        esac
        break
      else
        echo "❌ Nieprawidłowy numer połączenia. Spróbuj ponownie."
      fi
    else
      echo "❌ Nieprawidłowa opcja. Spróbuj ponownie."
    fi
  done

  read -p "ENTER, by wrócić do menu..." dummy
}

create_hotspot() {
  read -p "Nazwa sieci (SSID): " SSID
  read -s -p "Hasło (min 8 znaków): " PASS
  echo
  nmcli device wifi hotspot ifname wlan0 ssid "$SSID" password "$PASS"
  read -p "ENTER, by wrócić do menu..." dummy
}

device_info() {
  clear
  echo "🔌 Status urządzeń sieciowych:"
  echo "------------------------------------"
  nmcli device status | awk '$2 != "wifi-p2p"'
  echo

  echo "🌐 Ogólny status sieci:"
  echo "------------------------------------"
  nmcli general status
  echo

  read -p "Naciśnij ENTER, by wrócić..." dummy
}

toggle_wifi() {
  clear
  while true; do
    clear
    echo -e "\n📶 Obecny stan Wi-Fi: $(nmcli radio wifi)"
    echo -e "\n1) Włącz Wi-Fi"
    echo "2) Wyłącz Wi-Fi"
    echo "3) Wróć..."
    read -p "Wybierz: " opt
    case $opt in
      1)
        nmcli radio wifi on
        echo "✅ Wi-Fi włączone."
        echo "🔄 Aktualny stan: $(nmcli radio wifi)"
        break
        ;;
      2)
        nmcli radio wifi off
        echo "✅ Wi-Fi wyłączone."
        echo "🔄 Aktualny stan: $(nmcli radio wifi)"
        break
        ;;
      3)
        echo "↩️  Powrót do menu..."
        break
        ;;
      *)
        echo "❌ Nieprawidłowy wybór."
        ;;
    esac
  done
  read -p "ENTER, by wrócić do menu..." dummy
}

toggle_wlan() {
  clear

  # Pobierz dostępne interfejsy Wi-Fi
  interfaces=$(nmcli device status | awk '$2 == "wifi" {print $1}')
  echo -e "📶 Dostępne interfejsy Wi-Fi:\n"

  # Wyświetl je z numeracją
  select iface in $interfaces "Wróć"; do
    if [[ "$iface" == "Wróć" ]]; then
      echo "↩️  Powrót do menu..."
      return
    elif [[ -n "$iface" ]]; then
      break
    else
      echo "❌ Nieprawidłowy wybór."
    fi
  done

  # Menu operacji na wybranym interfejsie
  while true; do
    clear
    status=$(nmcli device status | awk -v iface="$iface" '$1 == iface {print $3}')
    echo -e "\n📡 Status urządzenia $iface: $status"
    echo -e "\n1) Rozłącz $iface"
    echo "2) Podłącz $iface"
    echo "3) Wróć..."
    read -p "Wybierz: " opt
    case $opt in
      1)
        sudo nmcli device disconnect "$iface"
        echo "✅ $iface zostało rozłączone."
        ;;
      2)
        sudo nmcli device connect "$iface"
        echo "✅ $iface zostało podłączone."
        ;;
      3)
        echo "↩️  Powrót do wyboru interfejsu..."
        break
        ;;
      *)
        echo "❌ Nieprawidłowy wybór."
        ;;
    esac
    status_after=$(nmcli device status | awk -v iface="$iface" '$1 == iface {print $3}')
    echo "🔄 Aktualny status $iface: $status_after"
    read -p "ENTER, by kontynuować..." dummy
  done
}

clean_wifi() {
  clear
  echo -e "\n📋 Zapisane połączenia Wi-Fi:"
  nmcli -f NAME,TYPE connection show | awk '$2 == "wifi" {print " - " $1}'

  echo -e "\n⚠️  Czy na pewno chcesz usunąć wszystkie zapisane sieci Wi-Fi? (t/n)"
  read -p "> " confirm
  if [[ "$confirm" != "t" && "$confirm" != "T" ]]; then
    echo "❌ Anulowano. Żadne połączenie nie zostało usunięte."
    read -p "ENTER, by wrócić do menu..." dummy
    return
  fi

  echo -e "\n🧼 Usuwam zapisane połączenia Wi-Fi..."
  nmcli -t -f NAME,TYPE connection show | awk -F: '$2 == "wifi"' | while IFS=: read -r name type; do
    nmcli connection delete "$name"
  done

  echo "✅ Wszystkie zapisane sieci Wi-Fi zostały usunięte."
  read -p "ENTER, by wrócić do menu..." dummy
}

# Główna pętla
# Główna pętla
while true; do
  show_menu
  read -p "Wybierz opcję: " choice
  case $choice in
    1) connect_to_wifi ;;
    2) connection_mgmt ;;
    3) clean_wifi ;;
    4) toggle_wlan ;;
    5) toggle_wifi ;;
    6) create_hotspot ;;
    7) device_info ;;
    q|Q) 
      echo "👋 Do zobaczenia!"
      sleep 1
      clear
      exit 0
      ;;
    *) 
      echo "❌ Nieprawidłowy wybór."
      sleep 1
      ;;
  esac
done
