#!/bin/bash

# Git User Manager with SSH Support
# Gestiona usuarios de Git Y sus claves SSH correspondientes

set -euo pipefail

# Archivos de configuración
USERS_FILE="$HOME/.git-users-ssh.json"
TEMP_FILE="/tmp/git-users-ssh-temp.json"
SSH_CONFIG="$HOME/.ssh/config"
SSH_CONFIG_BACKUP="$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Funciones de logging
info() { echo -e "${BLUE}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}❌${NC} $1" >&2; }
header() {
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}    🔧 Git User Manager + SSH${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
}

# Inicializar archivos
init_files() {
    if [[ ! -f "$USERS_FILE" ]]; then
        cat > "$USERS_FILE" << 'EOF'
{
  "users": []
}
EOF
        info "Archivo de usuarios con SSH creado: $USERS_FILE"
    fi
    
    if [[ ! -f "$SSH_CONFIG" ]]; then
        touch "$SSH_CONFIG"
        info "Archivo SSH config creado: $SSH_CONFIG"
    fi
}

# Obtener usuarios del JSON
get_users() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.users[] | "\(.id)|\(.name)|\(.email)|\(.ssh_key // "")|\(.host_alias // "")"' "$USERS_FILE" 2>/dev/null || echo ""
    else
        # Fallback básico sin jq
        grep -o '"id":"[^"]*"' "$USERS_FILE" 2>/dev/null | cut -d'"' -f4 | while read -r id; do
            name=$(grep -A5 "\"id\":\"$id\"" "$USERS_FILE" | grep '"name"' | cut -d'"' -f4)
            email=$(grep -A5 "\"id\":\"$id\"" "$USERS_FILE" | grep '"email"' | cut -d'"' -f4)
            ssh_key=$(grep -A5 "\"id\":\"$id\"" "$USERS_FILE" | grep '"ssh_key"' | cut -d'"' -f4 || echo "")
            host_alias=$(grep -A5 "\"id\":\"$id\"" "$USERS_FILE" | grep '"host_alias"' | cut -d'"' -f4 || echo "")
            echo "$id|$name|$email|$ssh_key|$host_alias"
        done 2>/dev/null || echo ""
    fi
}

