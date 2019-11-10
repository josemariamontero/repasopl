5-Añade una columna llamada ImporteComprado en la tabla Proveedores. Realiza una
sentencia o un procedimiento que la rellene a partir de los datos existentes. Realiza
también los módulos de programación necesarios para que se mantenga actualizada
automáticamente cada vez que se inserte un pedido nuevo.

alter table Proveedores add ImporteComprado NUMBER;

create or replace trigger Actualizacion
after insert or update on Pedidos 
for each row
declare
	v_proveedor proveedores.codigo%type;
begin 
	if inserting then
		v_proveedor:=Proveedores(:new.codigoproveedor);
		SumarImporte:=(v_proveedor,:new.importe);
	elsif updating then
		if :old.importe < :new.importe then
		v_proveedor:=Proveedores(:new.codigoproveedor);
		SumarImporte(v_proveedor,:new.importe);
		if :old.importe > :new.importe then
		v_proveedor:=Proveedores(:new.codigoproveedor);
		RestarImporte(v_proveedor,:new.importe);
		end if;
	else:
		v_proveedor:=Proveedores(:old.codigoproveedor);
		RestarImporte(v_proveedor,:old.importe);
	end if;
end;
/

create or replace function Proveedores(p_codigoproveedor proveedores.codigo%type)
return proveedores.codigo%type;
is
	v_codigoproveedor	proveedores.codigo%type;
begin 
	select codigo into v_codigoproveedor
	from proveedores
	where codigo = p_codigoproveedor;
	return	v_codigoproveedor;
end;
/

create or replace function SumarImporte(p_codigoproveedor proveedores.codigo%type,
										p_importe		  precios.importe%type)
is
begin 
	update ImporteComprado
	set ImporteComprado = ImporteComprado + p_importe
	where codigo = p_codigoproveedor;
end;
/

create or replace function RestarImporte(p_codigoproveedor proveedores.codigo%type,
										p_importe		  precios.importe%type)
is
begin 
	update ImporteComprado
	set ImporteComprado = ImporteComprado - p_importe
	where codigo = p_codigoproveedor;
end;
/

8. Realiza los módulos de programación necesarios para asegurar que el precio de un
medicamento en una presentación determinada es creciente con el tamaño del
envase.

create or replace function PreciosMedicamentos (p_codigomedicamento precios.codigomedicamento%type,
											   p_importe		   precios.importe%type)
return precios.importe%type;
is
	v_precios	precios.importe%type;
begin 
	select precios into v_precios
	from precios
	where precios = p_importe
	and codigomedicamento = p_codigomedicamento;
	return v_precios;
end PreciosMedicamentos;
/

create or replace trigger presentacion (p_codigo presentaciones.codigo%type)
before insert on Presentaciones
for each row
declare
	v_cantidad 	presentaciones.cantidad%type;
	v_formato 	presentaciones.formato%type;
begin
	select formato,cantidad into v_cantidad,v_formato
	from presentaciones
	where codigo=p_codigo;
	PreciosMedicamentos(p_codigomedicamento,p_importe);
	if v_cantidad > :new.cantidad and v_formato > :new.formato then
		raise_application_error(-20020,'Datos incorrectos');
	end if;
end;
/


2. Realiza un procedimiento que nos proporcione diferentes listados acerca de las compras de
medicamentos realizadas gestionando las excepciones que consideres oportunas. El primer parámetro
determinará el tipo de informe.

Informe Tipo 1: El segundo parámetro será un código de medicamento y el tercero un código de
presentación. Se mostrarán los envases adquiridos del citado medicamento con dicha presentación
incluyendo la siguiente información:

create or replace function Cabecera(p_codigo medicamentos.codigo%type,
									 p_presentacion presentaciones.codigo%type)
returns varchar as $$
declare
	v_cont	numeric;
begin
	select count(*) into v_cont
	from envasesdemedicamentos
	where codigomedicamento=p_codigo
	and codigopresentacion=p_presentacion;
	if v_cont=0 then
		raise notice 'No hay medicamentos con esa presentacion';
	else
		MostrarCabecera(p_codigo, p_presentacion, v_cont);
	end if;
end Cabecera;
$$ language plpgsql;

create or replace function MostrarCabecera(p_codigo medicamentos.codigo%type,
											p_presentacion presentaciones.codigo%type,
											p_contador numeric)
returns varchar as $$
declare
	v_nombre medicamentos.nombrecomercial%type;
	v_presentacion presentaciones.formato%type;
begin
	select nombrecomercial into v_nombre
	from medicamentos
	where codigo=p_codigo;
	select formato into v_presentacion
	from presentaciones
	where codigo=p_presentacion;
	return 'Codigo Medicamento: '||p_codigo||' '||'Nombre Medicamento: '||v_nombre;
	return 'Formato Presentación: '||v_presentacion||' '||'Cantidad: '||p_contador;
