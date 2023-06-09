
# Tesis
# Script para construcción de variables

# Limpiar
remove(list = ls())

# Paquetes
library("haven")    # leer bases SPSS (.sav)
library("readxl")   # leer bases Excel (.xlsx)
library("dplyr")    # procesar datos
library("stringr")  # usar str_sub()


## Bases de datos ## -----------------------------------------------------------


# ENDES 2018
#  Cuestionario de hogares: 
RECH0   <- read_sav("E:/BD/ENDES/ENDES2018/Bases/Modulo64/RECH0.sav")
RECH1   <- read_sav("E:/BD/ENDES/ENDES2018/Bases/Modulo64/RECH1.sav")
RECH23  <- read_sav("E:/BD/ENDES/ENDES2018/Bases/Modulo65/RECH23.sav")
RECH4   <- read_sav("E:/BD/ENDES/ENDES2018/Bases/Modulo64/RECH4.sav")
PROGRA  <- read_sav("E:/BD/ENDES/ENDES2018/Bases/Modulo569/Programas Sociales x Hogar.sav")
RECH6   <- read_sav("E:/BD/ENDES/ENDES2018/Bases/Modulo74/RECH6.sav")
#  Cuestionario de mujeres: 
REC0111 <- read_sav("E:/BD/ENDES/ENDES2018/Bases/Modulo66/REC0111.sav")
REC91   <- read_sav("E:/BD/ENDES/ENDES2018/Bases/Modulo66/REC91.sav")


# Mapa de Pobreza Monetaria, INEI 2018
#  Archivo "Anexo Estadístico.xlsx"
#  https://www.gob.pe/institucion/inei/informes-publicaciones/3204872-mapa-de-pobreza-provincial-y-distrital-2018
nomcolumnas <- c("ubigeo", "agr", "distrito", "poblacionpro", "IC_inf", "IC_sup", "ubicacionpob")
mapapobreza <- read_xlsx(path = "E:/BD/MapaPobreza/MapaPobreza2018/Documentación/Anexo Estadístico.xlsx", 
                         sheet = "Anexo2", 
                         range = "A8:G2158", 
                         col_names = nomcolumnas)  
mapapobreza <- mapapobreza %>% 
  filter(!is.na(ubigeo)) %>% 
  filter(!is.na(ubicacionpob))


# Base de Datos de Pueblos Indígenas u Originarios, MINCUL, 2023
#  Archivo "BDPI - Centros poblados - 2022_0.xlsx"
#  https://bdpi.cultura.gob.pe/buscador-de-localidades-de-pueblos-indigenas
nomcolumnas <- c("N", "ubigeoCCPP", "nombreCCPP", "nrolocalidades", "nomlocalidades", "ambito", "puebloindigena", 
                 "departamento", "provincia", "distrito", "ubigeo", "region", "area", "tipoadm", "categoriaCCPP")
bdpi <- read_xlsx(path = "E:/BD/BDPI/BDPI2023.04.06/BDPI - Centros poblados - 2022_0.xlsx", 
                  sheet = "1. BDPI - CC.PP", 
                  range = "B8:P36436", 
                  col_names = nomcolumnas)


## Variables

## Variables de resultado y covariables del niño/niña ## -----------------------


# El punto de partida es RECH6 
base <- NULL
base <- RECH6 %>% 
  select(HHID, orden = HC0, orden_madreenc = HC60, HC1, HC27, HC70)


# Crear "edad" y "sexo"
base <- base %>% 
  mutate(edad = HC1) %>% 
  mutate(sexo = case_when(HC27 == 1 ~ 0, HC27 == 2 ~ 1)) 


# Crear "tallaedad" (puntaje Z de talla según edad)
base <- base %>% 
  mutate(tallaedad = case_when(
    HC70 %in% c(9996,9997,9998) ~ NA_real_,
    HC70 > -600 & HC70 < 600    ~ as.numeric(HC70), 
    is.na(HC70)                 ~ NA_real_ ))