# Mostrar usuario y SSH actual
show_current_user() {
    header
    echo -e "${CYAN}📋 CONFIGURACIÓN ACTUAL${NC}"
    echo ""
    
    # Configuración Git
    local effective_name=$(git config user.name 2>/dev/null || echo "No configurado")
    local effective_email=$(git config user.email 2>/dev/null || echo "No configurado")
    local global_name=$(git config --global user.name 2>/dev/null || echo "No configurado")
    local global_email=$(git config --global user.email 2>/dev/null || echo "No configurado")
    
    echo -e "${GREEN}🎯 GIT - CONFIGURACIÓN EFECTIVA:${NC}"
    echo -e "   👤 Nombre: ${YELLOW}$effective_name${NC}"
    echo -e "   📧 Email:  ${YELLOW}$effective_email${NC}"
    
    echo -e "${BLUE}🌍 GIT - CONFIGURACIÓN GLOBAL:${NC}"
    echo -e "   👤 Nombre: $global_name"
    echo -e "   📧 Email:  $global_email"
    
    # Información SSH
    echo ""
    echo -e "${PURPLE}🔑 SSH - CONFIGURACIÓN ACTUAL:${NC}"
    
    # SSH Agent
    if ssh-add -l &>/dev/null; then
        echo -e "   🟢 SSH Agent: ${GREEN}Activo${NC}"
        echo -e "   🔐 Claves cargadas:"
        ssh-add -l | while read -r line; do
            echo -e "      • $line"
        done
    else
        echo -e "   🔴 SSH Agent: ${RED}No activo o sin claves${NC}"
    fi
    
    # SSH Config para el repo actual
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
        echo ""
        echo -e "${YELLOW}📁 REPOSITORIO ACTUAL:${NC}"
        local repo_name=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "Desconocido")
        echo -e "   📂 Nombre: $repo_name"
        echo -e "   🌐 URL: $repo_url"
        
        # Detectar qué host SSH se usaría
        if [[ "$repo_url" =~ git@ ]]; then
            local ssh_host=$(echo "$repo_url" | sed 's/git@\([^:]*\):.*/\1/')
            echo -e "   🖥️  Host SSH: $ssh_host"
            
            # Buscar configuración SSH para este host
            if grep -q "Host.*$ssh_host" "$SSH_CONFIG" 2>/dev/null; then
                echo -e "   ⚙️  Config SSH: ${GREEN}Configurado${NC}"
                local ssh_user=$(grep -A5 "Host.*$ssh_host" "$SSH_CONFIG" | grep "User" | head -1 | awk '{print $2}' || echo "")
                local ssh_key_file=$(grep -A5 "Host.*$ssh_host" "$SSH_CONFIG" | grep "IdentityFile" | head -1 | awk '{print $2}' || echo "")
                [[ -n "$ssh_user" ]] && echo -e "      👤 Usuario SSH: $ssh_user"
                [[ -n "$ssh_key_file" ]] && echo -e "      🔑 Clave SSH: $ssh_key_file"
            else
                warning "No hay configuración SSH específica para $ssh_host"
            fi
        fi
        
        # Verificar configuración local vs global
        local local_name=$(git config --local user.name 2>/dev/null || echo "")
        local local_email=$(git config --local user.email 2>/dev/null || echo "")
        
        if [[ -n "$local_name" ]] || [[ -n "$local_email" ]]; then
            echo ""
            if [[ "$effective_name" != "$global_name" ]] || [[ "$effective_email" != "$global_email" ]]; then
                error "⚠️  CONFLICTO: Configuración local sobrescribe la global"
            else
                info "ℹ️  Este repositorio tiene configuración local"
            fi
            echo -e "${RED}🏠 CONFIGURACIÓN LOCAL:${NC}"
            echo -e "   👤 Nombre: ${local_name:-'No configurado'}"
            echo -e "   📧 Email:  ${local_email:-'No configurado'}"
        fi
    fi
    
    echo ""
}

# Cambiar usuario y SSH
switch_user() {
    header
    echo -e "${CYAN}🔄 CAMBIAR USUARIO + SSH${NC}"
    echo ""
    
    local users_data=$(get_users)
    
    if [[ -z "$users_data" ]]; then
        warning "No hay usuarios guardados."
        echo ""
        echo "💡 Usa la opción 'agregar' para añadir usuarios primero."
        return 1
    fi
    
    echo -e "${GREEN}Usuarios disponibles:${NC}"
    echo ""
    
    local -a user_data_array=()
    local counter=1
    
    while IFS='|' read -r id name email ssh_key host_alias; do
        if [[ -n "$id" ]]; then
            echo -e "  ${YELLOW}[$counter]${NC} $name"
            echo -e "      📧 $email"
            echo -e "      🆔 ID: $id"
            [[ -n "$ssh_key" ]] && echo -e "      🔑 SSH: $ssh_key"
            [[ -n "$host_alias" ]] && echo -e "      🏷️  Alias: $host_alias"
            echo ""
            user_data_array+=("$id|$name|$email|$ssh_key|$host_alias")
            ((counter++))
        fi
    done <<< "$users_data"
    
    echo -n "Selecciona un usuario [1-$((counter-1))] o 'q' para salir: "
    read -r selection
    
    if [[ "$selection" == "q" ]] || [[ "$selection" == "Q" ]]; then
        info "Operación cancelada."
        return 0
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -ge "$counter" ]]; then
        error "Selección inválida."
        return 1
    fi
    
    # Obtener datos del usuario seleccionado
    local selected_user="${user_data_array[$((selection-1))]}"
    IFS='|' read -r sel_id sel_name sel_email sel_ssh_key sel_host_alias <<< "$selected_user"
    
    echo ""
    echo -e "${GREEN}🔄 Cambiando configuración...${NC}"
    
    # 1. Cambiar configuración Git
    git config --global user.name "$sel_name"
    git config --global user.email "$sel_email"
    echo -e "  ✅ Git configurado: $sel_name <$sel_email>"
    
    # 2. Configurar SSH si está especificado
    if [[ -n "$sel_ssh_key" ]] && [[ -f "$sel_ssh_key" ]]; then
        # Limpiar SSH agent
        ssh-add -D 2>/dev/null || true
        
        # Agregar la nueva clave
        if ssh-add "$sel_ssh_key" 2>/dev/null; then
            echo -e "  ✅ Clave SSH cargada: $sel_ssh_key"
        else
            warning "No se pudo cargar la clave SSH: $sel_ssh_key"
        fi
    fi
    
    # 3. Aplicar configuración local si estamos en un repo
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        echo ""
        echo -n "¿Aplicar también al repositorio actual? [y/N]: "
        read -r apply_local
        
        if [[ "$apply_local" =~ ^[Yy]$ ]]; then
            git config --local user.name "$sel_name"
            git config --local user.email "$sel_email"
            echo -e "  ✅ Configuración local actualizada"
        fi
    fi
    
    echo ""
    success "Usuario cambiado a: $sel_id"
    
    # Mostrar configuración resultante
    echo ""
    echo -e "${BLUE}📋 Estado actual:${NC}"
    echo -e "  👤 Git: $(git config user.name) <$(git config user.email)>"
    if ssh-add -l &>/dev/null; then
        echo -e "  🔑 SSH: $(ssh-add -l | wc -l) clave(s) cargada(s)"
    else
        echo -e "  🔑 SSH: Sin claves cargadas"
    fi
    
    echo ""
}

