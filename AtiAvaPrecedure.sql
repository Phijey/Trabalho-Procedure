
use classicmodels;

create table carrinho_compras(
pedidocodvar varchar(15) not null,
qtdevar int not null,
valorvar decimal(10, 2) not null,
codigocliente int not null
);

delimiter $$

create procedure gerar_item_pedido(
in PARAM_pedidocodvar varchar(15), 
in PARAM_qtdevar int, 
in PARAM_valorvar decimal(10, 2), 
in PARAM_npedidovar int
)
begin
declare produto_var int;

select count(*) into produto_var 
from products 
where productCode = PARAM_pedidocodvar;
  
if produto_var = 0 then
signal sqlstate '45000' set message_text = 'Produto não existe!';
end if;

if PARAM_qtdevar <= 0 then
signal sqlstate '45000' set message_text = 'qtdevar inválida!';
end if;

insert into orderdetails (
orderNumber, 
productCode, 
quantityOrdered, 
priceEach, 
orderLineNumber
) 
values (
PARAM_npedidovar, 
PARAM_pedidocodvar, 
PARAM_qtdevar, 
PARAM_valorvar, 
(select ifnull(max(orderLineNumber), 0) + 1 from orderdetails where orderNumber = PARAM_npedidovar)
);
    
update products
set quantityInStock = quantityInStock - PARAM_qtdevar
where productCode = PARAM_pedidocodvar;

end$$


delimiter $$

create procedure gerar_pedido(
in PARAM_codigocliente int, 
in PARAM_codigovendedor int, 
out resultado varchar(200)
)
INC: begin
declare npedidovar int;
declare pedidocodvar varchar(15);
declare qtdevar int;
declare valorvar decimal(10, 2);
declare convar int default 0;
    
declare carrinholpvar cursor for 
select pedidocodvar, qtdevar, valorvar 
from carrinho 
where codigocliente = PARAM_codigocliente;
  
declare continue handler for not found set convar = 1;

if not exists(select customerNumber from customers where customerNumber = PARAM_codigocliente) then
set resultado = "Cliente informado não existe!";
leave INC;
end if;
      
if not exists(select employeeNumber from employees where jobTitle = 'Sales Rep' and employeeNumber = PARAM_codigovendedor) then
set resultado = "Vendedor informado não existe!";
leave INC;
end if;
    
if not exists(select codigocliente from carrinho where codigocliente = PARAM_codigocliente) then
set resultado = "Carrinho vazio!";
leave INC;
end if;
    
start transaction;
    
insert into orders (
orderDate, 
requiredDate, 
status, 
customerNumber
)
values (
curdate(), 
date_add(curdate(), interval 7 day), 
'In Process', 
PARAM_codigocliente
);

set npedidovar = last_insert_id();
      
open carrinholpvar;
    
repeat
fetch carrinholpvar into pedidocodvar, qtdevar, valorvar;
if convar = 1 then
leave INC;
end if;

			
call gerar_item_pedido(pedidocodvar, qtdevar, valorvar, npedidovar);
			
until convar = 1
end repeat;
close carrinholpvar;

update customers
set salesrepemployeenumber = PARAM_codigovendedor
WHERE customernumber = PARAM_codigocliente;

set resultado = concat('Sucesso: Pedido gerado com o número ', npedidovar);
    
commit;
    
leave INC;

end$$


delimiter ;