end MostrarCabecera;
$$ language plpgsql;

create or replace function MostrarPedidos(p_codigo medicamentos.codigo%type,
										   p_presentacion presentaciones.codigo%type)
returns varchar as $$
declare
	v_presentacion presentaciones.codigo%type;
	v_proveedor proveedores.codigo%type;
	v_importe precios.importe%type;
	v_fecha precios.fechainicio%type;
	v_importetotal numeric:=0;
	cur_pedido cursor for select codigopresentacion,codigoproveedor,importe,fechainicio into v_presentacion,v_proveedor,v_importe,v_fecha
	from precios
	where codigomedicamento=p_codigo
	and codigopresentacion=p_presentacion;
begin
	Cabecera(p_codigo,p_presentacion);
	open cur_pedido;
	fetch cur_pedido into v_presentacion,v_proveedor,v_importe,v_fecha;
	while( found ) loop
		return 'Presentacion:'||v_presentacion||'Proveedor:'||v_proveedor||'Importe: '||v_importe||'Fecha:'||v_fecha);
		v_importetotal:=v_importetotal+v_importe;
		fetch cur_pedido into v_presentacion,v_proveedor,v_importe,v_fecha;
	end loop;
	return 'Importe Total:'||v_importetotal||;
end MostrarPedidos;
$$ language plpgsql;


Informe Tipo 2: El segundo parámetro será un código de medicamento y el tercero se ignorará. Se
mostrarán todos los envases adquiridos en todas las presentaciones posibles con el siguiente formato:

create or replace function Informe2(p_codigo medicamentos.codigo%type)
returns varchar as $$
	v_presentacion presentaciones.codigo%type;
	v_total numeric:=0;
	cur_present cursor for select codigopresentacion into v_presentacion
	from envasesdemedicamentos
	where codigomedicamento=p_codigo;
begin
	for v_present in cur_present loop
		v_presentacion:=v_present.codigopresentacion;
		MostrarPedidos2(p_codigo,v_presentacion,v_total);
	end loop;
	return 'Importe Total Medicamento: '||v_total;
end Informe2;
$$ language plpgsql;

create or replace function MostrarPedidos2(p_codigo medicamentos.codigo%type,
										   p_presentacion presentaciones.codigo%type,
										   v_total in out numeric)
return varchar as $$
	v_presentacion presentaciones.codigo%type;
	v_proveedor proveedores.codigo%type;
	v_importe precios.importe%type;
	v_fecha precios.fechainicio%type;
	v_importetotal numeric:=0;
	cur_pedido cursor for select codigopresentacion,codigoproveedor,importe,fechainicio into v_presentacion,v_proveedor,v_importe,v_fecha
	from precios
	where codigomedicamento=p_codigo
	and codigopresentacion=p_presentacion;
begin
	Cabecera(p_codigo,p_presentacion);
	open cur_pedido;
	fetch cur_pedido into v_presentacion,v_proveedor,v_importe,v_fecha;
	while( found ) loop
		return 'Presentación: '||v_presentacion||'Proveedor: '||v_proveedor||'Importe: '||v_importe||'Fecha: '||v_fecha);
		v_importetotal:=v_importetotal+v_importe;
		fetch cur_pedido into v_presentacion,v_proveedor,v_importe,v_fecha;
	end loop;
	return 'Importe Total Presentación: '||v_importetotal;
	v_total:=v_importetotal+v_total;
end MostrarPedidos2;
$$ language plpgsql;

Informe Tipo 3: El segundo parámetro y el tercero se ignorarán. Se mostrarán todas las compras de
todos los medicamentos en todas las presentaciones posibles incluyendo la siguiente información:

create or replace function Informe3
return varchar as $$
declare
	v_medicamento medicamentos.codigo%type;
	v_preciototal numeric:=0;
	cur_medica cursor for select distinct codigomedicamento
	from envasesdemedicamentos;
begin
	for v_medica in cur_medica loop
		v_medicamento:=v_medica.codigomedicamento;
		MostrarInforme(v_medicamento,v_preciototal);
	end loop;
	return 'Importe Total Compras: '||v_preciototal;
end Informe3;
$$ language plpgsql;

create or replace function MostrarInforme(p_codigo medicamentos.codigo%type,
										   v_preciototal in out numeric)
return varchar as $$
declare
	v_presentacion presentaciones.codigo%type;
	v_total numeric:=0;
	cur_present cursor for select codigopresentacion into v_presentacion
	from envasesdemedicamentos
	where codigomedicamento=p_codigo;
begin
	for v_present in cur_present loop
		v_presentacion:=v_present.codigopresentacion;
		MostrarPedidos2(p_codigo,v_presentacion,v_total);
	end loop;
	return 'Importe Total Medicamento: '||v_total;
	v_preciototal:=v_preciototal+v_total;
end MostrarInforme;
$$ language plpgsql;