# Agregar nuevo usuario con SSH
add_user() {
    header
    echo -e "${CYAN}➕ AGREGAR NUEVO USUARIO + SSH${NC}"
    echo ""
    
    # Solicitar información básica
    echo -n "🆔 ID del usuario (ej: personal, trabajo, freelance): "
    read -r user_id
    
    if [[ -z "$user_id" ]]; then
        error "El ID no puede estar vacío."
        return 1
    fi
    
    # Verificar si ya existe
    local existing_users=$(get_users)
    if echo "$existing_users" | cut -d'|' -f1 | grep -q "^$user_id$"; then
        error "El ID '$user_id' ya existe."
        return 1
    fi
    
    echo -n "👤 Nombre completo: "
    read -r user_name
    
    if [[ -z "$user_name" ]]; then
        error "El nombre no puede estar vacío."
        return 1
    fi
    
    echo -n "📧 Email: "
    read -r user_email
    
    if [[ -z "$user_email" ]]; then
        error "El email no puede estar vacío."
        return 1
    fi
    
    # Configuración SSH
    echo ""
    echo -e "${PURPLE}🔑 CONFIGURACIÓN SSH (opcional):${NC}"
    echo -n "🔐 Ruta a la clave SSH privada (Enter para omitir): "
    read -r ssh_key_path
    
    local host_alias=""
    if [[ -n "$ssh_key_path" ]]; then
        # Expandir tilde
        ssh_key_path="${ssh_key_path/#\~/$HOME}"
        
        if [[ ! -f "$ssh_key_path" ]]; then
            warning "El archivo $ssh_key_path no existe."
            echo -n "¿Continuar sin clave SSH? [Y/n]: "
            read -r continue_without
            if [[ "$continue_without" =~ ^[Nn]$ ]]; then
                info "Operación cancelada."
                return 0
            fi
            ssh_key_path=""
        else
            echo -n "🏷️  Alias de host (ej: github-personal): "
            read -r host_alias
        fi
    fi
    
    # Mostrar resumen
    echo ""
    echo -e "${GREEN}📋 RESUMEN DEL NUEVO USUARIO:${NC}"
    echo -e "  🆔 ID: $user_id"
    echo -e "  👤 Nombre: $user_name"
    echo -e "  📧 Email: $user_email"
    [[ -n "$ssh_key_path" ]] && echo -e "  🔑 SSH Key: $ssh_key_path"
    [[ -n "$host_alias" ]] && echo -e "  🏷️  Host Alias: $host_alias"
    echo ""
    
    echo -n "¿Confirmar? [Y/n]: "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        info "Operación cancelada."
        return 0
    fi
    
    # Agregar usuario al archivo JSON
    if command -v jq >/dev/null 2>&1; then
        local ssh_key_json="null"
        local host_alias_json="null"
        [[ -n "$ssh_key_path" ]] && ssh_key_json="\"$ssh_key_path\""
        [[ -n "$host_alias" ]] && host_alias_json="\"$host_alias\""
        
        jq --arg id "$user_id" --arg name "$user_name" --arg email "$user_email" \
           --argjson ssh_key "$ssh_key_json" --argjson host_alias "$host_alias_json" \
           '.users += [{"id": $id, "name": $name, "email": $email, "ssh_key": $ssh_key, "host_alias": $host_alias}]' \
           "$USERS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$USERS_FILE"
    else
        # Fallback sin jq
        cp "$USERS_FILE" "$SSH_CONFIG_BACKUP.json"
        head -n -2 "$USERS_FILE" > "$TEMP_FILE"
        
        if grep -q '"id"' "$USERS_FILE"; then
            echo '    ,' >> "$TEMP_FILE"
        fi
        
        cat >> "$TEMP_FILE" << EOF
    {
      "id": "$user_id",
      "name": "$user_name",
      "email": "$user_email"$([ -n "$ssh_key_path" ] && echo ",
      \"ssh_key\": \"$ssh_key_path\"")$([ -n "$host_alias" ] && echo ",
      \"host_alias\": \"$host_alias\"")
    }
  ]
}
EOF
        
        mv "$TEMP_FILE" "$USERS_FILE"
    fi
    
    success "Usuario '$user_id' agregado exitosamente."
    
    # Configurar SSH config si se especificó
    if [[ -n "$ssh_key_path" ]] && [[ -n "$host_alias" ]]; then
        echo ""
        echo -n "¿Agregar configuración SSH automática? [Y/n]: "
        read -r add_ssh_config
        
        if [[ ! "$add_ssh_config" =~ ^[Nn]$ ]]; then
            # Backup del SSH config
            cp "$SSH_CONFIG" "$SSH_CONFIG_BACKUP"
            
            echo "" >> "$SSH_CONFIG"
            echo "# Configuración para $user_id" >> "$SSH_CONFIG"
            echo "Host $host_alias" >> "$SSH_CONFIG"
            echo "    HostName github.com" >> "$SSH_CONFIG"
            echo "    User git" >> "$SSH_CONFIG"
            echo "    IdentityFile $ssh_key_path" >> "$SSH_CONFIG"
            echo "    IdentitiesOnly yes" >> "$SSH_CONFIG"
            
            success "Configuración SSH agregada para $host_alias"
            info "Backup creado: $SSH_CONFIG_BACKUP"
        fi
    fi
    
    # Preguntar si cambiar a este usuario
    echo ""
    echo -n "¿Cambiar a este usuario ahora? [Y/n]: "
    read -r switch_now
    
    if [[ ! "$switch_now" =~ ^[Nn]$ ]]; then
        git config --global user.name "$user_name"
        git config --global user.email "$user_email"
        
        if [[ -n "$ssh_key_path" ]]; then
            ssh-add -D 2>/dev/null || true
            ssh-add "$ssh_key_path" 2>/dev/null && success "Clave SSH cargada"
        fi
        
        success "Usuario activo cambiado a '$user_id'."
    fi
    
    echo ""
}

