-- CASO 1

-- Creación de usuarios con cuotas y tablespace
CREATE USER PRY2205_USER1 IDENTIFIED BY Cesfam5651a123654 
    DEFAULT TABLESPACE users 
    QUOTA 10M ON users;
GRANT CREATE SESSION TO PRY2205_USER1;

CREATE USER PRY2205_USER2 IDENTIFIED BY Cesfam5651a123654 
    DEFAULT TABLESPACE users 
    QUOTA 10M ON users;
GRANT CREATE SESSION TO PRY2205_USER2;

-- Creación de roles
CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_P;

-- Asignaciones de roles a los usuarios
GRANT PRY2205_ROL_D TO PRY2205_USER2;
GRANT PRY2205_ROL_P TO PRY2205_USER1;

-- Crear sinónimos públicos
CREATE PUBLIC SYNONYM PACIENTE3 FOR ADMIN.PACIENTES;
SELECT * FROM PACIENTE3;

-- Privilegios para PRY2205_USER1
GRANT CREATE TABLE, CREATE VIEW, CREATE SYNONYM TO PRY2205_USER1;

-- Privilegios para PRY2205_USER2
GRANT CREATE VIEW TO PRY2205_USER2;
GRANT SELECT ON ADMIN.PACIENTES TO PRY2205_USER2;
GRANT SELECT ON ADMIN.BONO_CONSULTA TO PRY2205_USER2;
GRANT SELECT ON ADMIN.SALUD TO PRY2205_USER2;

-- Otorgar permisos de selección mediante el rol PRY2205_ROL_D
GRANT SELECT ON PRY2205_USER1.MEDICO TO PRY2205_ROL_D;
GRANT SELECT ON PRY2205_USER1.CARGO TO PRY2205_ROL_D;

-- Privilegios del rol PARA PRY2205_ROL_P
GRANT CREATE PROCEDURE TO PRY2205_USER1;
GRANT CREATE FUNCTION TO PRY2205_USER1;

-- Crear sinónimos privados (solo accesibles para el usuario PRY2205_USER2)
CREATE SYNONYM PRY2205_USER2.PAGOS_PRIV FOR PRY2205_USER1.PAGOS;
CREATE SYNONYM PRY2205_USER2.PACIENTE_PRIV FOR PRY2205_USER1.PACIENTES;

-- Crear un índice en la columna id_cliente para optimizar las búsquedas por id_cliente
CREATE INDEX idx_id_cliente ON clientes(id_cliente);

-- Crear un índice en la columna nombre_cliente para optimizar las búsquedas por nombre_cliente
CREATE INDEX idx_nombre_cliente ON clientes(nombre_cliente);

-- Crear un índice compuesto para las columnas id_cliente y nombre_cliente
CREATE INDEX idx_cliente_compuesto ON clientes(id_cliente, nombre_cliente);

------ CASO 2 ------

-- Vista de recalculo de pagos
CREATE OR REPLACE VIEW PRY2205_USER2.V_RECALCULO_PAGOS AS
SELECT 
    -- RUN y dígito verificador
    PACIENTE.PAC_RUN AS PAC_RUN,
    PACIENTE.DV_RUN AS DV_RUN,
    -- Sistema de salud
    SALUD.DESCRIPCION AS SIST_SALUD,
    -- Nombre completo (Apellido Paterno, Apellido Materno, Nombres)
    PACIENTE.APATERNO || ' ' || PACIENTE.AMATERNO || ' ' || PACIENTE.PNOMBRE AS NOMBRE_PACIENTE,
    -- Costo del bono
    BONO_CONSULTA.COSTO AS COSTO,
    -- Calcular el monto ajustado y redondear a un número entero
    ROUND(
        CASE 
            -- Si la consulta fue después de las 17:15 y el costo está entre 15,000 y 25,000
            WHEN TO_NUMBER(SUBSTR(BONO_CONSULTA.HR_CONSULTA, 1, 2)) * 60 + TO_NUMBER(SUBSTR(BONO_CONSULTA.HR_CONSULTA, 4, 2)) > 1035 
                 AND BONO_CONSULTA.COSTO BETWEEN 15000 AND 25000 THEN BONO_CONSULTA.COSTO * 1.15
            -- Si la consulta fue después de las 17:15 y el costo es mayor a 25,000
            WHEN TO_NUMBER(SUBSTR(BONO_CONSULTA.HR_CONSULTA, 1, 2)) * 60 + TO_NUMBER(SUBSTR(BONO_CONSULTA.HR_CONSULTA, 4, 2)) > 1035 
                 AND BONO_CONSULTA.COSTO > 25000 THEN BONO_CONSULTA.COSTO * 1.20
            -- Si no se cumple ninguna de las condiciones anteriores, se deja el costo original
            ELSE BONO_CONSULTA.COSTO
        END
    ) AS MONTO_A_CANCELAR,
    -- Calcular edad del paciente
    FLOOR(MONTHS_BETWEEN(SYSDATE, PACIENTE.FECHA_NACIMIENTO) / 12) AS EDAD
FROM 
    PACIENTE
INNER JOIN 
    BONO_CONSULTA ON PACIENTE.PAC_RUN = BONO_CONSULTA.PAC_RUN
INNER JOIN 
    SALUD ON PACIENTE.SAL_ID = SALUD.SAL_ID
ORDER BY 
    PACIENTE.PAC_RUN, MONTO_A_CANCELAR ASC;

------ CASO 3 ------

-- Vista para aumentar el sueldo del médico
CREATE OR REPLACE VIEW PRY2205_USER1.VISTA_AUM_MEDICO_X_CARGO AS
SELECT 
    TO_CHAR(medico.rut_med, '999G999G999') || '-' || medico.dv_run AS RUT_MEDICO,
    cargo.nombre AS CARGO,
    TO_CHAR(medico.sueldo_base) AS SUELDO_BASE,
    TO_CHAR(medico.sueldo_base * 1.15, '999G999G999') AS SUELDO_AUMENTADO
FROM 
    MEDICO medico
INNER JOIN 
    CARGO cargo ON medico.car_id = cargo.car_id
WHERE 
    LOWER(cargo.nombre) LIKE '%atención%'
ORDER BY 
    medico.sueldo_base * 1.15;