# Crear "desnutricion" (desnutrición crónica)
base <- base %>%  
  mutate(desnutricion = case_when(
    HC70 %in% c(9996,9997,9998) ~ NA_real_,
    HC70 <  -200                ~ 1,
    HC70 >= -200                ~ 0,
    is.na(HC70)                 ~ NA_real_ )) 


# Crear "desnutricionext" (desnutrición crónica extrema)
base <- base %>% 
  mutate(desnutricionext = case_when(
    HC70 %in% c(9996,9997,9998) ~ NA_real_,
    HC70 <  -300                ~ 1,
    HC70 >= -300                ~ 0,
    is.na(HC70)                 ~ NA_real_ )) 


## Variables de tratamiento ## -------------------------------------------------


# Crear "tratamiento"
temp <- PROGRA %>%
  mutate(tratamiento = case_when(
    QH95 == 1   ~ 1,
    QH95 == 2   ~ 0,
    QH95 == 8   ~ NA_real_,
    is.na(QH95) ~ NA_real_)) %>% 
  select(HHID, QH95, tratamiento)
base <- base %>% left_join(temp, by = "HHID") 


# Crear "tiempotra_hogar" (tiempo de tratamiento del hogar)
temp <- PROGRA %>% 
  mutate(tiempotra_hogar = case_when(
    QH96A <= 19 & QH96M <= 12   ~ QH96A*12 + QH96M, 
    QH96A <= 19 & QH96M == 98   ~ QH96A*12, 
    QH96A == 98                 ~ NA_real_,
    is.na(QH96A) | is.na(QH96M) ~ NA_real_)) %>% 
  select(HHID, QH96A, QH96M, tiempotra_hogar)
base <- base %>% left_join(temp, by = "HHID")


# Crear "tiempotra" (tiempo de tratamiento del niño/a)
base <- base %>%  
  mutate(tiempotra = case_when(
    edad >  tiempotra_hogar ~ tiempotra_hogar,
    edad <= tiempotra_hogar ~ edad)) 


## Covariables de la madre o del padre ## --------------------------------------


# Previo: crear "id_madre" y "id_padre"
temp <- RECH1 %>% 
  mutate(orden_madre = case_when(
    HV111 == 1 & HV112 != 0 ~ HV112, 
    TRUE                    ~ NA_real_)) %>% 
  mutate(orden_padre = case_when(
    HV113 == 1 & HV114 != 0 ~ HV114, 
    TRUE                    ~ NA_real_)) %>% 
  select(HHID, orden_miembro = HVIDX, HV111, HV112, orden_madre, HV113, HV114, orden_padre)
base <- base %>% 
  left_join(temp, by = c("HHID","orden"="orden_miembro")) 


# Crear "edad_madre"
# según Cuestionario de Mujeres
temp <- REC0111 %>% 
  mutate(orden_mujer = as.numeric(str_sub(CASEID, -2, -1))) %>% 
  select(HHID, orden_mujer, V015, V012) 
base <- base %>% 
  left_join(temp, by = c("HHID","orden_madreenc"="orden_mujer")) 
# según Cuestionario de Hogares
temp <- RECH1 %>% 
  select(HHID, orden_miembro=HVIDX, HV105) 
base <- base %>%  
  left_join(temp, by = c("HHID", "orden_madre"="orden_miembro")) 
# crear
base <- base %>% mutate(edad_madre = case_when(
  orden_madreenc %in% c(1:15)        ~ V012, 
  orden_madreenc %in% c(993,994,995) ~ as.numeric(HV105)))


# Crear "idioma_madre"
temp <- REC91 %>% 
  mutate(HHID = str_sub(CASEID, 1, 15), 
         orden_mujer = as.numeric(str_sub(CASEID, 17, 18))) %>% 
  mutate(idioma_madre = case_when(
    S119 %in% c(1,2,3,4,5,6,7,8,9) ~ 1, 
    S119 %in% c(10,11,12)          ~ 0, 
    is.na(S119)                    ~ NA_real_)) %>% 
  select(HHID, orden_mujer, S119, idioma_madre) 
base <- base %>% 
  left_join(temp, by = c("HHID", "orden_madreenc"="orden_mujer")) 


