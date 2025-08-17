#!/bin/bash

# Git User Manager
# Programa simple para gestionar usuarios de Git
# Funcionalidades: Identificar usuario actual, Cambiar usuarios, Agregar usuarios

set -euo pipefail

# Archivo donde se guardan los usuarios
USERS_FILE="$HOME/.git-users.json"
TEMP_FILE="/tmp/git-users-temp.json"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para logging con colores
info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

error() {
    echo -e "${RED}❌${NC} $1" >&2
}

header() {
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}        🔧 Git User Manager${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
}

# Inicializar archivo de usuarios si no existe
init_users_file() {
    if [[ ! -f "$USERS_FILE" ]]; then
        echo '{"users": []}' > "$USERS_FILE"
        info "Archivo de usuarios creado: $USERS_FILE"
    fi
}

# Función para obtener usuarios del archivo JSON
get_users() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.users[] | "\(.id)|\(.name)|\(.email)"' "$USERS_FILE" 2>/dev/null || echo ""
    else
        # Fallback sin jq
        grep -o '"id":"[^"]*"' "$USERS_FILE" | cut -d'"' -f4 | while read -r id; do
            name=$(grep -A2 "\"id\":\"$id\"" "$USERS_FILE" | grep '"name"' | cut -d'"' -f4)
            email=$(grep -A3 "\"id\":\"$id\"" "$USERS_FILE" | grep '"email"' | cut -d'"' -f4)
            echo "$id|$name|$email"
        done 2>/dev/null || echo ""
    fi
}

# Función 1: Identificar usuario actual
show_current_user() {
    header
    echo -e "${CYAN}📋 USUARIO ACTUAL${NC}"
    echo ""
    
    # Obtener configuración actual
    local current_name=$(git config --global user.name 2>/dev/null || echo "No configurado")
    local current_email=$(git config --global user.email 2>/dev/null || echo "No configurado")
    
    # Mostrar información del usuario actual
    echo -e "👤 ${GREEN}Nombre:${NC} $current_name"
    echo -e "📧 ${GREEN}Email:${NC}  $current_email"
    
    # Verificar si estamos en un repositorio
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local repo_name=$(basename "$(git rev-parse --show-toplevel)")
        local repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "Sin remoto")
        echo ""
        echo -e "${YELLOW}📁 Repositorio actual:${NC}"
        echo -e "   Nombre: $repo_name"
        echo -e "   URL: $repo_url"
        
        # Verificar configuración local vs global
        local local_name=$(git config --local user.name 2>/dev/null || echo "")
        local local_email=$(git config --local user.email 2>/dev/null || echo "")
        
        if [[ -n "$local_name" ]] || [[ -n "$local_email" ]]; then
            echo ""
            warning "Este repositorio tiene configuración LOCAL:"
            echo -e "   👤 Nombre local: ${local_name:-'No configurado'}"
            echo -e "   📧 Email local:  ${local_email:-'No configurado'}"
        fi
    fi
    
    echo ""
}

