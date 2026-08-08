CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE barberias (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    slug VARCHAR(80) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    direccion VARCHAR(250),
    instagram VARCHAR(120),
    url_google_maps VARCHAR(1000),
    mostrar_ubicacion BOOLEAN NOT NULL DEFAULT FALSE,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    intervalo_minutos INTEGER NOT NULL DEFAULT 30,
    dias_antelacion_reserva INTEGER NOT NULL DEFAULT 30,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_barberia_slug CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_barberia_intervalo CHECK (intervalo_minutos BETWEEN 5 AND 180),
    CONSTRAINT ck_barberia_antelacion CHECK (dias_antelacion_reserva BETWEEN 1 AND 365)
);

CREATE TABLE profesionales (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    nombre VARCHAR(100) NOT NULL,
    alias VARCHAR(80),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_profesional_alias_barberia UNIQUE (barberia_id, alias),
    CONSTRAINT uq_profesional_id_barberia UNIQUE (id, barberia_id)
);

CREATE TABLE servicios (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    nombre VARCHAR(120) NOT NULL,
    descripcion VARCHAR(600),
    precio NUMERIC(10,2) NOT NULL,
    duracion_minutos INTEGER NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_servicio_nombre_barberia UNIQUE (barberia_id, nombre),
    CONSTRAINT uq_servicio_id_barberia UNIQUE (id, barberia_id),
    CONSTRAINT ck_servicio_precio CHECK (precio >= 0),
    CONSTRAINT ck_servicio_duracion CHECK (duracion_minutos > 0)
);