# Crear "educacion_madre" y "educacion_padre":
# según Cuestionario de Mujeres
temp <- REC91 %>% 
  mutate(HHID = str_sub(CASEID, 1, 15), 
         orden_mujer = as.numeric(str_sub(CASEID, 17, 18))) %>% 
  mutate(educacion_mujer = case_when(
    S108N == 0                               ~ 0, 
    S108N == 1 & S108Y %in% c(0,1,2,3,4,5,6) ~ as.numeric(S108Y), 
    S108N == 1 & S108Y == 7                  ~ S108G, 
    S108N == 2                               ~ 6 + S108Y, 
    S108N == 3                               ~ 6 + 5 + S108Y, 
    S108N == 4                               ~ 6 + 5 + S108Y, 
    S108N == 5                               ~ 6 + 5 + 5 + S108Y, 
    is.na(S108N)                             ~ NA_real_)) %>% 
  select(HHID, orden_mujer, S108N, S108Y, S108G, educacion_mujer) 
base <- base %>% 
  left_join(temp, by = c("HHID", "orden_madreenc"="orden_mujer")) 
# según Cuestionario de Hogares  
temp <- RECH1 %>% 
  mutate(educacion_miembro = case_when(
    HV108 >= 0 & HV108 <= 20 ~ as.numeric(HV108),
    HV108 == 98              ~ NA_real_, 
    is.na(HV108)             ~ NA_real_)) %>% 
  select(HHID, orden_miembro=HVIDX, HV108, educacion_miembro)
base <- base %>%
  left_join(temp, by = c("HHID", "orden_madre"="orden_miembro")) 
# crear
base <- base %>% mutate(educacion_madre = case_when(
  orden_madreenc %in% c(1:15)        ~ educacion_mujer, 
  orden_madreenc %in% c(993,994,995) ~ educacion_miembro))
# crear
base <- base %>% 
  left_join(temp, by = c("HHID", "orden_padre"="orden_miembro"), suffix = c("_madre","_padre")) %>% 
  mutate(educacion_padre = educacion_miembro_padre)


# Crear "seguropri":
temp <- RECH4 %>% 
  mutate(seguropri_miembro = case_when(
    SH11D == 1 | SH11E == 1 ~ 1,
    SH11Y == 1              ~ NA_real_,
    TRUE                    ~ 0)) %>% 
  select(HHID, orden_miembro=IDXH4, SH11D, SH11E, SH11Y, seguropri_miembro) 
base <- base %>% 
  left_join(temp, by = c("HHID", "orden_madre"="orden_miembro")) %>% 
  rename(seguropri_madre = seguropri_miembro)
base <- base %>% 
  left_join(temp, by = c("HHID", "orden_padre"="orden_miembro"), suffix = c("_madre", "_padre")) %>% 
  rename(seguropri_padre = seguropri_miembro)
base <- base %>% 
  mutate(seguropri = case_when(
    seguropri_madre == 1   | seguropri_padre == 1   ~ 1,
    is.na(seguropri_madre) & is.na(seguropri_padre) ~ NA_real_, 
    TRUE                                            ~ 0)) 


## Covariables del hogar ## ----------------------------------------------------


# Crear "hacinamiento"
temp <- RECH1 %>% 
  group_by(HHID) %>% 
  summarise(nromiembros = n()) %>% 
  left_join(RECH23 %>% select(HHID, HV216), by = "HHID") %>% 
  mutate(hacinamiento = HV216/nromiembros)
base <- base %>% left_join(temp, by = "HHID") 


# Crear "maxeducacion_miembro"
temp <- RECH1 %>% 
  mutate(educacion_miembro = case_when(
    HV108 >= 0 & HV108 <= 20 ~ as.numeric(HV108),
    HV108 == 98              ~ NA_real_, 
    is.na(HV108)             ~ NA_real_)) %>% 
  filter(HV105 >= 17) %>% 
  group_by(HHID) %>% 
  summarise(maxeducacion_miembro = max(educacion_miembro, na.rm=TRUE)) 
base <- base %>% left_join(temp, by = "HHID") 