# Generar nueva clave SSH
generate_ssh_key() {
    header
    echo -e "${CYAN}🔑 GENERAR NUEVA CLAVE SSH${NC}"
    echo ""
    
    echo -n "📧 Email para la clave SSH: "
    read -r ssh_email
    
    if [[ -z "$ssh_email" ]]; then
        error "El email no puede estar vacío."
        return 1
    fi
    
    echo -n "📁 Nombre del archivo (sin extensión): "
    read -r key_name
    
    if [[ -z "$key_name" ]]; then
        error "El nombre no puede estar vacío."
        return 1
    fi
    
    local key_path="$HOME/.ssh/$key_name"
    
    if [[ -f "$key_path" ]]; then
        error "Ya existe una clave con ese nombre."
        return 1
    fi
    
    echo ""
    info "Generando clave SSH..."
    
    ssh-keygen -t ed25519 -C "$ssh_email" -f "$key_path" -N ""
    
    if [[ $? -eq 0 ]]; then
        success "Clave SSH generada: $key_path"
        echo ""
        echo -e "${YELLOW}🔑 CLAVE PÚBLICA (para agregar a GitHub/GitLab):${NC}"
        echo ""
        cat "$key_path.pub"
        echo ""
        
        echo -n "¿Cargar esta clave en el SSH agent? [Y/n]: "
        read -r load_key
        
        if [[ ! "$load_key" =~ ^[Nn]$ ]]; then
            ssh-add "$key_path" && success "Clave cargada en SSH agent"
        fi
        
        echo ""
        info "Ahora puedes usar esta clave al agregar un usuario:"
        echo "  Ruta: $key_path"
    else
        error "Error al generar la clave SSH."
    fi
    
    echo ""
}