CREATE TABLE horarios_trabajo (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    profesional_id BIGINT NOT NULL,
    dia_semana VARCHAR(12) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_horario_profesional_barberia FOREIGN KEY (profesional_id, barberia_id) REFERENCES profesionales(id, barberia_id),
    CONSTRAINT ck_horario_dia CHECK (dia_semana IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY')),
    CONSTRAINT ck_horario_orden CHECK (hora_fin > hora_inicio),
    CONSTRAINT ux_horario_tramo UNIQUE (barberia_id, profesional_id, dia_semana, hora_inicio, hora_fin)
);

CREATE TABLE dias_bloqueados (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    profesional_id BIGINT NOT NULL,
    fecha DATE NOT NULL,
    hora_inicio TIME,
    hora_fin TIME,
    motivo VARCHAR(250),
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bloqueo_profesional_barberia FOREIGN KEY (profesional_id, barberia_id) REFERENCES profesionales(id, barberia_id),
    CONSTRAINT ck_bloqueo_franja CHECK ((hora_inicio IS NULL AND hora_fin IS NULL) OR (hora_inicio IS NOT NULL AND hora_fin > hora_inicio))
);

CREATE TABLE dias_trabajo_especial (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    profesional_id BIGINT NOT NULL REFERENCES profesionales(id),
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_trabajo_especial_orden CHECK (hora_fin > hora_inicio)
);

CREATE TABLE citas (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    profesional_id BIGINT NOT NULL,
    servicio_id BIGINT NOT NULL,
    nombre_cliente VARCHAR(100) NOT NULL,
    telefono_cliente VARCHAR(20) NOT NULL,
    fecha_inicio TIMESTAMP NOT NULL,
    fecha_fin TIMESTAMP NOT NULL,
    nota_cliente VARCHAR(1000),
    codigo_cancelacion_hmac VARCHAR(64),
    estado VARCHAR(30) NOT NULL,
    cancelada_por VARCHAR(12),
    motivo_cancelacion VARCHAR(500),
    fecha_cancelacion TIMESTAMP,
    nombre_servicio_reservado VARCHAR(120) NOT NULL,
    precio_servicio_reservado NUMERIC(10,2) NOT NULL,
    duracion_servicio_minutos_reservada INTEGER NOT NULL,
    clave_idempotencia VARCHAR(100) NOT NULL,
    huella_solicitud VARCHAR(64) NOT NULL,
    anonimizada BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_cita_idempotencia_barberia UNIQUE (barberia_id, clave_idempotencia),
    CONSTRAINT uq_cita_id_barberia UNIQUE (id, barberia_id),
    CONSTRAINT fk_cita_profesional_barberia FOREIGN KEY (profesional_id, barberia_id) REFERENCES profesionales(id, barberia_id),
    CONSTRAINT fk_cita_servicio_barberia FOREIGN KEY (servicio_id, barberia_id) REFERENCES servicios(id, barberia_id),
    CONSTRAINT ck_cita_fechas CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT ck_cita_estado CHECK (estado IN ('RESERVADA','CONFIRMADA','COMPLETADA','CANCELADA_POR_CLIENTE','CANCELADA_POR_BARBERIA','NO_PRESENTADO')),
    CONSTRAINT ck_cita_cancelada_por CHECK (cancelada_por IS NULL OR cancelada_por IN ('CLIENTE','BARBERIA'))
);

ALTER TABLE citas ADD CONSTRAINT citas_profesional_sin_solapamiento
    EXCLUDE USING gist (profesional_id WITH =, tsrange(fecha_inicio, fecha_fin, '[)') WITH &&)
    WHERE (estado IN ('RESERVADA','CONFIRMADA'));

CREATE TABLE usuarios_administracion (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    profesional_id BIGINT,
    nombre_usuario VARCHAR(80) NOT NULL UNIQUE,
    contrasena_hash VARCHAR(100) NOT NULL,
    rol VARCHAR(20) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    intentos_fallidos INTEGER NOT NULL DEFAULT 0,
    fecha_bloqueo TIMESTAMP,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_usuario_id_barberia UNIQUE (id, barberia_id),
    CONSTRAINT fk_usuario_profesional_barberia FOREIGN KEY (profesional_id, barberia_id) REFERENCES profesionales(id, barberia_id),
    CONSTRAINT ck_usuario_rol CHECK (rol IN ('PROPIETARIO','BARBERO'))
);

CREATE UNIQUE INDEX ux_usuario_profesional ON usuarios_administracion(profesional_id) WHERE profesional_id IS NOT NULL;

CREATE TABLE notificaciones (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    profesional_id BIGINT,
    cita_id BIGINT,
    tipo VARCHAR(30) NOT NULL,
    titulo VARCHAR(150) NOT NULL,
    mensaje VARCHAR(1000) NOT NULL,
    leida BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_lectura TIMESTAMP,
    CONSTRAINT fk_notificacion_profesional_barberia FOREIGN KEY (profesional_id, barberia_id) REFERENCES profesionales(id, barberia_id),
    CONSTRAINT fk_notificacion_cita_barberia FOREIGN KEY (cita_id, barberia_id) REFERENCES citas(id, barberia_id),
    CONSTRAINT ck_notificacion_tipo CHECK (tipo IN ('CITA_CANCELADA','CITA_CREADA','SISTEMA'))
);

CREATE TABLE intentos_cancelacion (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    huella_origen VARCHAR(64) NOT NULL,
    fecha_intento TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    exitoso BOOLEAN NOT NULL
);

CREATE TABLE intentos_reserva (
    id BIGSERIAL PRIMARY KEY,
    barberia_id BIGINT NOT NULL REFERENCES barberias(id),
    huella_origen VARCHAR(64) NOT NULL,
    fecha_intento TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_profesionales_barberia ON profesionales(barberia_id, activo);
CREATE INDEX idx_servicios_barberia ON servicios(barberia_id, activo);
CREATE INDEX idx_horarios_busqueda ON horarios_trabajo(barberia_id, profesional_id, dia_semana, activo);
CREATE INDEX idx_dias_bloqueados_busqueda ON dias_bloqueados(barberia_id, profesional_id, fecha);
CREATE INDEX ix_trabajo_especial_fecha ON dias_trabajo_especial(barberia_id, profesional_id, fecha);
CREATE INDEX idx_citas_barberia_fecha ON citas(barberia_id, fecha_inicio);
CREATE INDEX idx_citas_profesional_fecha ON citas(profesional_id, fecha_inicio);
CREATE INDEX idx_citas_telefono ON citas(barberia_id, telefono_cliente) WHERE anonimizada = FALSE;
CREATE INDEX idx_notificaciones_no_leidas ON notificaciones(barberia_id, leida, fecha_creacion DESC);
CREATE INDEX idx_intento_cancelacion_busqueda ON intentos_cancelacion(barberia_id, huella_origen, fecha_intento);
CREATE INDEX idx_intento_reserva_busqueda ON intentos_reserva(barberia_id, huella_origen, fecha_intento);