# Crear "vehiculos"
base <- base %>% 
  left_join(RECH23 %>% select(HHID, vehiculos = HV212), by = "HHID") 


# Crear "combustibles"
temp <- RECH23 %>% 
  mutate(combustibles = case_when(
    HV226 %in% c(1,2,3,4,5)           ~ 1,
    HV226 %in% c(6,7,8,9,10,11,95,96) ~ 0, 
    is.na(HV226)                      ~ NA_real_)) %>% 
  select(HHID, HV226, combustibles) 
base <- base %>% left_join(temp, by = "HHID") 


# Crear "bienes"
temp <- RECH23 %>% 
  mutate(bienes = SH61K + HV209 + HV221 + SH61O + SH61P + SH61Q + SH61J) %>% 
  select(HHID, SH61K, HV209, HV221, SH61O, SH61P, SH61Q, SH61J, bienes) 
base <- base %>% left_join(temp, by = "HHID")


# Crear "agua", "desague" y "electricidad"
temp <- RECH23 %>% 
  mutate(agua = case_when(
    HV201 == 11                                 ~ 1,
    HV201 %in% c(12,13,21,22,41,43,51,61,71,96) ~ 0,
    HV201 == NA                                 ~ NA_real_)) %>% 
  mutate(desague = case_when(
    HV205 == 11                           ~ 1,
    HV205 %in% c(12,21,22,23,24,31,32,96) ~ 0,
    HV205 == NA                           ~ NA_real_)) %>% 
  mutate(electricidad = HV206) %>% 
  mutate(servicios = agua + desague + electricidad) %>% 
  select(HHID, HV201, agua, HV205, desague, HV206, SH70, electricidad, servicios)
base <- base %>% left_join(temp, by = "HHID")


# Crear "pisos", "paredes" y "techos"
temp <- RECH23 %>%
  mutate(pisos = case_when(
    HV213 %in% c(31,32,33,34) ~ 1,
    HV213 %in% c(11,21,96)    ~ 0,
    is.na(HV213)              ~ NA_real_)) %>% 
  mutate(paredes = case_when(
    HV214 == 31                                    ~ 1,
    HV214 %in% c(11,12,13,21,22,23,24,32,33,41,96) ~ 0,
    is.na(HV214)                                   ~ NA_real_)) %>% 
  mutate(techos = case_when(
    HV215 == 31                              ~ 1,
    HV215 %in% c(11,12,21,22,32,33,34,41,96) ~ 0, 
    is.na(HV215)                             ~ NA_real_)) %>% 
  mutate(materiales = pisos + paredes + techos) %>% 
  select(HHID, HV213, pisos, HV214, paredes, HV215, techos, materiales)
base <- base %>% left_join(temp, by = "HHID") 


# Crear "area" y "lugar"
temp <- RECH0 %>% 
  mutate(area = case_when(
    HV025 == 1 ~ 1, 
    HV025 == 2 ~ 0)) %>%
  mutate(lugar = case_when(
    HV026 == 0 ~ 3, 
    HV026 == 1 ~ 2,
    HV026 == 2 ~ 1,
    HV026 == 3 ~ 0)) %>%
  select(HHID, HV025, area, HV026, lugar)
base <- base %>% left_join(temp, by = "HHID")


## Covariables del distrito ## -------------------------------------------------