# Función 2: Cambiar entre usuarios
switch_user() {
    header
    echo -e "${CYAN}🔄 CAMBIAR USUARIO${NC}"
    echo ""
    
    # Mostrar usuarios disponibles
    local users_data=$(get_users)
    
    if [[ -z "$users_data" ]]; then
        warning "No hay usuarios guardados."
        echo ""
        echo "💡 Usa la opción 'agregar' para añadir usuarios primero."
        return 1
    fi
    
    echo -e "${GREEN}Usuarios disponibles:${NC}"
    echo ""
    
    local -a user_ids=()
    local counter=1
    
    while IFS='|' read -r id name email; do
        if [[ -n "$id" ]]; then
            echo -e "  ${YELLOW}[$counter]${NC} $name"
            echo -e "      📧 $email"
            echo -e "      🆔 ID: $id"
            echo ""
            user_ids+=("$id|$name|$email")
            ((counter++))
        fi
    done <<< "$users_data"
    
    # Solicitar selección
    echo -n "Selecciona un usuario [1-$((counter-1))] o 'q' para salir: "
    read -r selection
    
    if [[ "$selection" == "q" ]] || [[ "$selection" == "Q" ]]; then
        info "Operación cancelada."
        return 0
    fi
    
    # Validar selección
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -ge "$counter" ]]; then
        error "Selección inválida."
        return 1
    fi
    
    # Obtener datos del usuario seleccionado
    local selected_user="${user_ids[$((selection-1))]}"
    IFS='|' read -r sel_id sel_name sel_email <<< "$selected_user"
    
    # Cambiar configuración global de Git
    git config --global user.name "$sel_name"
    git config --global user.email "$sel_email"
    
    echo ""
    success "Usuario cambiado exitosamente:"
    echo -e "  👤 Nombre: ${GREEN}$sel_name${NC}"
    echo -e "  📧 Email:  ${GREEN}$sel_email${NC}"
    
    # Preguntar si aplicar también localmente si estamos en un repo
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        echo ""
        echo -n "¿Aplicar también al repositorio actual? [y/N]: "
        read -r apply_local
        
        if [[ "$apply_local" =~ ^[Yy]$ ]]; then
            git config --local user.name "$sel_name"
            git config --local user.email "$sel_email"
            success "Configuración local también actualizada."
        fi
    fi
    
    echo ""
}

# Función 3: Agregar nuevo usuario
add_user() {
    header
    echo -e "${CYAN}➕ AGREGAR NUEVO USUARIO${NC}"
    echo ""
    
    # Solicitar ID del usuario
    echo -n "🆔 ID del usuario (ej: personal, trabajo, freelance): "
    read -r user_id
    
    if [[ -z "$user_id" ]]; then
        error "El ID no puede estar vacío."
        return 1
    fi
    
    # Verificar si el ID ya existe
    local existing_users=$(get_users)
    if echo "$existing_users" | cut -d'|' -f1 | grep -q "^$user_id$"; then
        error "El ID '$user_id' ya existe."
        return 1
    fi
    
    # Solicitar nombre
    echo -n "👤 Nombre completo: "
    read -r user_name
    
    if [[ -z "$user_name" ]]; then
        error "El nombre no puede estar vacío."
        return 1
    fi
    
    # Solicitar email
    echo -n "📧 Email: "
    read -r user_email
    
    if [[ -z "$user_email" ]]; then
        error "El email no puede estar vacío."
        return 1
    fi
    
    # Validación básica de email
    if ! echo "$user_email" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
        warning "El formato del email parece incorrecto, pero continuando..."
    fi
    
    # Mostrar resumen
    echo ""
    echo -e "${GREEN}📋 Resumen del nuevo usuario:${NC}"
    echo -e "  🆔 ID: $user_id"
    echo -e "  👤 Nombre: $user_name"
    echo -e "  📧 Email: $user_email"
    echo ""
    
    echo -n "¿Confirmar? [Y/n]: "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        info "Operación cancelada."
        return 0
    fi
    
    # Agregar usuario al archivo JSON
    if command -v jq >/dev/null 2>&1; then
        # Usando jq
        jq --arg id "$user_id" --arg name "$user_name" --arg email "$user_email" \
           '.users += [{"id": $id, "name": $name, "email": $email}]' \
           "$USERS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$USERS_FILE"
    else
        # Fallback sin jq - método manual
        # Leer el archivo actual, quitar la última llave y agregar el nuevo usuario
        head -n -1 "$USERS_FILE" > "$TEMP_FILE"
        
        # Si ya hay usuarios, agregar coma
        if grep -q '"id"' "$USERS_FILE"; then
            echo '    ,' >> "$TEMP_FILE"
        fi
        
        # Agregar nuevo usuario
        cat >> "$TEMP_FILE" << EOF
    {
      "id": "$user_id",
      "name": "$user_name",
      "email": "$user_email"
    }
  ]
}
EOF
        
        mv "$TEMP_FILE" "$USERS_FILE"
    fi
    
    success "Usuario '$user_id' agregado exitosamente."
    
    # Preguntar si cambiar a este usuario
    echo ""
    echo -n "¿Cambiar a este usuario ahora? [Y/n]: "
    read -r switch_now
    
    if [[ ! "$switch_now" =~ ^[Nn]$ ]]; then
        git config --global user.name "$user_name"
        git config --global user.email "$user_email"
        success "Usuario activo cambiado a '$user_id'."
    fi
    
    echo ""
}

