/*Un cliente no puede tener más de una cita pendiente para el mismo día y horario.
Tampoco puede haber citas que inicien durante el tiempo estimado de atención de 30 minutos.*/
/*
create or replace view cita_oficina as
select idcita, fechacita, horariocita, nrocliente,
		--Seleccionamos solo a.idoficina para evitar ambiguedad
		duracioncita, a.idoficina, nrodocumento, idservicio, dia, nombre, cp
		--Juntamos los citas con las oficinas que corresponden
		from Cita a inner join Oficina b on (a.idoficina = b.idoficina);
*/

CREATE OR REPLACE FUNCTION existeCitaEnTiempoEstimado()
--Función que comprueba si ya hay una cita con tiempo estimado en el horario de la nueva.
RETURNS TRIGGER 
LANGUAGE PLPGSQL  
AS
$$
BEGIN
     IF NOT EXISTs (
     		--obtenemos las citas de la oficina a la cual se quiere registrar una nueva cita.
	       SELECT * 
	       FROM (select * from cita where cita.idoficina = new.idoficina) a
	       --comprobamos si la nueva cita coincide con el horario estimado de alguna.
	       WHERE (NEW.idoficina=a.idoficina) and (a.fechacita= NEW.fechacita) and (a.horariocita<=NEW.horariocita) and (NEW.horariocita<(a.horariocita + interval '30 minutes'))
		   )
	THEN
    	RETURN NEW;
  	ELSE
    	RAISE EXCEPTION 'Cita durante tiempo de atencion de otra';
  END IF;
END;
$$;

create trigger existeCitaEnTiempoEstimado before insert on cita
	for each row execute procedure existeCitaEnTiempoEstimado();

--------CONTROLAMOS QUE NO EXISTA UNA CITA PARA EL MISMO CLIENTE EN ESE DÍA Y HORARIO----------------
/*
--Creamos una vista para poder obtener citas con oficinas fehchas y horarios
create or replace VIEW cita_oficina_horario as
--Seleccionamos solo c.idoficina y c.dia para evitar ambiguedad
SELECT nroCliente, c.idoficina, c.dia, horaini , horafin
FROM (
		select idcita, fechacita, horariocita, nrocliente,
		--Seleccionamos solo a.idoficina para evitar ambiguedad
		duracioncita, a.idoficina, nrodocumento, idservicio, dia, nombre, cp
		--Juntamos los citas con las oficinas que corresponden
		from Cita a inner join Oficina b on (a.idoficina = b.idoficina)) c 
/*Ahora tenemos las citas de cada oficina.
  Juntamos a las citas con oficinas le agregamos el horario
 */
inner join DiaAtencion d on (c.idoficina = d.idoficina);
*/

CREATE OR REPLACE FUNCTION existeCitaEnEseHorario()
/*Esta función comprueba si un cliente tiene ya una cita para el mismo horario en la misma oficina.
 * Si no se encuentran citas, registra la nueva cita. En caso contrario devuelve un mensaje.
 */
RETURNS TRIGGER 
LANGUAGE PLPGSQL  
AS
$$
begin
    IF NOT exists (
    		--Buscamos algúna cita que coincida con la que se quiere ingresar.
	       SELECT *
	       FROM (SELECT nroCliente, c.idoficina, c.dia, horaini , horafin
				FROM (
							select idcita, fechacita, horariocita, nrocliente,
							--Seleccionamos solo a.idoficina para evitar ambiguedad
								duracioncita, z.idoficina, nrodocumento, idservicio, dia, nombre, cp
								--Juntamos los citas con las oficinas que corresponden
							from Cita z inner join Oficina b on (z.idoficina = b.idoficina)) c 
								/*Ahora tenemos las citas de cada oficina.
  								Juntamos a las citas con oficinas le agregamos el horario
 									*/
				inner join DiaAtencion d on (c.idoficina = d.idoficina)) a
	       WHERE (NEW.nrocliente=a.nrocliente) and (NEW.idoficina=a.idoficina) and (NEW.dia=a.dia) and (a.horaini<= NEW.horariocita) and (NEW.horariocita<a.horafin)
		   )
	then
		--Si el cliente no tiene cita para ese horario en esa oficina, registramos la cita.
    	RETURN NEW;
  	else
  		--Devolvemos una exepción si encontramos una cita del cliente en ese horario para esa oficina.
    	RAISE EXCEPTION 'El cliente ya posee una cita para ese horario';
  END IF;
END;
$$;


create trigger existeCitaEnEseHorario before insert on cita
	for each row execute procedure existeCitaEnEseHorario();


--************************************************************
--No se deben poder agendar citas para una fecha anterior a la actual. En caso de que la cita
--sea para el día actual, se debe verificar que la hora de la misma no sea anterior a la hora en
--la que se está dando de alta.

CREATE OR REPLACE FUNCTION CitaParaFuturo()
RETURNS TRIGGER 
LANGUAGE PLPGSQL  
AS
$$
BEGIN
	IF (NEW.fechaCita>CURRENT_DATE)
	THEN
    	RETURN NEW;
  	ELSE IF (NEW.fechaCita=CURRENT_DATE) and (NEW.horarioCita>LOCALTIME)
		THEN
		RETURN NEW;
	     ELSE
	     RAISE EXCEPTION 'No se puede registrar una cita para una fecha anterior a la actual.';
  	   END IF;
	 END IF;
END;
$$;

create trigger citaParaFuturo before insert on cita
for each row execute procedure CitaParaFuturo();