# Limpiar configuración local
clean_local_config() {
    header
    echo -e "${CYAN}🧹 LIMPIAR CONFIGURACIÓN LOCAL${NC}"
    echo ""
    
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        error "No estás en un repositorio Git."
        return 1
    fi
    
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    local local_name=$(git config --local user.name 2>/dev/null || echo "")
    local local_email=$(git config --local user.email 2>/dev/null || echo "")
    
    if [[ -z "$local_name" ]] && [[ -z "$local_email" ]]; then
        success "No hay configuración local que limpiar."
        return 0
    fi
    
    echo -e "${YELLOW}📁 Repositorio: $repo_name${NC}"
    echo ""
    echo -e "${RED}🗑️  Se eliminará la configuración local:${NC}"
    [[ -n "$local_name" ]] && echo -e "   👤 Nombre: $local_name"
    [[ -n "$local_email" ]] && echo -e "   📧 Email: $local_email"
    echo ""
    
    echo -n "¿Continuar? [y/N]: "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Operación cancelada."
        return 0
    fi
    
    [[ -n "$local_name" ]] && git config --local --unset user.name
    [[ -n "$local_email" ]] && git config --local --unset user.email
    
    success "Configuración local eliminada."
    echo ""
    
    local global_name=$(git config --global user.name 2>/dev/null || echo "No configurado")
    local global_email=$(git config --global user.email 2>/dev/null || echo "No configurado")
    echo -e "${GREEN}Ahora se usará la configuración global:${NC}"
    echo -e "   👤 Nombre: $global_name"
    echo -e "   📧 Email:  $global_email"
    echo ""
}

# Listar usuarios
list_users() {
    header
    echo -e "${CYAN}📋 USUARIOS GUARDADOS${NC}"
    echo ""
    
    local users_data=$(get_users)
    
    if [[ -z "$users_data" ]]; then
        warning "No hay usuarios guardados."
        echo ""
        echo "💡 Usa la opción 'agregar' para añadir usuarios."
        return 0
    fi
    
    local counter=1
    while IFS='|' read -r id name email ssh_key host_alias; do
        if [[ -n "$id" ]]; then
            echo -e "${YELLOW}[$counter] $id${NC}"
            echo -e "   👤 $name"
            echo -e "   📧 $email"
            [[ -n "$ssh_key" ]] && echo -e "   🔑 SSH: $ssh_key"
            [[ -n "$host_alias" ]] && echo -e "   🏷️  Alias: $host_alias"
            echo ""
            ((counter++))
        fi
    done <<< "$users_data"
}