# Función para listar usuarios guardados
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
    while IFS='|' read -r id name email; do
        if [[ -n "$id" ]]; then
            echo -e "${YELLOW}[$counter] $id${NC}"
            echo -e "   👤 $name"
            echo -e "   📧 $email"
            echo ""
            ((counter++))
        fi
    done <<< "$users_data"
}

# Función para mostrar ayuda
show_help() {
    header
    echo -e "${CYAN}📖 AYUDA${NC}"
    echo ""
    echo "Uso: $0 [opción]"
    echo ""
    echo "Opciones disponibles:"
    echo -e "  ${GREEN}actual${NC}     Mostrar usuario actual de Git"
    echo -e "  ${GREEN}cambiar${NC}    Cambiar entre usuarios guardados"
    echo -e "  ${GREEN}agregar${NC}    Agregar nuevo usuario"
    echo -e "  ${GREEN}listar${NC}     Listar todos los usuarios guardados"
    echo -e "  ${GREEN}ayuda${NC}      Mostrar esta ayuda"
    echo ""
    echo "Si se ejecuta sin parámetros, mostrará un menú interactivo."
    echo ""
    echo -e "${YELLOW}Ejemplos:${NC}"
    echo "  $0 actual         # Ver usuario actual"
    echo "  $0 cambiar        # Cambiar usuario"
    echo "  $0 agregar        # Agregar usuario nuevo"
    echo ""
}

# Menú interactivo
show_menu() {
    while true; do
        header
        echo -e "${CYAN}🔧 MENÚ PRINCIPAL${NC}"
        echo ""
        echo -e "${GREEN}[1]${NC} 👁️  Ver usuario actual"
        echo -e "${GREEN}[2]${NC} 🔄 Cambiar usuario"
        echo -e "${GREEN}[3]${NC} ➕ Agregar nuevo usuario"
        echo -e "${GREEN}[4]${NC} 📋 Listar usuarios guardados"
        echo -e "${GREEN}[5]${NC} 📖 Ayuda"
        echo -e "${GREEN}[0]${NC} 🚪 Salir"
        echo ""
        echo -n "Selecciona una opción [0-5]: "
        read -r option
        
        case $option in
            1)
                show_current_user
                echo ""
                echo -n "Presiona Enter para continuar..."
                read -r
                ;;
            2)
                switch_user
                echo ""
                echo -n "Presiona Enter para continuar..."
                read -r
                ;;
            3)
                add_user
                echo ""
                echo -n "Presiona Enter para continuar..."
                read -r
                ;;
            4)
                list_users
                echo ""
                echo -n "Presiona Enter para continuar..."
                read -r
                ;;
            5)
                show_help
                echo ""
                echo -n "Presiona Enter para continuar..."
                read -r
                ;;
            0)
                echo ""
                info "¡Hasta luego! 👋"
                exit 0
                ;;
            *)
                echo ""
                error "Opción inválida. Intenta de nuevo."
                echo ""
                echo -n "Presiona Enter para continuar..."
                read -r
                ;;
        esac
    done
}

# Función principal
main() {
    # Verificar que Git esté instalado
    if ! command -v git >/dev/null 2>&1; then
        error "Git no está instalado en el sistema."
        exit 1
    fi
    
    # Inicializar archivo de usuarios
    init_users_file
    
    # Procesar argumentos
    case "${1:-}" in
        "actual"|"current"|"status")
            show_current_user
            ;;
        "cambiar"|"switch"|"change")
            switch_user
            ;;
        "agregar"|"add"|"nuevo")
            add_user
            ;;
        "listar"|"list"|"ls")
            list_users
            ;;
        "ayuda"|"help"|"-h"|"--help")
            show_help
            ;;
        "")
            # Sin argumentos, mostrar menú interactivo
            show_menu
            ;;
        *)
            error "Opción desconocida: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"