# Previo: 
# Crear "ubigeo" y corregir el ubigeo y CODCCPP de los hogares con ubigeo = 120699 (un ubigeo que 
#  agrupó a los actuales distritos de Pangoa, Mazamari y Vizcatán del Ene): 
base <- base %>% 
  left_join(RECH0 %>% select(HHID, ubigeo, region = HV024, CODCCPP, NOMCCPP), by = "HHID") %>% 
  mutate(CODCCPP = case_when(
    ubigeo == "120699" & NOMCCPP == "MAZAMARI"                   ~ "0001",
    ubigeo == "120699" & NOMCCPP == "SAN MARTIN DE PANGOA"       ~ "0001",
    ubigeo == "120699" & NOMCCPP == "NUEVA JERUSALEN"            ~ NA_character_,
    ubigeo == "120699" & NOMCCPP == "UNION ALTO SANIBENI"        ~ "0254",
    ubigeo == "120699" & NOMCCPP == "CANAAN"                     ~ "0038",
    ubigeo == "120699" & NOMCCPP == "SANTA ROSA DE ALTO KIATARI" ~ "0051",
    ubigeo == "120699" & NOMCCPP == "SHAORIATO"                  ~ "0091",
    ubigeo == "120699" & NOMCCPP == "TUNUNTUARI"                 ~ "0005",
    ubigeo == "120699" & NOMCCPP == "ALTO TUNUNTUARI AMAZONAS"   ~ "0006",
    ubigeo == "120699" & NOMCCPP == "CERRO VERDE"                ~ "0012",
    ubigeo == "120699" & NOMCCPP == "NUEVA UNION"                ~ NA_character_,
    ubigeo == "120699" & NOMCCPP == "LIBERTAD DE MAZANGARO"      ~ NA_character_,
    ubigeo == "120699" & NOMCCPP == "SEÑOR DE LOS MILAGROS"      ~ "0145",
    TRUE                                                         ~ CODCCPP)) %>% 
  mutate(ubigeo = case_when(
    ubigeo == "120699" & NOMCCPP == "MAZAMARI"                   ~ "120604",
    ubigeo == "120699" & NOMCCPP == "SAN MARTIN DE PANGOA"       ~ "120606",
    ubigeo == "120699" & NOMCCPP == "NUEVA JERUSALEN"            ~ NA_character_,
    ubigeo == "120699" & NOMCCPP == "UNION ALTO SANIBENI"        ~ "120606",
    ubigeo == "120699" & NOMCCPP == "CANAAN"                     ~ "120606",
    ubigeo == "120699" & NOMCCPP == "SANTA ROSA DE ALTO KIATARI" ~ "120606",
    ubigeo == "120699" & NOMCCPP == "SHAORIATO"                  ~ "120606",
    ubigeo == "120699" & NOMCCPP == "TUNUNTUARI"                 ~ "120609",
    ubigeo == "120699" & NOMCCPP == "ALTO TUNUNTUARI AMAZONAS"   ~ "120609",
    ubigeo == "120699" & NOMCCPP == "CERRO VERDE"                ~ "120609",
    ubigeo == "120699" & NOMCCPP == "NUEVA UNION"                ~ "120609",
    ubigeo == "120699" & NOMCCPP == "LIBERTAD DE MAZANGARO"      ~ "120609",
    ubigeo == "120699" & NOMCCPP == "SEÑOR DE LOS MILAGROS"      ~ "120604",
    TRUE                                                         ~ ubigeo)) 
# Crear "ubigeoCCPP" (ubigeo del centro poblado)
base <- base %>% 
  mutate(ubigeoCCPP = case_when(
    !is.na(ubigeo) & !is.na(CODCCPP) ~ paste(ubigeo, CODCCPP, sep = ""),
    TRUE                             ~ NA_character_)) 


# Crear "pobreza"
temp <- mapapobreza %>% 
  mutate(pobreza = (IC_inf+IC_sup)/2) %>% 
  select(ubigeo, distrito, IC_inf, IC_sup, pobreza)
base <- base %>% left_join(temp, by = "ubigeo") 


# Crear "puebloamazonico"
base <- base %>% 
  left_join(bdpi %>% select(ubigeoCCPP, nombreCCPP, ambito, puebloindigena), by = "ubigeoCCPP") %>% 
  mutate(puebloamazonico = case_when(
    !is.na(CODCCPP) & ambito %in% c("Amazónico", "Amazónico / Andino") ~ 1,
    !is.na(CODCCPP) & ambito == "Andino"                               ~ 0,
    !is.na(CODCCPP) & is.na(ambito)                                    ~ 0,
    is.na(CODCCPP)                                                     ~ NA_real_))


# Crear "altitud"
base <- base %>% 
  left_join(RECH0 %>% select(HHID, altitud = HV040), by = "HHID") 


save(base, file = "D:/OneDrive/TesisUNMSM/CodigoTesis/3_Resultados/base.RData")
remove(temp,nomcolumnas)