# Mostrar ayuda
show_help() {
    header
    echo -e "${CYAN}📖 AYUDA${NC}"
    echo ""
    echo "Este programa gestiona usuarios Git Y sus claves SSH asociadas."
    echo ""
    echo "Uso: $0 [opción]"
    echo ""
    echo "Opciones disponibles:"
    echo -e "  ${GREEN}actual${NC}        Mostrar configuración actual (Git + SSH)"
    echo -e "  ${GREEN}cambiar${NC}       Cambiar usuario y cargar su clave SSH"
    echo -e "  ${GREEN}agregar${NC}       Agregar nuevo usuario con clave SSH"
    echo -e "  ${GREEN}generar${NC}       Generar nueva clave SSH"
    echo -e "  ${GREEN}listar${NC}        Listar todos los usuarios guardados"
    echo -e "  ${GREEN}limpiar${NC}       Limpiar configuración local del repo"
    echo -e "  ${GREEN}ayuda${NC}         Mostrar esta ayuda"
    echo ""
    echo -e "${YELLOW}🔑 Gestión de SSH:${NC}"
    echo "• Las claves SSH se cargan automáticamente al cambiar usuario"
    echo "• Se puede generar nuevas claves SSH desde el programa"
    echo "• Se gestiona automáticamente el archivo ~/.ssh/config"
    echo ""
    echo -e "${YELLOW}Ejemplos de uso:${NC}"
    echo "  $0 actual         # Ver configuración actual"
    echo "  $0 cambiar        # Cambiar usuario y SSH"
    echo "  $0 generar        # Generar nueva clave SSH"
    echo ""
}

# Menú interactivo
show_menu() {
    while true; do
        header
        echo -e "${CYAN}🔧 MENÚ PRINCIPAL${NC}"
        echo ""
        echo -e "${GREEN}[1]${NC} 👁️  Ver configuración actual (Git + SSH)"
        echo -e "${GREEN}[2]${NC} 🔄 Cambiar usuario + SSH"
        echo -e "${GREEN}[3]${NC} ➕ Agregar nuevo usuario + SSH"
        echo -e "${GREEN}[4]${NC} 🔑 Generar nueva clave SSH"
        echo -e "${GREEN}[5]${NC} 📋 Listar usuarios guardados"
        echo -e "${GREEN}[6]${NC} 🧹 Limpiar config local"
        echo -e "${GREEN}[7]${NC} 📖 Ayuda"
        echo -e "${GREEN}[0]${NC} 🚪 Salir"
        echo ""
        echo -n "Selecciona una opción [0-7]: "
        read -r option
        
        case $option in
            1) show_current_user; echo ""; echo -n "Presiona Enter..."; read -r ;;
            2) switch_user; echo ""; echo -n "Presiona Enter..."; read -r ;;
            3) add_user; echo ""; echo -n "Presiona Enter..."; read -r ;;
            4) generate_ssh_key; echo ""; echo -n "Presiona Enter..."; read -r ;;
            5) list_users; echo ""; echo -n "Presiona Enter..."; read -r ;;
            6) clean_local_config; echo ""; echo -n "Presiona Enter..."; read -r ;;
            7) show_help; echo ""; echo -n "Presiona Enter..."; read -r ;;
            0) echo ""; info "¡Hasta luego! 👋"; exit 0 ;;
            *) echo ""; error "Opción inválida."; echo -n "Presiona Enter..."; read -r ;;
        esac
    done
}

# Función principal
main() {
    # Verificar dependencias
    if ! command -v git >/dev/null 2>&1; then
        error "Git no está instalado."
        exit 1
    fi
    
    if ! command -v ssh-keygen >/dev/null 2>&1; then
        error "ssh-keygen no está disponible."
        exit 1
    fi
    
    # Inicializar archivos
    init_files
    
    # Procesar argumentos
    case "${1:-}" in
        "actual"|"current"|"status") show_current_user ;;
        "cambiar"|"switch"|"change") switch_user ;;
        "agregar"|"add"|"nuevo") add_user ;;
        "generar"|"generate"|"keygen") generate_ssh_key ;;
        "listar"|"list"|"ls") list_users ;;
        "limpiar"|"clean"|"fix") clean_local_config ;;
        "ayuda"|"help"|"-h"|"--help") show_help ;;
        "") show_menu ;;
        *) error "Opción desconocida: $1"; echo ""; show_help; exit 1 ;;
    esac
}

main "$@"
