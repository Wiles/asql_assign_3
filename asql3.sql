create database KanBan

go

use KanBan

go

create table Bins
(
	id int not null primary key identity(1,1),
	item varchar(25) not null,
	capacity int not null,
	current_amount int not null,
	[card] bit not null default 1
)

go

insert into Bins (item, capacity, current_amount)
values ('Harness', 75, 75)
insert into Bins (item, capacity, current_amount)
values ('Housing', 25, 25)
insert into Bins (item, capacity, current_amount)
values ('Lens', 40, 40)
insert into Bins (item, capacity, current_amount)
values ('Bulb', 50, 50)
insert into Bins (item, capacity, current_amount)
values ('Bezel', 75, 75)

go

create trigger UpdateBinsTrigger
on Bins
after update
as
if (UPDATE(current_amount))
begin
	update Bins set [card]=0 where current_amount <= 5
end

go

create table ProductsBuilt
(
	product varchar(50) NOT NULL,
	number_built int NOT NULL default 0
)

go

insert into ProductsBuilt (product) VALUES ('Lamp')

go

--
-- sproc for taking an item out of a bin
--
create procedure TakeItemFromBin
	@binId int
as
declare @tran varchar(20) = 'takeItem'
begin transaction @tran
declare @count int = (select current_amount from Bins where id=@binId)
if (@count = 0)
begin
	rollback transaction @tran
	return 0
end
else
begin
	set @count = @count - 1
	update Bins set current_amount=@count where id=@binId
	commit transaction @tran
	return 1
end

go

--
-- sproc for building a lamp
-- 
create procedure BuildLamp
as
declare @buildalamp int = 0
declare @transactionName varchar(20) = 'buildlamptran'
begin transaction @transactionName
declare @ret int = 0
declare @parts int = 0
exec @ret = TakeItemFromBin @binId = 1
set @parts += @ret
exec @ret = TakeItemFromBin @binId = 2
set @parts += @ret
exec @ret = TakeItemFromBin @binId = 3
set @parts += @ret
exec @ret = TakeItemFromBin @binId = 4
set @parts += @ret
exec @ret = TakeItemFromBin @binId = 5
set @parts += @ret

if @parts = 5
begin
	update ProductsBuilt set number_built = number_built + 1 where product = 'Lamp'
	commit transaction @transactionName
	return 1
end
else
begin
	rollback transaction @transactionName
	return 0
end

go


-- 
-- sproc for restocking
-- 
create procedure RestockBins
as
update Bins set current_amount = current_amount + capacity where current_amount <= 5

go


-- 
-- job for restocking
--
