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
	update Bins set [card]=1 where current_amount > 5
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
USE [msdb]
GO

/****** Object:  Job [Restock]    Script Date: 10/24/2012 20:23:35 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 10/24/2012 20:23:35 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Restock', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'samuel-laptop\samuel', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Restock Step]    Script Date: 10/24/2012 20:23:35 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Restock Step', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC RestockBins', 
		@database_name=N'KanBan', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'RestockSchedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20121024, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'edf2f8cf-3535-4b66-a6d0-19e49002f45f'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

-- 
-- job to create lamps
--
USE [msdb]
GO

/****** Object:  Job [BuildLamp]    Script Date: 10/24/2012 20:25:27 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 10/24/2012 20:25:27 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'BuildLamp', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'samuel-laptop\samuel', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [BuildLampStep]    Script Date: 10/24/2012 20:25:27 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'BuildLampStep', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC BuildLamp', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'BuildLampSchedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20121024, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'65974f7b-68de-42c7-83d0-f37a8fbd563b'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

