USE [BDDistBHF_CF]
GO
/****** Object:  StoredProcedure [dbo].[sp_Mam_TO005]    Script Date: 14/01/2020 06:08:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[sp_Mam_TO005] (@tipo int, @olnumi int=-1, @olnumichof int=-1, @olnumiconci int=-1, @olfecha date=null,
									   @oluact nvarchar(10)='', @pedido int=-1, @TO001 TO001Type Readonly, @zona int=-1, 
									   @mrec decimal(18, 2)=0,@cliente int=0,@fechai date=null,@fechaf date=null, @nconci int=-1,@chofer int=-1,
									   @oanumi int=-1,@credito decimal(18,2)=0)
AS
BEGIN
	DECLARE @newHora nvarchar(5)
	set @newHora=CONCAT(DATEPART(HOUR,GETDATE()),':',DATEPART(MINUTE,GETDATE()))
	DECLARE @newFecha date
	set @newFecha=GETDATE()

	IF @tipo=-1 --ELIMINAR REGISTRO
	BEGIN
		BEGIN TRY 
			update TO001A 
			set oaacaja=0
			from TO001A inner join @TO001 as td on TO001A .oaato1numi=td.oanumi and TO001A.oaacaja=@olnumi 
		
			delete from TO005 where olnumi=@olnumi 

			--Consulibr que hace newNumi
			select @olnumi as newNumi
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END
	IF @tipo=1 --NUEVO REGISTRO
	BEGIN
		begin try
			begin tran Insertar_Nuevo

			set @olnumi=IIF((select COUNT(olnumi) from TO005)=0, 0, (select MAX(olnumi) from TO005))+1

			INSERT INTO TO005 VALUES(@olnumi, @olnumichof, @olnumiconci, @olfecha, @mrec, @newFecha, @newHora, @oluact)

     		update TO001A 
			set oaacaja=@olnumi
			from TO001A inner join @TO001 as td on TO001A.oaato1numi=td.oanumi 
			and TO001A.oaacaja=0  and td.estado=0

			select @olnumi as newNumi  --Consulibr que hace newNumi
			commit tran Insertar_Nuevo
			print concat('Se actualizo el saldo del producto con codigo: ', @olnumi)
		end try
		begin catch
			rollback tran Insertar_Nuevo
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
			VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		end catch
	END

	IF @tipo=2 --NUEVO REGISTRO
	BEGIN
		BEGIN TRY 
			update TO005 
			set olnumichof=@olnumichof, olnumiconci=@olnumiconci, olfecha=@olfecha, olmrec=@mrec
			where olnumi=@olnumi 

     		update TO001A 
			set oaacaja=@olnumi
			from 
				TO001A inner join @TO001 as td on TO001A.oaato1numi=td.oanumi and TO001A.oaanumiprev=@olnumichof and 
				TO001A.oaacaja=0 and td.estado =0

			update TO001A 
			set oaacaja=0
			from TO001A inner join @TO001 as td on td.oanumi=TO001A.oaato1numi and td.estado=-1

		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

	IF @tipo=3 --MOSTRAR DATOS DEL REGISTRO
	BEGIN
		BEGIN TRY 
			select 
				a.olnumi, a.olnumichof, repartidor.cbdesc as chofer, a.olnumiconci, a.olfecha, a.olmrec, 
				a.olfact, a.olhact, a.oluact 
			from 
				TO005 as a inner join TC002 as repartidor on repartidor.cbnumi=a.olnumichof 
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

	IF @tipo=4 --MOSTRAR DETALLE DEL REGISTRO
	BEGIN
		BEGIN TRY 
			select pedido.oanumi,pedido.oafdoc,pedido.oaccli,cliente.ccdesc as cliente,
				   pedido.oarepa,pedido.oaest,pedido.oaap,pedido.oapg,
				   Sum(detalle.obptot)as total,
				   (Sum(detalle.obptot)-(isnull((select sum(aa.ogcred) from TO001A1 as aa where aa.ognumi=pedido.oanumi),0))) as contado,
				   (isnull((select sum(aa.ogcred) from TO001A1 as aa where aa.ognumi=pedido.oanumi),0)) as credito, 
				   iif((isnull((select sum(aa.ogcred) from TO001A1 as aa where aa.ognumi=pedido.oanumi),0))>0 and cliente2.ccbtcre=1,1,0) as tcre, 1 as estado
			from 
				TO005  as caja inner join TO001A as a on a.oaacaja=caja.olnumi  
				inner join TO001 as pedido on pedido.oanumi=a.oaato1numi 
				inner join TC004 as cliente on cliente.ccnumi=pedido.oaccli and oaest=3
				inner join TO0011 as detalle on detalle.obnumi=pedido.oanumi 
				inner join TC002 as repartidor on repartidor.cbnumi=pedido.oarepa
				inner join TC004B as cliente2 on cliente2.ccbnumi=pedido.oaccli 
			where caja.olnumi=@olnumi 
			group by pedido.oanumi,pedido.oafdoc,pedido.oaccli,cliente.ccdesc,pedido.oarepa,pedido.oaest,pedido.oaap,pedido.oapg, cliente2.ccbtcre 

		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

	IF @tipo=5 --LISTAR CLIENTES 
	BEGIN
		BEGIN TRY 
			--select pedido.oanumi,pedido.oafdoc,pedido.oaccli,cliente.ccdesc as cliente,
			--	   pedido.oarepa,pedido.oaest,pedido.oaap,pedido.oapg,Sum(detalle.obptot)as total,
			--	   (Sum(detalle .obptot)-(isnull((select sum(aa.ogcred)
			--									  from TO001A1 as aa 
			--									  where aa.ognumi=pedido.oanumi),0))) as contado,
			--	   (isnull((select sum(aa.ogcred)
			--				from TO001A1 as aa 
			--				where aa.ognumi=pedido.oanumi),0)) as credito,
			--				iif((isnull((select sum(aa.ogcred) from TO001A1 as aa where aa.ognumi=pedido.oanumi),0))>0 and cliente2.ccbtcre=1,1,0) as tcre, 0 as estado
			--from TO001 as pedido inner join TC004 as cliente on cliente.ccnumi=pedido.oaccli and oaest=3
			--	 inner join TO0011 as detalle on detalle.obnumi=pedido.oanumi
			--	 inner join TC002 as repartidor on repartidor.cbnumi=pedido.oarepa and pedido.oarepa=@olnumichof --and pedido.oafdoc=@olfecha
			--	 inner join TO001A as aux on aux.oaato1numi=pedido.oanumi  
			--	 inner join TC004B as cliente2 on cliente2.ccbnumi=pedido.oaccli 
			--where pedido.oanumi not in (select a.oaato1numi
			--							from TO001A as a 
			--							where a.oaacaja>0)
			--group by pedido.oanumi,pedido.oafdoc,pedido.oaccli,cliente.ccdesc,pedido.oarepa,pedido.oaest,pedido.oaap,pedido.oapg, cliente2.ccbtcre 

			select pedido.oanumi, pedido.oafdoc,pedido.oaccli,cliente.ccdesc as cliente,
				   pedido.oarepa,pedido.oaest,pedido.oaap,pedido.oapg,Sum(detalle.obptot)as total,
				   (Sum(detalle .obptot)-(isnull((select sum(aa.ogcred)
												  from TO001A1 as aa 
												  where aa.ognumi=pedido.oanumi),0))) as contado,
				   (isnull((select sum(aa.ogcred)
							from TO001A1 as aa 
							where aa.ognumi=pedido.oanumi),0)) as credito,
							iif((isnull((select sum(aa.ogcred) from TO001A1 as aa where aa.ognumi=pedido.oanumi),0))>0 and cliente2.ccbtcre=1,1,0) as tcre, 0 as estado
			from TO001 as pedido inner join TC004 as cliente on cliente.ccnumi=pedido.oaccli and oaest=3
				 inner join TO0011 as detalle on detalle.obnumi=pedido.oanumi
				 inner join TC002 as repartidor on repartidor.cbnumi=pedido.oarepa and pedido.oarepa=@olnumichof --and pedido.oafdoc=@olfecha
				 inner join TO001A as aux on aux.oaato1numi=pedido.oanumi  
				 inner join TC004B as cliente2 on cliente2.ccbnumi=pedido.oaccli 
				 inner join TO001C as conci on conci.oacoanumi=pedido.oanumi and conci.oacnconc=@nconci

			where pedido.oanumi not in (select a.oaato1numi
										from TO001A as a 
										where a.oaacaja>0)
			group by pedido.oanumi, pedido.oafdoc, pedido.oaccli, cliente.ccdesc, pedido.oarepa, pedido.oaest, 
			pedido.oaap, pedido.oapg, cliente2.ccbtcre 
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

	IF @tipo=6 --LISTAR CONCILIACIONES ABIERTAS 
	BEGIN
		BEGIN TRY 
			select 
				a.ibid, a.ibfdoc, a.ibconcep, c.cbnumi as idchofer, c.cbdesc as chofer
			from 
				TM001 as a inner join TM0012 as d on d.ieconcti2=a.ibid and d.ieest=2
				inner join TC002 as c on c.cbnumi=a.ibidchof 
				inner join TC0051 as e on e.cecon=7 and c.cbcat=e.cenum and d.ieconcti2 not in(select a.olnumiconci  
																							   from TO005  as a)
			where a.ibfdoc >='2018-08-29'
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

	
	IF @tipo=7 --VER DETALLE DEL PEDIDO
	BEGIN
		BEGIN TRY 
			select 
				detalle.obcprod, producto.cadesc, detalle.obpbase, detalle.obpcant, detalle.obptot 
			from 
				TO001 as pedido inner join TO0011 as detalle on detalle.obnumi=pedido.oanumi 
				inner join TC001 as producto on producto.canumi=detalle.obcprod 
			where pedido .oanumi=@pedido
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

	IF @tipo=8 --OBTENER PEDIDOS ENTREGADOS DESDE LA MOVIL
	BEGIN
		BEGIN TRY 
			SELECT c.obcprod, c.obpcant, c.obpbase, c.obptot 
			from TO001 as pedido inner join TO001A as b on b.oaato1numi=pedido.oanumi and b.oaaentrega=2
				 inner join TO0011 as c on c.obnumi=pedido.oanumi 
			where pedido.oanumi in(select td.oanumi from @TO001 as td)
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

	IF @tipo=9 --OBTENER PEDIDOS ENTREGADOS DESDE LA PC
	BEGIN
		BEGIN TRY 
			select 
				c.obcprod ,c.obpcant ,c.obpbase ,c.obptot 
			from 
				TO001 as pedido inner join TO001A as b on b.oaato1numi=pedido.oanumi and b.oaaentrega=1
				inner join TO0011 as c on c.obnumi =pedido.oanumi 
			where pedido.oanumi in (select td.oanumi from @TO001 as td)
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

	IF @tipo=10 --LISTAR ZONAS
	BEGIN
		BEGIN TRY 
			select 
				a.lanumi as yccod3, zona.cedesc + '' as ycdes3
			from 
				TL001 as a inner join TC0051 as zona on zona.cecon=2 and zona.cenum=a.lazona 
				inner join TC0051 as ciudad on ciudad.cecon=3 and ciudad.cenum=a.lacity
				inner join TC0051 as provincia on provincia.cecon=4 and provincia.cenum=a.laprovi 
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

	IF @tipo=11 --LISTAR ZONAS
	BEGIN
		BEGIN TRY
			select 
				a.ccnumi, a.cccod, isnull(a.ccdesc, '') as ccdesc, isnull (a.cctelf2, '') as cctelf2,
				isnull(a.ccobs, '') as ccobs, isnull(a.cclat, '0') as cclat, isnull(a.cclongi, '0') as cclongi
			from 
				TC004 as a inner join TL001 as zona on zona.lanumi=a.cczona
			where 
				zona.lanumi=@zona
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END


	
	IF @tipo=12 --LISTAR CLIENTES
	BEGIN
		BEGIN TRY
			select 
				a.ccnumi, a.cccod, isnull(a.ccdesc, '') as ccdesc, isnull (a.cctelf2, '') as cctelf2,
				isnull(a.ccdirec , '') as ccobs
			from 
				TC004 as a inner join TL001 as zona on zona.lanumi=a.cczona
			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END


		IF @tipo=13 --ESTADO DE CUENTAS CLIENTES GENERAL
	BEGIN
		BEGIN TRY
			SELECT pedido.oanumi, FORMAT (pedido.oafdoc , 'dd-MM-yyyy')  as oafdoc, pedido.oaccli, cliente.ccdesc AS cliente, pedido.oarepa, pedido.oaest,
 pedido.oaap, pedido.oapg, Sum(detalle.obptot) AS total, (Sum(detalle.obptot) - (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0))) AS contado, (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0)) AS credito, iif((isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0)) > 0 AND cliente2.ccbtcre = 1, 1, 0) AS tcre, 1 AS estado
FROM     TO005 AS caja INNER JOIN
                  TO001A AS a ON a.oaacaja = caja.olnumi INNER JOIN
                  TO001 AS pedido ON pedido.oanumi = a.oaato1numi INNER JOIN
                  TC004 AS cliente ON cliente.ccnumi = pedido.oaccli AND oaest = 3 INNER JOIN
                  TO0011 AS detalle ON detalle.obnumi = pedido.oanumi INNER JOIN
                  TC002 AS repartidor ON repartidor.cbnumi = pedido.oarepa INNER JOIN
                  TC004B AS cliente2 ON cliente2.ccbnumi = pedido.oaccli
				and pedido .oafdoc >=@fechai and pedido.oafdoc <=@fechaf 
GROUP BY pedido.oanumi, pedido.oafdoc, pedido.oaccli, cliente.ccdesc, pedido.oarepa, pedido.oaest, pedido.oaap, pedido.oapg, 
cliente2.ccbtcre

			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END


	IF @tipo=14 --ESTADO DE CUENTAS CLIENTES GENERAL
	BEGIN
		BEGIN TRY
			SELECT pedido.oanumi,  FORMAT (pedido.oafdoc , 'dd-MM-yyyy') as oafdoc , pedido.oaccli, cliente.ccdesc AS cliente, pedido.oarepa, pedido.oaest,
 pedido.oaap, pedido.oapg, Sum(detalle.obptot) AS total, (Sum(detalle.obptot) - (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0))) AS contado, (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0)) AS credito, iif((isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0)) > 0 AND cliente2.ccbtcre = 1, 1, 0) AS tcre, 1 AS estado
FROM     TO005 AS caja INNER JOIN
                  TO001A AS a ON a.oaacaja = caja.olnumi INNER JOIN
                  TO001 AS pedido ON pedido.oanumi = a.oaato1numi INNER JOIN
                  TC004 AS cliente ON cliente.ccnumi = pedido.oaccli AND oaest = 3 INNER JOIN
                  TO0011 AS detalle ON detalle.obnumi = pedido.oanumi INNER JOIN
                  TC002 AS repartidor ON repartidor.cbnumi = pedido.oarepa INNER JOIN
                  TC004B AS cliente2 ON cliente2.ccbnumi = pedido.oaccli
				  and cliente .ccnumi =@cliente ----Numi Cliente
				  and pedido .oafdoc >=@fechai and pedido.oafdoc <=@fechaf 
GROUP BY pedido.oanumi, pedido.oafdoc, pedido.oaccli, cliente.ccdesc, pedido.oarepa, pedido.oaest, pedido.oaap, pedido.oapg, 
cliente2.ccbtcre

			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

		IF @tipo=15 --LISTAR CLIENTES
	BEGIN
		BEGIN TRY
			select 
				a.cbnumi , a.cbci , isnull(a.cbdesc , '') as ccdesc, isnull (a.cbtelef , '') as cctelf2,
				isnull(a.cbdirec  , '') as ccobs
			from 
				TC002 as a 
			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

		IF @tipo=16 --REPORTE VENDEDOR TODOS
	BEGIN
		BEGIN TRY
			SELECT pedido.oanumi, FORMAT (pedido.oafdoc , 'dd-MM-yyyy') as oafdoc,caja .olnumi as caja, pedido.oaccli, cliente.ccdesc AS cliente, pedido.oarepa,repartidor .cbdesc , Sum(detalle.obptot) AS total, (Sum(detalle.obptot) - (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0))) AS contado, (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0)) AS credito, iif((isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0)) > 0 AND cliente2.ccbtcre = 1, 1, 0) AS tcre, 1 AS estado
FROM     TO005 AS caja INNER JOIN
                  TO001A AS a ON a.oaacaja = caja.olnumi INNER JOIN
                  TO001 AS pedido ON pedido.oanumi = a.oaato1numi INNER JOIN
                  TC004 AS cliente ON cliente.ccnumi = pedido.oaccli AND oaest = 3 INNER JOIN
                  TO0011 AS detalle ON detalle.obnumi = pedido.oanumi INNER JOIN
                  TC002 AS repartidor ON repartidor.cbnumi = pedido.oarepa INNER JOIN
                  TC004B AS cliente2 ON cliente2.ccbnumi = pedido.oaccli
				    and pedido .oafdoc >=@fechai and pedido.oafdoc <=@fechaf 
					 where (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0))>0
GROUP BY pedido.oanumi, pedido.oafdoc,caja.olnumi ,repartidor .cbdesc , pedido.oaccli, cliente.ccdesc, pedido.oarepa, pedido.oaest, pedido.oaap, pedido.oapg, 
cliente2.ccbtcre
			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END


	IF @tipo=17 --REPORTE VENDEDOR Solo Uno
	BEGIN
		BEGIN TRY
			SELECT pedido.oanumi, FORMAT (pedido.oafdoc , 'dd-MM-yyyy') as oafdoc,caja .olnumi as caja, pedido.oaccli, cliente.ccdesc AS cliente, pedido.oarepa,repartidor .cbdesc , Sum(detalle.obptot) AS total, (Sum(detalle.obptot) - (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0))) AS contado, (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0)) AS credito, iif((isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0)) > 0 AND cliente2.ccbtcre = 1, 1, 0) AS tcre, 1 AS estado
FROM     TO005 AS caja INNER JOIN
                  TO001A AS a ON a.oaacaja = caja.olnumi INNER JOIN
                  TO001 AS pedido ON pedido.oanumi = a.oaato1numi INNER JOIN
                  TC004 AS cliente ON cliente.ccnumi = pedido.oaccli AND oaest = 3 INNER JOIN
                  TO0011 AS detalle ON detalle.obnumi = pedido.oanumi INNER JOIN
                  TC002 AS repartidor ON repartidor.cbnumi = pedido.oarepa INNER JOIN
                  TC004B AS cliente2 ON cliente2.ccbnumi = pedido.oaccli
				  and repartidor .cbnumi =@cliente 
				    and pedido .oafdoc >=@fechai and pedido.oafdoc <=@fechaf 
					 where (isnull
                      ((SELECT sum(aa.ogcred)
                        FROM      TO001A1 AS aa
                        WHERE   aa.ognumi = pedido.oanumi), 0))>0
GROUP BY pedido.oanumi, pedido.oafdoc,caja.olnumi ,repartidor .cbdesc , pedido.oaccli, cliente.ccdesc, pedido.oarepa, pedido.oaest, pedido.oaap, pedido.oapg, 
cliente2.ccbtcre
			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

--		IF @tipo=18 
--	BEGIN
--		BEGIN TRY
			

--SELECT e.oaccbnumi, c.canumi, c.cacod, c.cadesc, c.cadesc2, d.cadesc AS categoria, SUM(b.obpcant) AS obpcant, b.obpbase AS chprecio, SUM(b.obptot) AS Total
--FROM     dbo.TO001 AS a INNER JOIN
--                  dbo.TO0011 AS b ON a.oanumi = b.obnumi INNER JOIN
--                  dbo.TC001 AS c ON b.obcprod = c.canumi INNER JOIN
--                  dbo.TC005C AS d ON c.cacat = d.canumi INNER JOIN
--                  dbo.TO001C AS e ON a.oanumi = e.oacoanumi
--WHERE  (a.oaest < 3) AND (a.oaap = 1) and e.oaccbnumi=@chofer 
--and a.oanumi in (  select x.id   from @ID as x)
--GROUP BY e.oaccbnumi, c.canumi, c.cacod, c.cadesc, c.cadesc2, d.cadesc, b.obpbase
			
--		END TRY
--		BEGIN CATCH
--			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
--				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
--		END CATCH
--	END

			IF @tipo=19 
	BEGIN
		BEGIN TRY
			

select 0 as id
			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

			IF @tipo=20 
	BEGIN
		BEGIN TRY
		SELECT  TOP 100 oanumi,oafdoc,oahora,oaccli,ccdesc,ccdirec,cctelf1,cccat,oazona,cedesc,oaobs,oaobs2,oaest,cclat,
cclongi,oaap,oapg,ccultvent,oarepa,oaanumiprev ,IIF(Exists(select * from TO001A1 as credito where credito.ognumi =oanumi ),0,1) as credito,
IIF(Exists(select * from TO001A1 as credito where credito.ognumi =oanumi ),(select top 1 credito.ogcred from TO001A1 as credito where credito.ognumi =oanumi ),0) as montocredito
 FROM TO001,TC004,TC0051,TL001,TO001A WHERE  ccnumi=oaccli 
 AND oazona=lanumi AND cecon=2 AND lazona=cenum AND oanumi=oaato1numi  AND oaest<>10 
 order by oanumi desc
			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

			IF @tipo=21 
	BEGIN
		BEGIN TRY
if (not exists (select * from TO001A1 where ognumi =@oanumi ))
begin
insert into TO001A1 values (@oanumi ,@credito )

select @oanumi 
end
else

begin 
update TO001A1 set ogcred =@credito where ognumi =@oanumi 
select @oanumi 
end
			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

		IF @tipo=22 
	BEGIN
		BEGIN TRY

SELECT  distinct  a.oanumi, a.oafdoc, b.ccdesc, c.cbdesc, f.canumi, f.cadesc, a.oaobs, e.obpcant, e.obpbase, e.obptot, a.oaest, d.oaccbnumi,
                      (SELECT SUM(obptot) AS Expr1
                       FROM      dbo.TO0011 AS x
                       WHERE   (obnumi = a.oanumi)) AS Total
FROM     dbo.TO001 AS a INNER JOIN
                  dbo.TO001A AS a1 ON a.oanumi = a1.oaato1numi INNER JOIN
                  dbo.TC004 AS b ON a.oaccli = b.ccnumi INNER JOIN
                  dbo.TC002 AS c ON a1.oaanumiprev = c.cbnumi INNER JOIN
                  dbo.TO001C AS d ON a.oanumi = d.oacoanumi INNER JOIN
                  dbo.TO0011 AS e ON e.obnumi = a.oanumi INNER JOIN
                  dbo.TC001 AS f ON f.canumi = e.obcprod
				  where a.oanumi =@oanumi 
			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END

		IF @tipo=23 
	BEGIN
		BEGIN TRY
insert into TO001C values(@oanumi,@chofer ,null,null)
			
		END TRY
		BEGIN CATCH
			INSERT INTO TB001 (banum,baproc,balinea,bamensaje,batipo,bafact,bahact,bauact)
				   VALUES(ERROR_NUMBER(),ERROR_PROCEDURE(),ERROR_LINE(),ERROR_MESSAGE(),-1,@newFecha,@newHora,@oluact)
		END CATCH
	END
End





