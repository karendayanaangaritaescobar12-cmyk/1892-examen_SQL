USE coworking_db;
DELIMITER $$

DROP TABLE IF EXISTS ReservasExternas$$

CREATE TABLE ReservasExternas (
    id_reserva INT PRIMARY KEY AUTO_INCREMENT,
    plataforma VARCHAR(50) NOT NULL,
    fecha_reserva DATE NOT NULL,
    id_espacio INT NOT NULL,
    usuario_externo VARCHAR(100) NOT NULL,
    duracion INT NOT NULL,
    fecha_importacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado_importacion ENUM('pendiente', 'importada', 'error') NOT NULL DEFAULT 'pendiente',
    CONSTRAINT chk_duracion_externa CHECK (duracion > 0),
    CONSTRAINT fk_reservas_externas_espacio FOREIGN KEY (id_espacio)
        REFERENCES espacio(id_espacio)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci$$

DROP PROCEDURE IF EXISTS sp_importar_reserva_externa$$

CREATE PROCEDURE sp_importar_reserva_externa(
    IN p_plataforma VARCHAR(50),
    IN p_fecha_reserva DATE,
    IN p_id_espacio INT,
    IN p_usuario_externo VARCHAR(100),
    IN p_duracion INT
)
BEGIN
    DECLARE v_hora_inicio TIME DEFAULT '09:00:00';
    DECLARE v_hora_fin TIME;
    DECLARE v_id_usuario INT;
    DECLARE v_email VARCHAR(100);
    DECLARE v_conflicto INT DEFAULT 0;

    IF p_plataforma IS NULL OR TRIM(p_plataforma) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La plataforma no puede estar vacía';
    END IF;

    IF p_usuario_externo IS NULL OR TRIM(p_usuario_externo) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El usuario externo no puede estar vacío';
    END IF;

    IF p_duracion IS NULL OR p_duracion <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La duración debe ser mayor a 0';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM espacio WHERE id_espacio = p_id_espacio) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El espacio indicado no existe';
    END IF;

    SET v_hora_fin = ADDTIME(v_hora_inicio, SEC_TO_TIME(p_duracion * 3600));

    SELECT COUNT(*)
      INTO v_conflicto
      FROM reserva
     WHERE id_espacio = p_id_espacio
       AND fecha_reserva = p_fecha_reserva
       AND estado_reserva IN ('pendiente', 'confirmada')
       AND NOT (v_hora_fin <= hora_inicio OR v_hora_inicio >= hora_fin);

    IF v_conflicto > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya existe una reserva activa en ese horario para el espacio indicado';
    END IF;

    SET v_email = CONCAT(REPLACE(LOWER(TRIM(p_usuario_externo)), ' ', '_'), '@externo.com');

    SELECT id_usuario
      INTO v_id_usuario
      FROM usuario
     WHERE email = v_email
     LIMIT 1;

    IF v_id_usuario IS NULL THEN
        INSERT INTO usuario (
            tipo_documento,
            tipo_usuario,
            numero_documento,
            primer_nombre,
            primer_apellido,
            fecha_nacimiento,
            email,
            telefono,
            fecha_registro,
            id_empresa
        )
        VALUES (
            'CC',
            'comun',
            CONCAT('EXT-', UUID()),
            TRIM(SUBSTRING_INDEX(p_usuario_externo, ' ', 1)),
            COALESCE(TRIM(SUBSTRING_INDEX(p_usuario_externo, ' ', -1)), 'Externo'),
            DATE_SUB(CURDATE(), INTERVAL 25 YEAR),
            v_email,
            NULL,
            CURDATE(),
            NULL
        );

        SET v_id_usuario = LAST_INSERT_ID();
    END IF;

    INSERT INTO reserva (
        id_usuario,
        id_espacio,
        fecha_reserva,
        hora_inicio,
        hora_fin,
        numero_asistentes,
        estado_reserva
    )
    VALUES (
        v_id_usuario,
        p_id_espacio,
        p_fecha_reserva,
        v_hora_inicio,
        v_hora_fin,
        1,
        'confirmada'
    );

    INSERT INTO ReservasExternas (
        plataforma,
        fecha_reserva,
        id_espacio,
        usuario_externo,
        duracion,
        estado_importacion
    )
    VALUES (
        p_plataforma,
        p_fecha_reserva,
        p_id_espacio,
        p_usuario_externo,
        p_duracion,
        'importada'
    );

END$$

DELIMITER ;

-- Ejemplo de uso:
-- CALL sp_importar_reserva_externa('Airbnb', '2026-10-08', 1, 'Ana Gomez', 2);

-- -------------------------------------------------------------
-- BLOQUE DE PRUEBA - VALIDACIÓN DE LA INTEGRACIÓN
-- -------------------------------------------------------------

-- Datos mínimos necesarios para probar la importación
INSERT INTO empresa (razon_social, nit_ruc, email, telefono)
VALUES ('Coworking Central', '900123456-1', 'info@coworking.com', '3001234567')
ON DUPLICATE KEY UPDATE razon_social = VALUES(razon_social), email = VALUES(email);

INSERT INTO tipo_espacio (nombre, descripcion)
VALUES
    ('Sala de reuniones', 'Espacio para reuniones y trabajo en equipo'),
    ('Escritorio privado', 'Espacio individual con escritorio')
ON DUPLICATE KEY UPDATE descripcion = VALUES(descripcion);

INSERT INTO espacio (id_tipo_espacio, codigo_espacio, capacidad_maxima, precio_por_hora, estado_disponibilidad)
VALUES
    (1, 'SALA-01', 8, 35000, 'disponible'),
    (2, 'ESCR-01', 2, 25000, 'disponible')
ON DUPLICATE KEY UPDATE capacidad_maxima = VALUES(capacidad_maxima), precio_por_hora = VALUES(precio_por_hora);

-- Prueba 1: reserva externa válida
CALL sp_importar_reserva_externa('Airbnb', '2026-10-08', 1, 'Ana Gomez', 2);

-- Prueba 2: reserva externa válida en otro espacio
CALL sp_importar_reserva_externa('Booking', '2026-10-08', 2, 'Luis Perez', 3);

-- Prueba 3: conflicto de horario para el mismo espacio
-- Esta llamada debe generar error por solapamiento
-- CALL sp_importar_reserva_externa('Expedia', '2026-10-08', 1, 'Carlos Ruiz', 2);

-- Consultas de verificación
SELECT * FROM usuario;
SELECT * FROM reserva;
SELECT * FROM ReservasExternas;

