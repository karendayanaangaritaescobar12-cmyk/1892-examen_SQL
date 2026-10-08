# 1892 - Examen SQL

Proyecto de base de datos para la gestión de un coworking con integración de reservas externas procedentes de plataformas como Airbnb, Booking y otras fuentes externas.

## Objetivo

Desarrollar la estructura de una base de datos para un sistema de coworking y crear un procedimiento almacenado que permita importar reservas externas a la base de datos interna, validando condiciones como:

- existencia del espacio
- duración válida
- ausencia de conflictos de horario
- creación automática del usuario si no existe
- registro de la reserva externa en una tabla de auditoría/importación

## Archivos del proyecto

- `01_estructura.sql` : script con la creación de la base de datos y las tablas del sistema.
- `Integración de Datos Externos.SQL` : script con la tabla `ReservasExternas` y el procedimiento `sp_importar_reserva_externa`.
- `1892-examen.sql` : versión consolidada del ejercicio con ejemplos de prueba y verificación.

## Base de datos principal

La base de datos utilizada es:

```sql
coworking_db
```

Tiene entidades como:

- empresa
- usuario
- membresia
- tipo_membresia
- espacio
- tipo_espacio
- reserva
- servicio_adicional
- factura
- pago
- control_acceso
- auditoría

## Procedimiento implementado

Se creó el procedimiento:

```sql
sp_importar_reserva_externa
```

Este procedimiento recibe los siguientes parámetros:

- `p_plataforma`
- `p_fecha_reserva`
- `p_id_espacio`
- `p_usuario_externo`
- `p_duracion`

Y realiza lo siguiente:

1. valida que la plataforma y el usuario externo no estén vacíos
2. valida que la duración sea mayor a cero
3. valida que el espacio exista
4. verifica que no exista conflicto de horario en la misma fecha y espacio
5. crea el usuario interno si no existe
6. inserta la reserva en la tabla `reserva`
7. registra la información importada en `ReservasExternas`

## Ejemplo de uso

```sql
CALL sp_importar_reserva_externa('Airbnb', '2026-10-08', 1, 'Ana Gomez', 2);
```

## Validación incluida

El archivo final incluye una prueba de integración con:

- creación de datos mínimos
- dos importaciones exitosas
- ejemplo de conflicto de horario comentado
- consultas para revisar los resultados

## Requisitos

- MySQL 8.0 o superior
- ejecución previa del archivo `01_estructura.sql`
- luego ejecución del script de integración y pruebas

## Autor

Proyecto desarrollado como parte del examen de SQL.
